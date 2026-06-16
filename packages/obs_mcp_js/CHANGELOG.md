# Changelog

## [5.7.5] - 2026-05-26

### Changed
- **Registry-driven architecture**: Replaced hardcoded tool specs and switch/case dispatch with a centralized registry-driven `ToolDef` pattern
- Extracted tool definitions into dedicated `tool_registry.dart` for improved maintainability and extensibility
- Simplified server architecture by removing redundant handler methods
- Updated `bin/obs-mcp-server.js` with a cleaner Node.js wrapper structure
- Updated `build.sh` to support the new build pipeline
- Cleaned up unused files (removed `stderr.log`)

## 5.7.4

### Added
- Added `PUBLISHING.md` with npm release documentation

### Changed
- Bumped `ws` dependency from 8.20.0 to 8.20.1 (resolves uninitialized memory disclosure)
- Fixed `bin` path consistency in `package.json` (`./bin/` → `bin/`)

## 5.7.2

### Added
- Added `repository` and `homepage` fields to `package.json` for npm provenance

## 5.7.1+1

### Added
- Initial release of `@unngh/obs-mcp` — JavaScript-compiled MCP server for OBS Studio
- Full MCP server functionality with 60+ OBS control tools via `search` and `execute` meta-tools
- Code Mode implementation (search + execute pattern) for flexible AI agent interaction
- Compiled from Dart using dart2js for Node.js execution — no Dart runtime required
- WebSocket polyfill via `ws` package for Node.js 18–21 (Node 22+ uses native WebSocket)
- Newline-delimited JSON (ndjson) transport for MCP Inspector and client compatibility
- `OBS_MCP_DEBUG=1` environment variable for conditional stderr debug logging
- MCP Host configuration support for Claude Desktop, VS Code, Cursor, and generic clients

### Tool Categories
- **Connection**: connect, disconnect, is_connected, send_raw
- **General**: version, stats, hotkeys, trigger_hotkey, trigger_hotkey_by_key, sleep, broadcast_custom_event, call_vendor_request
- **Scenes**: list, group_list, get/set current program/preview, create
- **Scene Items**: list, group_list, get_id, enabled, locked, transform, source, private_settings, create, duplicate, remove
- **Inputs**: list, kind_list, special, default_settings, mute, volume, settings, name, create, remove
- **Inputs — Audio**: balance, sync_offset, monitor_type, audio_tracks
- **Inputs — Properties**: properties_list_items, press_properties_button, deinterlace mode/field_order
- **Sources**: get_active, screenshot, save_screenshot, private_settings
- **Media Inputs**: get_status, set_cursor, offset_cursor, trigger_action
- **Stream**: status, start, stop, toggle, send_caption
- **Record**: status, start, stop, toggle, pause, resume, toggle_pause
- **Outputs**: virtual_cam, replay_buffer, list, toggle/start/stop, get_status, get/set_settings
- **Config**: record_directory, stream_service_settings
- **UI**: studio_mode, open input properties/filters/interact, monitor_list
- **Transitions**: trigger_studio, kind_list, scene_list, get/set current, duration, settings, cursor, t_bar
- **Filters**: kind_list, list, default_settings, create, remove, rename, get, set_index, set_settings, set_enabled
- **Canvases**: list (v5.7.0+)

### Architecture
- Node.js entry point with keepalive, signal handling, and uncaught error handling
- dart2js compiled runtime loaded as ES module
- Background OBS WebSocket bootstrap (non-blocking MCP channel setup)
- Content-Length framing removed in favor of ndjson for dart_mcp compatibility
