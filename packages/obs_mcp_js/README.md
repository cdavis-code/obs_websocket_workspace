![obs_mcp_js banner](https://raw.githubusercontent.com/cdavis-code/obs_websocket_workspace/main/packages/obs_mcp_js/image/banner.svg)

# @unngh/obs-mcp

MCP server for controlling OBS Studio via AI agents — 60+ tools for scenes, streaming, recording, and more.

[![npm version](https://img.shields.io/npm/v/@unngh/obs-mcp.svg)](https://www.npmjs.com/package/@unngh/obs-mcp)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://github.com/cdavis-code/obs_websocket_workspace/blob/master/LICENSE)
[![Node.js](https://img.shields.io/badge/Node.js-%3E%3D18-brightgreen)](https://nodejs.org/)

## Quick Start

```bash
OBS_WEBSOCKET_URL=ws://localhost:4455 OBS_WEBSOCKET_PASSWORD=your_password npx @unngh/obs-mcp
```

That's it. The server connects to OBS and exposes tools over [MCP](https://modelcontextprotocol.io/) stdio transport.

## MCP Host Configuration

### Claude Desktop

Add to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "obs": {
      "command": "npx",
      "args": ["@unngh/obs-mcp"],
      "env": {
        "OBS_WEBSOCKET_URL": "ws://localhost:4455",
        "OBS_WEBSOCKET_PASSWORD": "your_password"
      }
    }
  }
}
```

### VS Code

Add to `.vscode/mcp.json` in your workspace:

```json
{
  "servers": {
    "obs": {
      "command": "npx",
      "args": ["@unngh/obs-mcp"],
      "env": {
        "OBS_WEBSOCKET_URL": "ws://localhost:4455",
        "OBS_WEBSOCKET_PASSWORD": "your_password"
      }
    }
  }
}
```

### Cursor

Add to your Cursor MCP settings:

```json
{
  "mcpServers": {
    "obs": {
      "command": "npx",
      "args": ["@unngh/obs-mcp"],
      "env": {
        "OBS_WEBSOCKET_URL": "ws://localhost:4455",
        "OBS_WEBSOCKET_PASSWORD": "your_password"
      }
    }
  }
}
```

### Generic MCP Client

Spawn the process and communicate via stdio (newline-delimited JSON):

```bash
npx @unngh/obs-mcp
```

## Code Mode

This server implements **code mode**, a pattern that pairs a `search` tool with an `execute` tool to give AI agents flexible access to complex functionality. Instead of exposing 60+ individual MCP tools directly, the server exposes just two top-level tools:

- **`search`** — discover available operations by query, with configurable detail levels (`"brief"`, `"detailed"`, or `"full"` for complete parameter schemas).
- **`execute`** — run JavaScript code that can call any of the 60+ OBS tools via `await call_tool('<tool_name>', { params })`.

### Why Code Mode?

Code mode, [popularized by Cloudflare's MCP servers](https://blog.cloudflare.com/code-mode/), offers several advantages:

1. **Flexibility** — Agents can compose multiple tool calls in a single execution, use control flow, and handle complex workflows without round-trip overhead.
2. **Discoverability** — The `search` tool lets agents find the right operation without memorizing tool names.
3. **Reduced token overhead** — A single script replaces multiple tool call steps.

## Features

All tools are prefixed with `obs_` and organized into the following groups:

| Group | Tools | Description |
|---|---|---|
| **Connection** | `connect`, `disconnect`, `is_connected`, `send_raw` | Manage the WebSocket connection to OBS |
| **General** | `general_version`, `general_stats`, `general_hotkeys`, `general_trigger_hotkey`, `general_trigger_hotkey_by_key`, `general_sleep`, `general_broadcast_custom_event`, `general_call_vendor_request` | Retrieve OBS version/stats, trigger hotkeys, broadcast custom events, vendor requests |
| **Scenes** | `scenes_list`, `scenes_group_list`, `scenes_get_current_program`, `scenes_set_current_program`, `scenes_get_current_preview`, `scenes_set_current_preview`, `scenes_create` | List, switch, and create scenes |
| **Scene Items** | `scene_items_list`, `scene_items_group_list`, `scene_items_get_id`, `scene_items_get_enabled`, `scene_items_set_enabled`, `scene_items_get_locked`, `scene_items_set_locked`, `scene_items_get_transform`, `scene_items_set_transform`, `scene_items_get_source`, `scene_items_get_private_settings`, `scene_items_set_private_settings`, `scene_items_create`, `scene_items_duplicate`, `scene_items_remove` | Query and control items within scenes, including position/scale/rotation/crop and private settings |
| **Inputs** | `inputs_list`, `inputs_kind_list`, `inputs_special`, `inputs_get_default_settings`, `inputs_get_mute`, `inputs_set_mute`, `inputs_toggle_mute`, `inputs_get_volume`, `inputs_set_volume`, `inputs_get_settings`, `inputs_set_settings`, `inputs_set_name`, `inputs_create`, `inputs_remove` | Manage audio/video inputs, mute, volume, and settings |
| **Inputs — Audio** | `inputs_get_audio_balance`, `inputs_set_audio_balance`, `inputs_get_audio_sync_offset`, `inputs_set_audio_sync_offset`, `inputs_get_audio_monitor_type`, `inputs_set_audio_monitor_type`, `inputs_get_audio_tracks`, `inputs_set_audio_tracks` | Control input audio properties: balance, sync offset, monitor type, and audio tracks |
| **Inputs — Properties** | `inputs_get_properties_list_items`, `inputs_press_properties_button`, `inputs_get_deinterlace_mode`, `inputs_set_deinterlace_mode`, `inputs_get_deinterlace_field_order`, `inputs_set_deinterlace_field_order` | Interact with input properties dialog and deinterlace settings |
| **Sources** | `sources_get_active`, `sources_get_screenshot`, `sources_save_screenshot`, `sources_get_private_settings`, `sources_set_private_settings` | Source state, screenshots, and private settings |
| **Media Inputs** | `media_inputs_get_status`, `media_inputs_set_cursor`, `media_inputs_offset_cursor`, `media_inputs_trigger_action` | Control media playback |
| **Stream** | `stream_status`, `stream_start`, `stream_stop`, `stream_toggle`, `stream_send_caption` | Control live streaming and send captions |
| **Record** | `record_status`, `record_start`, `record_stop`, `record_toggle`, `record_pause`, `record_resume`, `record_toggle_pause` | Control recording sessions |
| **Outputs** | `outputs_virtual_cam_status/toggle/start/stop`, `outputs_replay_buffer_status/toggle/start/stop/save`, `outputs_list`, `outputs_toggle/start/stop`, `outputs_get_status`, `outputs_get_settings`, `outputs_set_settings` | Manage virtual camera, replay buffer, and arbitrary outputs |
| **Config** | `config_record_directory`, `config_stream_service_settings` | Read recording directory and stream service configuration |
| **UI** | `ui_studio_mode_enabled`, `ui_set_studio_mode`, `ui_open_input_properties/filters/interact`, `ui_monitor_list` | Toggle Studio Mode, open input dialogs, list monitors |
| **Transitions** | `transitions_trigger_studio`, `transitions_kind_list`, `transitions_scene_list`, `transitions_get_current`, `transitions_set_current`, `transitions_set_duration`, `transitions_set_settings`, `transitions_get_cursor`, `transitions_set_t_bar` | Manage scene transitions: list kinds, configure, T-Bar control |
| **Filters** | `filters_kind_list`, `filters_list`, `filters_default_settings`, `filters_create`, `filters_remove`, `filters_rename`, `filters_get`, `filters_set_index`, `filters_set_settings`, `filters_set_enabled` | Manage source filters: create, remove, configure, and reorder |
| **Canvases** | `canvases_list`, `video_settings` | List canvases configured in OBS (v5.7.0+) and read base/output dimensions + FPS via the legacy `GetVideoSettings` request that works on every v5+ build |

### What Can You Do?

Here's a quick example of what AI agents can do with these tools. The code below is passed to the `execute` tool:

```javascript
// Discover available scene tools
const tools = await call_tool('search', { query: 'scene', detail_level: 'detailed' });

// Switch scenes and start recording
await call_tool('obs_scenes_set_current_program', { sceneName: 'Live Scene' });
await call_tool('obs_record_start', {});

// Animate a source
await call_tool('obs_scene_items_animate_transform', {
  sceneName: 'Live Scene',
  sceneItemId: 3,
  durationMs: 1000,
  targetPositionX: 960,
  targetPositionY: 540
});
```

## Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `OBS_WEBSOCKET_URL` | WebSocket URL for OBS | **Required** |
| `OBS_WEBSOCKET_PASSWORD` | Authentication password | None (no auth) |
| `OBS_WEBSOCKET_TIMEOUT` | Connection timeout in seconds | `120` |
| `OBS_MCP_DEBUG` | Enable stderr debug logging | `0` (disabled) |

## Requirements

- **Node.js >= 18** (Node 22+ uses native WebSocket; 18–21 uses `ws` polyfill)
- **OBS Studio** with the [WebSocket server enabled](https://github.com/obsproject/obs-websocket) (v5.x)

## Debugging

Enable verbose stderr logging with:

```bash
OBS_MCP_DEBUG=1 OBS_WEBSOCKET_URL=ws://localhost:4455 npx @unngh/obs-mcp
```

All protocol messages and connection events are logged to stderr when enabled.

## Building from Source

For contributors working on the package itself:

```bash
dart pub get
npm install
npm run build
```

Requires Dart SDK ^3.8.0 and Node.js >= 18.

## License

[MIT](https://github.com/cdavis-code/obs_websocket_workspace/blob/master/LICENSE)
