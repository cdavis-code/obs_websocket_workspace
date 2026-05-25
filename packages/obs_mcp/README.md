# obs_mcp

![obs_mcp banner](https://raw.githubusercontent.com/cdavis-code/obs_websocket_workspace/main/packages/obs_mcp/image/banner.svg)

<p align="center">
  <strong>MCP Server for OBS Studio</strong><br/>
  Control OBS Studio via the Model Context Protocol • Built with Dart • WebSocket v5.x
</p>

<p align="center">
  <a href="https://pub.dev/packages/obs_mcp"><img src="https://img.shields.io/pub/v/obs_mcp.svg?label=pub.dev&labelColor=333940&logo=dart&logoColor=fff" alt="Pub"></a>
  <a href="https://github.com/cdavis-code/obs_websocket_workspace"><img src="https://img.shields.io/github/stars/cdavis-code/obs_websocket_workspace?label=stars&logo=github&labelColor=333940" alt="GitHub stars"></a>
  <a href="https://pub.dev/packages/skills"><img src="https://img.shields.io/badge/AI%20Agent%20Skill-included-00b4ab?logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZmlsbD0iI2ZmZiIgZD0iTTEyIDJMMTMuMDkgOC4yNkwyMCA5TDEzLjA5IDE1Ljc0TDE1IDIyTDEyIDE4Ljc3TDkgMjJMMSAuOTkgMTcuNzRMNSAxNUwtMiA5TDUgOC4yNkwxMiAyWiIvPjwvc3ZnPg==" alt="AI Agent Skill"></a>
</p>

---

A standalone MCP (Model Context Protocol) server for controlling OBS Studio via the obs-websocket v5.x protocol. Built on top of the [`obs_websocket`](https://pub.dev/packages/obs_websocket) Dart library, it exposes OBS operations as MCP tools over stdio transport.

## Table of Contents

- [obs\_mcp](#obs_mcp)
  - [Table of Contents](#table-of-contents)
  - [What's New in v5.7.0](#whats-new-in-v570)
  - [Quick Start](#quick-start)
    - [Option 1: Global Activation (Recommended for End-Users)](#option-1-global-activation-recommended-for-end-users)
    - [Option 2: Homebrew (macOS / Linux)](#option-2-homebrew-macos--linux)
  - [Code Mode](#code-mode)
    - [Why Code Mode?](#why-code-mode)
  - [Features](#features)
    - [What Can You Do?](#what-can-you-do)
  - [AI Agent Skill](#ai-agent-skill)
  - [Configuration](#configuration)
  - [Development Setup](#development-setup)
    - [Prerequisites](#prerequisites)
    - [Running from Source](#running-from-source)
    - [Code Generation](#code-generation)
  - [Testing with MCP Inspector](#testing-with-mcp-inspector)
  - [Contributing](#contributing)
  - [License](#license)

## What's New in v5.7.0

This release adds comprehensive support for OBS WebSocket v5.7.0 features:

**Note:** Some features (Canvases, Scene Item private settings) require OBS with obs-websocket v5.7.0 or later.

- **Canvases**: New `canvases_list` tool to list all configured canvases
- **Input Audio Properties**: Full control over audio balance, sync offset, monitor type, and audio tracks
- **Input Properties Dialog**: Access to list property items and button presses
- **Scene Items Extended**: Access to source names and private settings
- **Transitions**: Complete transition management including kind listing, configuration, and T-Bar control
- **Filters**: Full filter lifecycle management (create, remove, rename, configure, reorder)
- **Outputs Extended**: List all outputs, get/set output status and settings

## Quick Start

**For end-users:** The recommended approach is to globally activate the package (Option 1). This makes the `obs_mcp` command available on your PATH and is the easiest way to use the MCP server with AI agents like Qoder, Claude Desktop, or VS Code.

**For developers:** If you need to modify the source code or add new tools, see the [Development Setup](#development-setup) section below.

### Option 1: Global Activation (Recommended for End-Users)

```bash
# Activate the package globally (makes the 'obs_mcp' command available)
dart pub global activate obs_mcp

# Set connection details via environment variables (or use a .env file)
export OBS_WEBSOCKET_URL=ws://localhost:4455
export OBS_WEBSOCKET_PASSWORD=your-password
```

That's it! Configure your AI agent using one of the [MCP Host Configuration](#mcp-host-configuration) examples below, and the agent will launch the server automatically.

### Option 2: Homebrew (macOS / Linux)

If you use the [`brew`](https://brew.sh/) package manager, you can install a pre-built `obs-mcp` binary without needing the Dart SDK on your PATH:

```sh
brew tap cdavis-code/obs-websocket
brew install obs-mcp
```

This installs the `obs-mcp` executable on your PATH. Set your connection details the same way as Option 1:

```sh
export OBS_WEBSOCKET_URL=ws://localhost:4455
export OBS_WEBSOCKET_PASSWORD=your-password
```

Then point your MCP host at the `obs-mcp` command (instead of `obs_mcp`) in the [MCP Host Configuration](#mcp-host-configuration) examples below.

## Code Mode

This server implements **code mode**, a pattern that pairs a `search` tool with an `execute` tool to give AI agents flexible, sandboxed access to complex functionality. Instead of exposing 60+ individual MCP tools directly, the server exposes just two top-level tools:

- **`search`** — discover available operations by query, with configurable detail levels (`"brief"`, `"detailed"`, or `"full"` for complete parameter schemas).
- **`execute`** — run JavaScript code that can call any of the 60+ OBS tools via `await call_tool('<tool_name>', { params })`.

### Why Code Mode?

Code mode, [popularized by Cloudflare's MCP servers](https://blog.cloudflare.com/code-mode/), offers several advantages:

1. **Flexibility** — Agents can compose multiple tool calls in a single execution, use control flow (loops, conditionals), and handle complex workflows without round-trip overhead.
2. **Discoverability** — The `search` tool lets agents find the right operation without memorizing tool names or reading external docs.
3. **Sandboxed execution** — Code runs in an isolated context with access only to the tools the server explicitly provides.
4. **Reduced token overhead** — Instead of the LLM reasoning through multiple tool call steps, it can write a single script that the server executes atomically.

This is why the [AI Agent Skill](#ai-agent-skill) included in this package teaches agents the `execute` + JavaScript pattern — it's the primary way to interact with OBS through this server.

## Features

All tools are prefixed with `obs_` and organized into the following groups:

| Group | Tools | Description |
|---|---|---|
| **Connection** | `connect`, `disconnect`, `is_connected`, `send_raw` | Manage the WebSocket connection to OBS |
| **General** | `general_version`, `general_stats`, `general_hotkeys`, `general_trigger_hotkey`, `general_sleep`, `general_broadcast_custom_event` | Retrieve OBS version/stats, trigger hotkeys, broadcast custom events |
| **Scenes** | `scenes_list`, `scenes_group_list`, `scenes_get_current_program`, `scenes_set_current_program`, `scenes_get_current_preview`, `scenes_set_current_preview`, `scenes_create` | List, switch, and create scenes |
| **Scene Items** | `scene_items_list`, `scene_items_group_list`, `scene_items_get_id`, `scene_items_get_enabled`, `scene_items_set_enabled`, `scene_items_get_locked`, `scene_items_set_locked`, `scene_items_set_transform`, `scene_items_get_source`, `scene_items_get_private_settings`, `scene_items_set_private_settings` | Query and control items within scenes, including position/scale/rotation/crop and private settings |
| **Inputs** | `inputs_list`, `inputs_kind_list`, `inputs_special`, `inputs_get_mute`, `inputs_set_mute`, `inputs_toggle_mute`, `inputs_get_volume`, `inputs_get_settings`, `inputs_set_settings`, `inputs_set_name`, `inputs_create`, `inputs_remove` | Manage audio/video inputs, mute, volume, and settings |
| **Inputs - Audio** | `inputs_get_audio_balance`, `inputs_set_audio_balance`, `inputs_get_audio_sync_offset`, `inputs_set_audio_sync_offset`, `inputs_get_audio_monitor_type`, `inputs_set_audio_monitor_type`, `inputs_get_audio_tracks`, `inputs_set_audio_tracks` | Control input audio properties: balance, sync offset, monitor type, and audio tracks |
| **Inputs - Properties** | `inputs_get_properties_list_items`, `inputs_press_properties_button` | Interact with input properties dialog (list items and button presses) |
| **Stream** | `stream_status`, `stream_start`, `stream_stop`, `stream_toggle`, `stream_send_caption` | Control live streaming and send captions |
| **Record** | `record_status`, `record_start`, `record_stop`, `record_toggle`, `record_pause`, `record_resume`, `record_toggle_pause` | Control recording sessions |
| **Outputs** | `outputs_virtual_cam_status/toggle/start/stop`, `outputs_replay_buffer_status/toggle/start/stop/save`, `outputs_toggle/start/stop`, `outputs_list`, `outputs_get_status`, `outputs_get_settings`, `outputs_set_settings` | Manage virtual camera, replay buffer, and arbitrary outputs |
| **Config** | `config_record_directory`, `config_stream_service_settings` | Read recording directory and stream service configuration |
| **UI** | `ui_studio_mode_enabled`, `ui_set_studio_mode`, `ui_open_input_properties/filters/interact`, `ui_monitor_list` | Toggle Studio Mode, open input dialogs, list monitors |
| **Transitions** | `transitions_trigger_studio`, `transitions_kind_list`, `transitions_scene_list`, `transitions_get_current`, `transitions_set_current`, `transitions_set_duration`, `transitions_set_settings`, `transitions_get_cursor`, `transitions_set_tbar` | Manage scene transitions: list kinds, configure current transition, T-Bar control |
| **Filters** | `filters_kind_list`, `filters_list`, `filters_default_settings`, `filters_create`, `filters_remove`, `filters_rename`, `filters_get`, `filters_set_index`, `filters_set_settings`, `filters_set_enabled` | Manage source filters: create, remove, configure, and reorder |
| **Canvases** | `canvases_list`, `video_settings` | List canvases configured in OBS (v5.7.0+) and read base/output dimensions + FPS via the legacy `GetVideoSettings` request that works on every v5+ build |

Code mode is enabled, providing sandbox execution via a search/execute tool pair.

### What Can You Do?

Here's a quick example of what AI agents can do with these tools. The code below is passed to the `execute` tool, which runs it in a sandboxed JavaScript environment:

```javascript
// Passed to the execute tool:
const scenes = await call_tool('obs_scenes_list', {});
await call_tool('obs_scenes_set_current_program', { sceneName: 'Live Scene' });
await call_tool('obs_record_start', {});
```

Agents can orchestrate complex OBS workflows — switching scenes, animating sources, controlling audio, managing recordings and streams, and more.

## AI Agent Skill

This package includes an **obs-mcp** skill for AI agents (Qoder, Claude, etc.) in the `skills/obs-mcp/` directory. The skill teaches agents how to:
- Invoke OBS tools via the `execute` + JavaScript pattern
- Discover available tools using `search`
- Run common workflows (connection checks, source transforms, animations, recording)
- Avoid common pitfalls (server-side vs client-side timing, transform payload shapes)

Agents can install the skill by running `skills get` after adding this package as a dependency. See [pub.dev/packages/skills](https://pub.dev/packages/skills) for details.

**Example agent workflow:** The skill teaches agents to:
1. Verify connection: `await call_tool('obs_is_connected', {})`
2. Discover tools: `search({ query: "scene items", detail_level: "detailed" })`
3. Execute operations via JavaScript in the `execute` tool
4. Handle errors with `try/finally` and restore state

See the [skill documentation](skills/obs-mcp/SKILL.md) for complete workflows and best practices.

## Configuration

Environment variables can be set via the shell or a `.env` file. The server searches for `.env` in the following locations (in order): `.env`, `bin/.env`, or adjacent to the running script.

| Variable | Description | Default |
|---|---|---|
| `OBS_WEBSOCKET_URL` | WebSocket server URL (e.g., `ws://localhost:4455`) | &mdash; |
| `OBS_WEBSOCKET_PASSWORD` | Authentication password (omit for anonymous connections) | &mdash; |
| `OBS_WEBSOCKET_TIMEOUT` | Connection timeout in seconds | `120` |

## Development Setup

This section is for developers who want to modify the obs_mcp source code or add new tools.

### Prerequisites

- Dart SDK >= 3.8.0
- OBS Studio with obs-websocket v5.x (bundled with OBS 28+)

### Running from Source

If you're working on the package locally, you can run the server directly from source instead of using the globally activated version:

```bash
cd packages/obs_mcp
dart pub get
dart run bin/obs_mcp_server.dart
```

### Code Generation

The MCP dispatcher (`lib/src/obs_mcp_server.mcp.dart`) is pre-generated and committed to the repository. You only need to run `build_runner` if you're modifying the `ObsMcpServer` class or adding new tools.

If you modify `lib/src/obs_mcp_server.dart`, regenerate the dispatcher:

```bash
dart run build_runner build
```

This produces `lib/src/obs_mcp_server.mcp.dart`, which wires up all tool handlers.

## Testing with MCP Inspector

The [MCP Inspector](https://github.com/modelcontextprotocol/inspector) (`@modelcontextprotocol/inspector`) is the preferred tool for interactively debugging and testing the server.

1. **Install the inspector globally:**

   ```bash
   npm install -g @modelcontextprotocol/inspector
   ```

2. **Launch the inspector connected to the server:**

   ```bash
   cd packages/obs_mcp
   npx @modelcontextprotocol/inspector dart run bin/obs_mcp_server.dart
   ```

   Or if you've activated the package globally:

   ```bash
   npx @modelcontextprotocol/inspector obs_mcp
   ```

3. **Browse and invoke tools** in the web UI that opens automatically. You can inspect request/response payloads for each tool call.

4. **Provide connection credentials** by placing a `.env` file in the `packages/obs_mcp/` or `packages/obs_mcp/bin/` directory with your `OBS_WEBSOCKET_URL` and `OBS_WEBSOCKET_PASSWORD` values.

## Contributing

Contributions are welcome! This package is part of the [obs_websocket workspace](https://github.com/cdavis-code/obs_websocket_workspace).

**Before submitting a PR:**
1. Make changes to `lib/src/obs_mcp_server.dart` (add `@Tool` annotated methods)
2. Regenerate the dispatcher: `dart run build_runner build`
3. Run tests: `dart test`
4. Format code: `dart format .`

See the [workspace README](../../README.md) for development setup.

## License

MIT — see the [LICENSE](../../LICENSE) file for details.
