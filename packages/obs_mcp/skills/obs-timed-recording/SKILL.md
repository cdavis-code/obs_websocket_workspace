---
name: obs-timed-recording
description: >
  Schedule OBS recording or streaming starts/stops via the OBS MCP
  server. Use for commands like "record for 45 minutes then stop",
  "start recording at 9:00 and stop at 10:15", "stop the stream in
  30 minutes", or "record this lecture for an hour". Handles the wait via
  obs_client_sleep so the JS sandbox stays idle.
---

# OBS Timed Recording

Schedule a duration-bounded recording or streaming session. Useful for lectures, long recordings, and unattended captures.

**Core philosophy**: Use `obs_client_sleep` to delegate the wait to the MCP host, **not** `setTimeout` inside the JS sandbox (which has a 30 s subprocess timeout).

## When to Use

- "Record for 45 minutes then stop"
- "Start recording at 9:00 and stop at 10:15"
- "Stop the stream in 30 minutes"
- "Record this lecture for an hour"
- "Start recording in 5 minutes"

**Do NOT use** for instant transport actions (use `obs-transport-control`) or replay buffer clips (use `obs-replay-clips`).

## Available Tools

All invoked via `execute` with JavaScript `call_tool()`:

- `obs_record_start` / `obs_record_stop` / `obs_record_status`.
- `obs_stream_start` / `obs_stream_stop` / `obs_stream_status`.
- `obs_client_sleep` — server-side sleep (1–25000 ms per call). Chain to wait longer.
- `obs_events_subscribe` + `obs_wait_for_event` — block until `RecordStateChanged` or `StreamStateChanged`.
- `obs_record_create_chapter` — optional, mark chapters at intervals.

## Critical Behavior

1. **`obs_client_sleep` caps at 25 000 ms per call.** For longer waits, chain calls:
   ```javascript
   async function sleepMs(totalMs) {
     while (totalMs > 0) {
       const chunk = Math.min(totalMs, 25000);
       await call_tool('obs_client_sleep', { ms: chunk });
       totalMs -= chunk;
     }
   }
   ```
2. **JS sandbox has a 30 s hard timeout per `execute` invocation.** Long durations must use `obs_client_sleep` (server-side) — `setTimeout` will not work.
3. **For absolute clock times** ("at 9:00"), compute `delayMs = targetTime - Date.now()` and use the same chained sleep pattern.
4. **Confirm the schedule back to the user** with a clear absolute end time.

## Command Mapping

| User says | Action |
|---|---|
| "Record for 45 minutes" | start now, sleep 45*60*1000, stop |
| "Stop the stream in 30 minutes" | sleep 30*60*1000, stop stream |
| "Start at 9:00, stop at 10:15" | sleep until 9:00, start, sleep until 10:15, stop |
| "Record for an hour, mark chapters every 10 min" | start, loop with chapter markers, stop |

## Latency-Conscious Behavior

- **Don't pre-check status** before starting unless asked. If recording is already active, OBS returns an error you can pass back.
- **Confirm the schedule once**, then run silently. Don't echo every minute.
- **Surface the saved file path** when stopping the recording.

## Example Interactions

### Example 1: Record for 45 minutes

**User**: "Record for 45 minutes."

**Agent** (chat): "Starting a 45-minute recording. Will stop at ~12:45."

**Agent** (tool):
```javascript
await call_tool('obs_record_start', {});
let remaining = 45 * 60 * 1000;
while (remaining > 0) {
  const chunk = Math.min(remaining, 25000);
  await call_tool('obs_client_sleep', { ms: chunk });
  remaining -= chunk;
}
const { outputPath } = await call_tool('obs_record_stop', {});
return { outputPath };
```

**Agent** (chat, after stop): "Recording finished. Saved to `/Users/me/Movies/...mkv`."

### Example 2: Stop stream in 30 minutes

**User**: "Stop the stream in 30 minutes."

**Agent** (tool):
```javascript
let remaining = 30 * 60 * 1000;
while (remaining > 0) {
  const chunk = Math.min(remaining, 25000);
  await call_tool('obs_client_sleep', { ms: chunk });
  remaining -= chunk;
}
await call_tool('obs_stream_stop', {});
```

**Agent** (chat): "Will stop the stream in 30 minutes." (then later: "Stream stopped.")

### Example 3: Absolute times with chapter markers

**User**: "Record for an hour, drop a chapter every 10 minutes."

**Agent** (tool):
```javascript
await call_tool('obs_record_start', {});
for (let i = 1; i <= 5; i++) {
  let remaining = 10 * 60 * 1000;
  while (remaining > 0) {
    const chunk = Math.min(remaining, 25000);
    await call_tool('obs_client_sleep', { ms: chunk });
    remaining -= chunk;
  }
  await call_tool('obs_record_create_chapter', {
    chapterName: `Mark ${i * 10} min`,
  });
}
// Final 10-minute segment
let remaining = 10 * 60 * 1000;
while (remaining > 0) {
  const chunk = Math.min(remaining, 25000);
  await call_tool('obs_client_sleep', { ms: chunk });
  remaining -= chunk;
}
const { outputPath } = await call_tool('obs_record_stop', {});
return { outputPath };
```

**Agent** (chat): "Recording for 1 hour with chapter markers every 10 min."

## Calculating Absolute Times

For "stop at 10:15":

```javascript
function delayUntil(hour, minute) {
  const now = new Date();
  const target = new Date(now);
  target.setHours(hour, minute, 0, 0);
  if (target <= now) target.setDate(target.getDate() + 1); // next day
  return target.getTime() - now.getTime();
}
const delayMs = delayUntil(10, 15);
```

Then chain `obs_client_sleep` calls until `delayMs` ms have passed.

## Error Handling

- **`Recording is already active`** when starting: surface it ("Already recording — stopping in 45 min from now anyway?") and proceed to schedule the stop.
- **Connection drops mid-wait**: `obs_client_sleep` runs on the MCP host, not OBS — sleep continues. The subsequent `record_stop` call will fail; surface a clear error.
- **User wants longer than ~30 min**: that's fine; this skill chains sleeps. The JS sandbox 30 s limit applies **per execute call**, not to the total scheduled time, because each chunked sleep returns control to the host.

## Quick Reference

```javascript
// Long wait helper
async function waitMs(totalMs) {
  while (totalMs > 0) {
    const chunk = Math.min(totalMs, 25000);
    await call_tool('obs_client_sleep', { ms: chunk });
    totalMs -= chunk;
  }
}

// Start, wait, stop
await call_tool('obs_record_start', {});
await waitMs(45 * 60 * 1000);
const { outputPath } = await call_tool('obs_record_stop', {});
```
