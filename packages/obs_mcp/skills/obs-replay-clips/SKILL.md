---
name: obs-replay-clips
description: >
  Save instant replay clips from the OBS replay buffer via the OBS MCP
  server. Use for short, imperative commands like "clip that",
  "save the last 30 seconds", "save that last moment", "start the replay
  buffer", or "where did that clip save?". Optimized for fast, hotkey-style
  clipping during gaming or live content.
---

# OBS Replay & Clips

Low-latency replay buffer control. The replay buffer keeps the last N seconds in memory so you can save instant clips on demand.

**Core philosophy**: When the user says "clip that", just save the buffer. Don't ask, don't pre-check.

## When to Use

- "Clip that" / "save that last moment" / "save the last 30 seconds"
- "Save a clip" / "grab a clip"
- "Start the replay buffer" / "enable instant replay"
- "Stop the replay buffer"
- "Where did the clip save?" / "show me the last clip path"

**Do NOT use** for full recordings (use `obs-transport-control`) or for editing/post-processing the saved file.

## Available Tools

All invoked via `execute` with JavaScript `call_tool()`:

- `obs_replay_buffer_status` — `{ outputActive }`. Tells you whether the buffer is running.
- `obs_replay_buffer_toggle` — start if stopped, stop if running.
- `obs_replay_buffer_start` — start the buffer.
- `obs_replay_buffer_stop` — stop the buffer.
- `obs_replay_buffer_save` — **save** the current buffered window to disk. Returns immediately; the file finalizes asynchronously.
- `obs_replay_buffer_get_last_replay` — `{ savedReplayPath }`. The path to the most recent saved clip.

## Critical Behavior

1. **The replay buffer must be running before you can save.** If the user says "clip that" and the buffer is off, return a short, actionable error: "Replay buffer is off. Say 'start the replay buffer' first."
2. **The buffer length (e.g., 30 s) is configured in OBS Settings → Output → Replay Buffer.** You cannot set it via WebSocket on the fly. If the user asks for "last 60 seconds" but the buffer is 30 s, return what's available and note the limit.
3. **`obs_replay_buffer_save` is fire-and-forget.** The file may take a moment to finalize. To get the path, follow up with `obs_replay_buffer_get_last_replay`.
4. **Don't toggle the buffer just to save.** Saving works only while it's actively running.

## Command Mapping

| User says | Action |
|---|---|
| "Clip that" / "save that" | `obs_replay_buffer_save` then `obs_replay_buffer_get_last_replay` |
| "Save the last 30 seconds" | Same — buffer length is fixed in OBS settings |
| "Start the replay buffer" | `obs_replay_buffer_start` |
| "Stop the replay buffer" | `obs_replay_buffer_stop` |
| "Is the replay buffer running?" | `obs_replay_buffer_status` |
| "Where's the last clip?" | `obs_replay_buffer_get_last_replay` |

## Latency-Conscious Behavior

- **Save first, ask questions later.** "Clip that" → call `obs_replay_buffer_save` immediately, then return the path.
- **Don't list the buffer status before saving** unless the save fails.
- **Confirm with the saved path**, not just "Done."

## Example Interactions

### Example 1: Clip that

**User**: "Clip that."

**Agent** (tool):
```javascript
await call_tool('obs_replay_buffer_save', {});
// Brief sleep to let the file finalize
await call_tool('obs_client_sleep', { ms: 500 });
const { savedReplayPath } = await call_tool('obs_replay_buffer_get_last_replay', {});
return { savedReplayPath };
```

**Agent** (chat): "Clip saved: `/Users/me/Movies/Replay 2026-05-18 12-00-00.mkv`"

### Example 2: Save fails (buffer off)

**User**: "Save the last moment."

**Agent** (tool):
```javascript
try {
  await call_tool('obs_replay_buffer_save', {});
} catch (e) {
  const status = await call_tool('obs_replay_buffer_status', {});
  if (!status.outputActive) {
    return { error: 'replay_buffer_off' };
  }
  throw e;
}
```

**Agent** (chat): "Replay buffer is off. Say 'start the replay buffer' first, then I can clip."

### Example 3: Start buffer

**User**: "Start instant replay."

**Agent** (tool):
```javascript
await call_tool('obs_replay_buffer_start', {});
```

**Agent** (chat): "Replay buffer started. Say 'clip that' anytime to save."

### Example 4: Auto-start with stream

**User**: "Start the buffer when I go live."

**Agent** (tool):
```javascript
await call_tool('obs_stream_start', {});
await call_tool('obs_replay_buffer_start', {});
```

**Agent** (chat): "Live, and replay buffer is running."

> Tip: OBS itself has a setting "Automatically start replay buffer when streaming" — recommend the user enable it for hands-off operation.

## Error Handling

- **`Replay Buffer is not active`**: tell the user to start it first.
- **`No replays have been saved yet`** from `get_last_replay`: ask them to save one first or wait for the file to finalize.
- **Connection lost**: surface a connection error.

## Quick Reference

```javascript
// Save the buffer (most common)
await call_tool('obs_replay_buffer_save', {});

// Get the last clip's path
const { savedReplayPath } = await call_tool('obs_replay_buffer_get_last_replay', {});

// Start / stop
await call_tool('obs_replay_buffer_start', {});
await call_tool('obs_replay_buffer_stop', {});

// Status
const { outputActive } = await call_tool('obs_replay_buffer_status', {});
```
