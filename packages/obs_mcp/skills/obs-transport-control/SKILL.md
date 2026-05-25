---
name: obs-transport-control
description: >
  Control OBS streaming, recording, and virtual camera transport via the
  OBS MCP server. Use for short, imperative commands like
  "go live", "start the stream", "end the stream after this segment",
  "start recording", "pause the recording", "stop recording",
  "turn on virtual camera", or "kill the virtual cam".
  Optimized for low-latency, hotkey-style transport control.
---

# OBS Transport Control

Low-latency control for the four core OBS "transport" operations: streaming, recording, recording pause, and virtual camera.

**Core philosophy**: Treat this as a hotkey replacement — recognize intent, call the tool once, confirm.

## When to Use

- "Go live" / "start streaming" / "start the stream"
- "End the stream" / "stop streaming" / "go offline"
- "Start recording" / "record this" / "start the local recording"
- "Stop recording" / "end the recording"
- "Pause the recording" / "resume recording"
- "Turn on virtual camera" / "start virtual cam"
- "Turn off virtual camera" / "stop virtual cam"

**Do NOT use** for replay buffer (use `obs-replay-clips`), audio mute (use `obs-audio-control`), or scene switching (use `obs-fast-scene-switcher`).

## Available Tools

All invoked via `execute` with JavaScript `call_tool()`:

### Streaming
- `obs_stream_status` — `{ outputActive, outputReconnecting, outputTimecode, outputDuration, outputBytes, outputSkippedFrames, outputTotalFrames }`
- `obs_stream_toggle` — start if stopped, stop if running. Returns `{ outputActive }`.
- `obs_stream_start` — start streaming.
- `obs_stream_stop` — stop streaming.

### Recording
- `obs_record_status` — `{ outputActive, outputPaused, outputTimecode, outputDuration, outputBytes }`
- `obs_record_toggle` — start if stopped, stop if running.
- `obs_record_start` — start recording.
- `obs_record_stop` — stop recording. Returns `{ outputPath }` (file path).
- `obs_record_toggle_pause` — pause if recording, resume if paused.
- `obs_record_pause` / `obs_record_resume` — explicit pause/resume.
- `obs_record_split_file` — split current recording into a new file.
- `obs_record_create_chapter` — insert a chapter marker (optional `chapterName`).

### Virtual Camera
- `obs_virtual_cam_status` — `{ outputActive }`
- `obs_virtual_cam_toggle` — start if stopped, stop if running.
- `obs_virtual_cam_start` / `obs_virtual_cam_stop`.

## Command Mapping

| User says | Tool | Notes |
|---|---|---|
| "Go live" / "start streaming" | `obs_stream_start` | Confirm: "Stream started." |
| "Stop the stream" / "go offline" | `obs_stream_stop` | Confirm with duration if available. |
| "Toggle the stream" / "flip streaming" | `obs_stream_toggle` | Use when state is unclear. |
| "Start recording" | `obs_record_start` | Confirm: "Recording started." |
| "Stop recording" | `obs_record_stop` | Return `outputPath` to user. |
| "Pause recording" | `obs_record_pause` | |
| "Resume recording" | `obs_record_resume` | |
| "Mark a chapter" / "chapter point" | `obs_record_create_chapter` | Pass `chapterName` if user names it. |
| "Split the recording" | `obs_record_split_file` | Continues recording in a new file. |
| "Start virtual cam" | `obs_virtual_cam_start` | |
| "Stop virtual cam" | `obs_virtual_cam_stop` | |

## Latency-Conscious Behavior

1. **Don't pre-check status before toggling** unless the user's phrasing is ambiguous. Just call the tool.
2. **For "go live", call `obs_stream_start` immediately** — do not check status first. If it's already running, OBS will return an error you can pass back.
3. **Confirm after the action**, including useful feedback (recording path, stream duration).
4. **No confirmation prompts.** "Go live" means go live, not "should I?".

## Conditional / Compound Commands

If the user says something like "end the stream after this segment" or "stop recording in 5 minutes":

```javascript
// Wait, then stop. Use obs_client_sleep, NOT setTimeout.
await call_tool('obs_client_sleep', { ms: 300000 }); // 5 min
await call_tool('obs_stream_stop', {});
```

Note the JS sandbox has a 30-second timeout. For longer waits, see `obs-timed-recording` skill.

## Example Interactions

### Example 1: Go live

**User**: "Go live."

**Agent** (tool):
```javascript
await call_tool('obs_stream_start', {});
```

**Agent** (chat): "Stream started."

### Example 2: Stop recording with feedback

**User**: "Stop recording."

**Agent** (tool):
```javascript
const result = await call_tool('obs_record_stop', {});
return result;
```

**Agent** (chat): "Recording stopped. Saved to `/Users/me/Movies/2026-05-18 12-00-00.mkv`."

### Example 3: Toggle pause

**User**: "Pause the recording."

**Agent** (tool):
```javascript
await call_tool('obs_record_pause', {});
```

**Agent** (chat): "Recording paused. Say 'resume' to continue."

### Example 4: Mark a chapter

**User**: "Mark a chapter called intro done."

**Agent** (tool):
```javascript
await call_tool('obs_record_create_chapter', { chapterName: 'intro done' });
```

**Agent** (chat): "Chapter 'intro done' marked."

## Error Handling

If a transport tool fails:
- Likely cause 1: the action was already in that state (e.g., starting a stream that's already running). Return: "Stream is already running."
- Likely cause 2: OBS disconnected. Check `obs_connection_status` and surface a short error.
- Likely cause 3: misconfigured stream service. Suggest checking OBS Settings → Stream.

## Quick Reference

```javascript
// Streaming
await call_tool('obs_stream_start', {});
await call_tool('obs_stream_stop', {});
const stream = await call_tool('obs_stream_status', {});

// Recording
await call_tool('obs_record_start', {});
const { outputPath } = await call_tool('obs_record_stop', {});
await call_tool('obs_record_pause', {});
await call_tool('obs_record_resume', {});
await call_tool('obs_record_create_chapter', { chapterName: 'highlight' });

// Virtual camera
await call_tool('obs_virtual_cam_toggle', {});
```
