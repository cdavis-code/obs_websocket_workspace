---
name: obs-mcp
description: Control a running OBS Studio instance through the OBS MCP server. Use when the user asks to connect to OBS, list or switch scenes, inspect or transform sources, control audio inputs, start/stop streaming or recording, trigger hotkeys, manage filters or transitions, or run any OBS WebSocket operation. Exposes 60+ tools via an `execute` + JavaScript invocation pattern.
---

# OBS MCP (obs-mcp-stdio)

Agent guide for controlling OBS Studio via the `obs-mcp-stdio` MCP server. The server wraps the [obs_mcp](../../packages/obs_mcp) Dart package and speaks OBS WebSocket v5.x to a locally running OBS instance.

## When to Use

Use this skill whenever the user wants to:
- Check whether OBS is reachable, connect, or disconnect.
- Read OBS state: version, stats, hotkeys, scenes, scene items, inputs.
- Change OBS state: switch scenes, set transforms, mute/volume, create/remove items.
- Drive outputs: streaming, recording, virtual camera, replay buffer.
- Animate a source on-canvas or script a timed sequence.
- Trigger a hotkey, a vendor request, or a raw WebSocket request.

## Prerequisites

Before using this skill, ensure:

1. **OBS Studio is installed** — Download from [obsproject.com](https://obsproject.com). OBS 28+ includes obs-websocket v5.x by default.
2. **OBS is running** — The WebSocket server only accepts connections when OBS Studio is actively running.
3. **WebSocket server is enabled** — In OBS: Tools → obs-websocket Settings → Enable WebSocket server (note the port and password).

**Quick health check** — Run this before any OBS operations:
```javascript
const status = await call_tool('obs_connection_status', {});
if (!status?.connected) {
  return 'OBS is not connected. Ensure OBS Studio is running and the WebSocket server is enabled.';
}
```

**If connection fails repeatedly**, OBS may not be running. Check your system's process list:
- **macOS/Linux**: `ps aux | grep -i 'OBS\|obs64'`
- **Windows**: `tasklist /fi "imagename eq obs64.exe"`

If no OBS process is found, return actionable guidance: *"OBS Studio is not running. Please launch OBS Studio first."*

If the process is running but WebSocket connection fails, prompt the user to verify obs-websocket settings in OBS: **Tools → obs-websocket Settings**.

## MCP Server Availability

This skill requires the `obs-mcp-stdio` server to be registered with the host agent. If `search`/`execute` tool calls fail with "tool not found" or similar errors, the server is not installed or configured.

**Install one of the following distributions:**

| Distribution | Install Command | Package |
|---|---|---|
| Dart (recommended) | `dart pub global activate obs_mcp` | [pub.dev/packages/obs_mcp](https://pub.dev/packages/obs_mcp) |
| npm | `npx @unngh/obs-mcp` (no install) | [npmjs.com/package/@unngh/obs-mcp](https://www.npmjs.com/package/@unngh/obs-mcp) |

**Runtime verification** — If tool discovery works but OBS calls fail, confirm the server responds:
```javascript
try {
  return await call_tool('obs_general_version', {});
} catch (e) {
  return { error: 'MCP server unreachable. See README for install/config.' };
}
```

**Host configuration examples** (place in the agent's MCP config, e.g. `mcp.json`):
```json
{
  "mcpServers": {
    "obs": {
      "command": "obs_mcp",
      "env": {
        "OBS_WEBSOCKET_URL": "ws://localhost:4455",
        "OBS_WEBSOCKET_PASSWORD": "your-password"
      }
    }
  }
}
```
```json
{
  "mcpServers": {
    "obs": {
      "command": "npx",
      "args": ["@unngh/obs-mcp"],
      "env": {
        "OBS_WEBSOCKET_URL": "ws://localhost:4455",
        "OBS_WEBSOCKET_PASSWORD": "your-password"
      }
    }
  }
}
```

For full host-specific setup (Qoder, Claude Desktop, VS Code, OpenCode), see the [obs_mcp README](../../README.md).

## Critical Invocation Pattern

The server exposes only **two** top-level tools: `search` and `execute`. All 60+ OBS operations are invoked **inside JavaScript** passed to `execute`.

**Do NOT** try to call `obs_scenes_list` (or any `obs_*` tool) directly — it is not registered as a top-level MCP tool and will fail with "tool not found".

**Do this instead**:
```javascript
// execute tool, code parameter:
const scenes = await call_tool('obs_scenes_list', {});
return scenes;
```

**Case-sensitivity rule**: OBS object names (scenes, sources, inputs, filters, transitions) are **strictly case-sensitive**. Always preserve the exact case:
- When the user provides a name directly, use it exactly as given (do not alter case)
- When you retrieve a name from OBS (via `obs_scenes_list`, `obs_inputs_list`, etc.), use the exact case returned
- Never normalize, lowercase, or capitalize object names when passing them to OBS tools

Rules:
- Every OBS call is `await call_tool('<tool_name>', { ...params })`.
- Use `Promise.all([...])` to parallelize independent reads.
- `return <value>` from the code to surface results back to the agent.
- Timing/animation must use client-side `setTimeout` (see Gotchas). `obs_general_sleep` sleeps on the server and will **not** pace client loops.

## Discovery Workflow

Before inventing a tool name, discover it:
```javascript
// Via the MCP search tool (not execute):
search({ query: "scene items transform", detail_level: "detailed" })
```
`detail_level` options: `"brief"` (name + description), `"detailed"` (+ parameter names/types/required), `"full"` (complete parameter schemas).

Use `search` when:
- You're unsure of the exact tool name.
- You need the parameter schema for a tool you haven't called before.
- A call fails with a schema error — re-check `detail_level: "full"`.

## Tool Catalog (60+ tools, by category)

All names below are invoked as `call_tool('<name>', {...})` inside `execute`.

### Connection
- `obs_connect` — connect to OBS WebSocket (`url`, `password`, `timeoutSeconds`, `autoReconnect` — defaults to `true`).
- `obs_disconnect` — close the connection.
- `obs_is_connected` — returns `bool`.
- `obs_connection_status` — `{ connected, state, negotiatedRpcVersion }` where `state ∈ disconnected | connecting | connected | reconnecting | failed`.
- `obs_connection_ping` — round-trip `GetVersion` and report latency in ms.
- `obs_send_raw` — send a raw OBS WebSocket request by op code/type.

### Events (subscribe + wait)
- `obs_events_subscribe` — set the active subscription mask. Pass either `mask` (int bitmask) or `subscriptions` (list of names: `general`, `config`, `scenes`, `inputs`, `transitions`, `filters`, `outputs`, `sceneItems`, `mediaInputs`, `vendors`, `ui`, `canvases`, `all`, `inputVolumeMeters`, `inputActiveStateChanged`, `inputShowStateChanged`, `sceneItemTransformChanged`).
- `obs_wait_for_event` — block until the next event whose `eventType` matches (e.g. `RecordStateChanged`, `SceneItemTransformChanged`). Times out after `timeoutMs` (default 30000). You **must** subscribe first.

### Timing
- `obs_client_sleep` — server-side sleep (1–25000 ms). **Prefer this over `setTimeout` inside `execute`** so the JS sandbox subprocess stays idle while the MCP host owns the wall clock (the sandbox has a hard 30 s timeout).
- `obs_general_sleep` — legacy server-side sleep. Use `obs_client_sleep` for new code.

### General
- `obs_general_version` — OBS/websocket/platform versions.
- `obs_general_stats` — CPU %, memory, FPS, render/output frame stats.
- `obs_general_hotkeys` — list registered hotkey names.
- `obs_general_trigger_hotkey` — trigger by hotkey name.
- `obs_general_trigger_hotkey_by_key` — trigger by key id + modifiers.
- `obs_general_sleep` — **server-side** sleep (ms). Do not use for client-paced loops.
- `obs_general_broadcast_custom_event` — broadcast an arbitrary JSON event.
- `obs_general_call_vendor_request` — call a vendor (plugin) request.

### Scenes
- `obs_scenes_list` — list scenes and current program/preview.
- `obs_scenes_group_list` — list groups.
- `obs_scenes_get_current_program`, `obs_scenes_set_current_program`.
- `obs_scenes_get_current_preview`, `obs_scenes_set_current_preview`.
- `obs_scenes_create`, `obs_scenes_remove`, `obs_scenes_set_name`.
- `obs_scenes_get_transition_override`, `obs_scenes_set_transition_override`.

### Scene Items
- `obs_scene_items_list` — list items in a scene (names, IDs, transforms).
- `obs_scene_items_get_id` — resolve `sceneItemId` by source name.
- `obs_scene_items_get_transform` — returns the **flat** transform shape (same field names as `set_transform`). Includes `positionX/Y`, `scaleX/Y`, `rotation`, `cropLeft/Top/Right/Bottom`, `alignment`, `boundsType`, `boundsAlignment`, `boundsWidth/Height`, plus read-only `sourceWidth/Height` and `width/height`.
- `obs_scene_items_set_transform` — full set: `positionX/Y`, `scaleX/Y`, `rotation`, `cropLeft/Top/Right/Bottom`, **`alignment`**, **`boundsType`**, **`boundsAlignment`**, **`boundsWidth/Height`**. Returns the canonical post-set transform.
- `obs_scene_items_animate_transform` — server-side animation from current → target over `durationMs` at `frameRate` fps (1–60). Easings: `linear`, `easeIn`, `easeOut`, `easeInOut`, `easeOutBounce`. Optional `restoreOnComplete` for transient "bump" animations. Survives reconnects and is not bound by the JS sandbox 30 s timeout.
- `obs_scene_items_set_enabled`, `obs_scene_items_get_enabled`.
- `obs_scene_items_set_locked`, `obs_scene_items_get_locked`.
- `obs_scene_items_set_index`, `obs_scene_items_get_index` — z-order.
- `obs_scene_items_set_blend_mode`, `obs_scene_items_get_blend_mode`.
- `obs_scene_items_create`, `obs_scene_items_duplicate`, `obs_scene_items_remove`.
- `obs_scene_items_get_private_settings`, `obs_scene_items_set_private_settings`.

### Inputs
- `obs_inputs_list`, `obs_inputs_get_kind_list`, `obs_inputs_get_special`.
- `obs_inputs_create`, `obs_inputs_remove`, `obs_inputs_set_name`.
- `obs_inputs_get_default_settings`, `obs_inputs_get_settings`, `obs_inputs_set_settings`.
- `obs_inputs_get_mute`, `obs_inputs_set_mute`, `obs_inputs_toggle_mute`.
- `obs_inputs_get_volume`, `obs_inputs_set_volume`.
- `obs_inputs_get_audio_balance`, `obs_inputs_set_audio_balance`.
- `obs_inputs_get_audio_sync_offset`, `obs_inputs_set_audio_sync_offset`.
- `obs_inputs_get_audio_monitor_type`, `obs_inputs_set_audio_monitor_type`.
- `obs_inputs_get_audio_tracks`, `obs_inputs_set_audio_tracks`.
- `obs_inputs_get_properties_list_property_items`, `obs_inputs_press_properties_button`.

### Media Inputs
- `obs_media_get_status`, `obs_media_set_cursor`, `obs_media_offset_cursor`.
- `obs_media_trigger_action` — play / pause / restart / stop / next / previous.

### Sources
- `obs_sources_get_active`, `obs_sources_get_screenshot`, `obs_sources_save_screenshot`.

### Transitions
- `obs_transitions_list`, `obs_transitions_get_kind_list`.
- `obs_transitions_get_current`, `obs_transitions_set_current`.
- `obs_transitions_get_current_cursor`, `obs_transitions_trigger_studio_mode`.
- `obs_transitions_get_duration`, `obs_transitions_set_duration`.
- `obs_transitions_get_settings`, `obs_transitions_set_settings`.

### Filters
- `obs_filters_list`, `obs_filters_get_default_settings`, `obs_filters_get_kind_list`.
- `obs_filters_create`, `obs_filters_remove`, `obs_filters_set_name`, `obs_filters_set_index`.
- `obs_filters_get`, `obs_filters_set_settings`, `obs_filters_set_enabled`.

### Outputs
- `obs_outputs_list`, `obs_outputs_get_status`, `obs_outputs_toggle`.
- `obs_outputs_start`, `obs_outputs_stop`, `obs_outputs_get_settings`, `obs_outputs_set_settings`.

### Streaming
- `obs_stream_status`, `obs_stream_toggle`, `obs_stream_start`, `obs_stream_stop`.
- `obs_stream_send_caption`.

### Recording
- `obs_record_status`, `obs_record_toggle`, `obs_record_start`, `obs_record_stop`.
- `obs_record_toggle_pause`, `obs_record_pause`, `obs_record_resume`.
- `obs_record_split_file`, `obs_record_create_chapter`, `obs_record_directory`.

### Virtual Camera
- `obs_virtual_cam_status`, `obs_virtual_cam_toggle`, `obs_virtual_cam_start`, `obs_virtual_cam_stop`.

### Replay Buffer
- `obs_replay_buffer_status`, `obs_replay_buffer_toggle`.
- `obs_replay_buffer_start`, `obs_replay_buffer_stop`, `obs_replay_buffer_save`.
- `obs_replay_buffer_get_last_replay`.

### Canvas / Projectors
- `obs_canvas_get_video_settings`, `obs_canvas_set_video_settings`.
- `obs_canvas_open_projector`.

### Configuration
- `obs_config_get_profile_parameter`, `obs_config_set_profile_parameter`.
- `obs_config_get_persistent_data`, `obs_config_set_persistent_data`.
- `obs_config_list_scene_collections`, `obs_config_get_current_scene_collection`, `obs_config_set_current_scene_collection`.
- `obs_config_create_scene_collection`, `obs_config_list_profiles`, `obs_config_get_current_profile`, `obs_config_set_current_profile`, `obs_config_create_profile`, `obs_config_remove_profile`.
- `obs_config_get_record_directory`, `obs_config_set_record_directory`.
- `obs_config_get_stream_service_settings`, `obs_config_set_stream_service_settings`.

### UI
- `obs_ui_get_studio_mode_enabled`, `obs_ui_set_studio_mode_enabled`.
- `obs_ui_open_input_properties_dialog`, `obs_ui_open_input_filters_dialog`, `obs_ui_open_input_interact_dialog`.
- `obs_ui_open_video_mix_projector`, `obs_ui_open_source_projector`, `obs_ui_open_scene_projector`.
- `obs_ui_open_video_mix_window_projector`, `obs_ui_open_source_window_projector`, `obs_ui_open_scene_window_projector`.
- `obs_ui_get_monitor_list`.

> Always confirm exact parameter names with `search(detail_level: "detailed" | "full")` before calling an unfamiliar tool — this catalog lists tool names only.

## Common Workflows

### 1. Verify connection before any work
```javascript
const status = await call_tool('obs_connection_status', {});
if (!status?.connected) {
  // Attempt to connect (credentials from env/.env or explicit params)
  const result = await call_tool('obs_connect', {
    url: 'ws://localhost:4455',
    autoReconnect: true,
  });
  
  // Verify connection succeeded
  const afterStatus = await call_tool('obs_connection_status', {});
  if (!afterStatus?.connected) {
    return {
      error: 'Failed to connect to OBS',
      troubleshooting: [
        'Ensure OBS Studio is running (check process list)',
        'Verify WebSocket server is enabled: Tools → obs-websocket Settings',
        'Check URL and password are correct'
      ]
    };
  }
}
return await call_tool('obs_general_version', {});
```

### 2. Inventory the active scene
```javascript
const scenes = await call_tool('obs_scenes_list', {});
const current = scenes.currentProgramSceneName;
const items = await call_tool('obs_scene_items_list', { sceneName: current });
return { scene: current, items };
```

### 3. Resolve a source by name, then read its transform
```javascript
const sceneName = (await call_tool('obs_scenes_list', {})).currentProgramSceneName;
const { sceneItemId } = await call_tool('obs_scene_items_get_id', {
  sceneName, sourceName: 'Follow Test'
});
// get_transform now returns the flat shape (same field names as set_transform).
const transform = await call_tool('obs_scene_items_get_transform', {
  sceneName, sceneItemId
});
return { sceneItemId, transform };
```

### 4. Transform a source (position / rotation / scale)
```javascript
await call_tool('obs_scene_items_set_transform', {
  sceneName: 'Scene',
  sceneItemId: 4,
  positionX: 100,
  positionY: 100,
  rotation: 0
});
```
Always save the original transform first so you can restore it.

### 5. Animate a source
**Preferred (server-side, survives the 30 s sandbox timeout, supports easing):**
```javascript
await call_tool('obs_scene_items_animate_transform', {
  sceneName: 'Scene',
  sceneItemId: 4,
  durationMs: 1500,
  targetPositionX: 1820,
  targetPositionY: 980,
  frameRate: 60,
  easing: 'easeOutBounce',
  restoreOnComplete: true,
});
```
See [scripts/animate-source.js](scripts/animate-source.js) for the legacy client-paced template (still useful when you need per-frame logic that the server-side tool can't express).

Key requirements when client-pacing:
- Pace frames with `await call_tool('obs_client_sleep', { ms: 16 })` (~60 fps). `obs_client_sleep` does **not** keep the sandbox subprocess busy the way `setTimeout` does, so it is safe under the 30 s sandbox timeout.
- Interpolate `positionX`/`positionY` only. Keep rotation/scale fixed unless animating them too.
- When the user says "move the mid-point of the source to X", compute `posX = X - width/2`, `posY = Y - height/2` from `width`/`height` on the flat transform.
- Restore the original transform at the end (or pass `restoreOnComplete: true` to the server-side animator).

### 6. Record a clip with lead-in / lead-out
See [scripts/record-with-leadin.js](scripts/record-with-leadin.js).

**Recommended pattern** (uses `obs_client_sleep` so the sandbox stays idle, and waits for the actual `RecordStateChanged` event instead of polling):
```javascript
await call_tool('obs_events_subscribe', { subscriptions: ['outputs'] });
await call_tool('obs_record_start', {});
await call_tool('obs_wait_for_event', {
  eventType: 'RecordStateChanged',
  timeoutMs: 5000,
});
await call_tool('obs_client_sleep', { ms: leadInMs });
await runAnimation();
await call_tool('obs_client_sleep', { ms: leadOutMs });
const { outputPath } = await call_tool('obs_record_stop', {});
return outputPath;
```
Recording directory defaults to the value returned by `obs_config_get_record_directory` (e.g. `/Users/<me>/Movies` on macOS).

### 7. Toggle streaming / recording / virtual cam
```javascript
await call_tool('obs_stream_toggle', {});        // start or stop stream
await call_tool('obs_record_toggle', {});        // start or stop recording
await call_tool('obs_virtual_cam_toggle', {});   // start or stop virtual cam
```

### 8. Audio controls
```javascript
await call_tool('obs_inputs_set_mute',  { inputName: 'Mic/Aux', inputMuted: true });
await call_tool('obs_inputs_set_volume', { inputName: 'Mic/Aux', inputVolumeDb: -6.0 });
```

### 9. Switch scenes (studio mode aware)
```javascript
const studio = await call_tool('obs_ui_get_studio_mode_enabled', {});
if (studio.studioModeEnabled) {
  await call_tool('obs_scenes_set_current_preview', { sceneName: 'Break' });
  await call_tool('obs_transitions_trigger_studio_mode', {});
} else {
  await call_tool('obs_scenes_set_current_program', { sceneName: 'Break' });
}
```

### 10. Trigger a hotkey
```javascript
const { hotkeys } = await call_tool('obs_general_hotkeys', {});
await call_tool('obs_general_trigger_hotkey', { hotkeyName: 'OBSBasic.StartRecording' });
```

## Execute Environment Limitations

1. **Keep scripts short and simple.** Accessing nested properties from tool call results (e.g., `items[0].sceneItemTransform.width`) frequently causes silent errors. Complex scripts with multiple tool calls and control flow often fail. Split operations into multiple small `execute` calls rather than one large script.

2. **Object names are strictly case-sensitive.** `sceneName: 'Main'` and `sceneName: 'main'` are different scenes. `inputName: 'Mic'` and `inputName: 'mic'` are different inputs. Always use the exact case:
   - **User-provided names**: Use exactly as the user typed them (do not alter case)
   - **OBS-returned names**: Use the exact case from `obs_scenes_list`, `obs_inputs_list`, etc.
   - Never normalize, lowercase, title-case, or otherwise modify object names

3. **Reading dimensions after text/settings changes requires a separate call.** After updating text via `obs_inputs_set_settings`, the source dimensions change. You must call `obs_scene_items_list` again in a **separate** `execute` invocation to get the updated width/height. Doing it in the same script often returns stale or null values.

4. **The JS sandbox has a hard 30 s subprocess timeout.** Any animation, lead-in, or wait that approaches 30 s should run via `obs_scene_items_animate_transform`, `obs_client_sleep`, or `obs_wait_for_event` so the work happens on the MCP host instead of inside the Node.js subprocess.

## Gotchas & Best Practices

0. **OBS must be running first.** WebSocket connection timeouts usually mean OBS Studio isn't launched or the WebSocket server isn't enabled. Check the process list before debugging connection issues (see [Prerequisites](#prerequisites)).
1. **Prefer `obs_client_sleep` over `setTimeout`.** `obs_general_sleep` and `obs_client_sleep` both pause server-side; the JS sandbox's `setTimeout` keeps the Node.js subprocess busy and competes with the 30 s sandbox timeout. For new code use `obs_client_sleep`.
2. **Snapshot before you mutate.** Call `obs_scene_items_get_transform` and store the result before animating so you can restore exactly. The shape now matches `set_transform` (flat fields), so `Object.assign({}, transform)` round-trips cleanly.
3. **Use UUIDs when ambiguous.** `sceneUuid` and `sourceUuid` are safer than names if the user might rename things mid-session.
4. **Canvas size matters for positioning.** Read `obs_canvas_get_video_settings` to get `baseWidth`/`baseHeight` — don't hard-code 1920×1080.
5. **Minimize round-trips.** Parallelize independent reads with `Promise.all([...])`.
6. **Transform fields are now symmetric.** Both `obs_scene_items_get_transform` and `obs_scene_items_set_transform` use the same flat field names: `positionX`, `positionY`, `scaleX`, `scaleY`, `rotation`, `cropLeft`, `cropTop`, `cropRight`, `cropBottom`, `alignment`, `boundsType`, `boundsAlignment`, `boundsWidth`, `boundsHeight`. The legacy nested `{ sceneItemTransform: {...} }` shape is no longer returned.
7. **Animations swallow errors silently.** Wrap loops in `try/finally` and always restore the original transform in `finally` (or use `restoreOnComplete: true` on `obs_scene_items_animate_transform`).
8. **Recording and streaming are asynchronous.** After `obs_record_stop`, the file path may not be available until the output flushes; subscribe to `outputs` and `obs_wait_for_event` on `RecordStateChanged` instead of polling `obs_record_status`.
9. **Don't call tools concurrently on the same scene item.** Serialize writes to avoid race conditions in OBS.
10. **Auto-reconnect is on by default.** `obs_connect` enables exponential-backoff reconnect (200 ms → 5 s, max 5 attempts). Use `obs_connection_status` to read the current `state` (`connected | reconnecting | failed`) instead of assuming the link is alive after a tool error.
11. **`obs_scene_items_set_transform` accepts the full transform.** `alignment`, `boundsType`, `boundsAlignment`, `boundsWidth`, and `boundsHeight` are all settable directly — no need to fall back to `obs_send_raw`.
12. **Alignment affects position interpretation.** Alignment 5 = center anchor (positionX/Y is the center of the source). Alignment 0 = top-left anchor (positionX/Y is the top-left corner). Always read the current alignment before calculating positions.
13. **Centering formula depends on alignment.** With alignment 0 (top-left): `positionX = canvasCenter - (width / 2)`. With alignment 5 (center): `positionX = canvasCenter` directly. Get the alignment from `obs_scene_items_get_transform` or `obs_scene_items_list` first.
14. **Subscribe before you wait.** `obs_wait_for_event` will hang (and ultimately time out) for events outside the active subscription mask. Call `obs_events_subscribe` first with the relevant group(s).

## Scripts

Reusable templates the agent can copy into `execute`:

- [scripts/connection-check.js](scripts/connection-check.js) — verify/auto-connect + print version.
- [scripts/animate-source.js](scripts/animate-source.js) — corner-tour animation with `easeOutBounce` and mid-point offset.
- [scripts/record-with-leadin.js](scripts/record-with-leadin.js) — wrap any async function with recording + lead-in/lead-out.

## References

- Server package: [packages/obs_mcp](../../packages/obs_mcp)
- OBS WebSocket v5 protocol: <https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md>
- Anthropic skill best practices: <https://docs.claude.com/en/agents-and-tools/agent-skills/best-practices>
