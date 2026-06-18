# Changelog

## Unreleased

## 5.7.1+4

* **Homebrew installation**: Added pre-built binary distribution via Homebrew (`brew tap cdavis-code/obs-websocket && brew install obs-mcp`), no Dart SDK required
* **README**: Restructured Quick Start with dedicated Homebrew option, expanded Table of Contents, added Contributing section
* **Dependency**: Bumped `obs_websocket` to `5.7.0+4`

## 5.7.1+3

* **Pana score 160/160**: Upgraded `easy_api_generator` to `^1.2.2` to fix lint warnings and formatting issues in the generated MCP dispatcher. The generated `obs_mcp_server.mcp.dart` now passes `dart analyze` and `dart format` with zero warnings.
* **Skills**: Updated `obs-get-state/SKILL.md` to call `obs_video_settings` first and only fall back to `obs_canvases_list` when the v5.7.0+ canvas list shape is specifically required.
* **Video settings**: New `video_settings` tool wraps the legacy `GetVideoSettings` request (available since OBS WebSocket v5.0). Returns `baseWidth`, `baseHeight`, `outputWidth`, `outputHeight`, `fpsNumerator`, and `fpsDenominator`. Use this on builds older than v5.7.0 where `canvases_list` errors out.

## 5.7.1+2

* **Connection helpers**: New first-class tools so agents no longer have to script connection handling via `execute`
  * `connection_status` — reports current connection state (`connected`, `connecting`, `disconnected`, `reconnecting`, `failed`)
  * `connection_ping` — lightweight `GetVersion` heartbeat
* **Event helpers**: New tools that wrap the underlying obs_websocket event stream
  * `events_subscribe` — reidentify with the requested event subscription mask or named categories
  * `wait_for_event` — polling-free wait for a specific event with optional timeout and predicate
* **Server-side animation**: `scene_items_animate_transform` interpolates a scene item transform over time on the server
  * Built-in easings: `linear`, `easeIn`, `easeOut`, `easeInOut`, `easeOutBounce`
  * Configurable `durationMs` and `frameRate`; optional restore-on-complete
  * Accepts target `positionX/Y`, `scaleX/Y`, `rotation`, `cropLeft/Top/Right/Bottom`
* **Client sleep**: `client_sleep` provides a server-side, non-OBS-blocking pause (1–25000 ms) for use between tool calls
* **Full transform parameters**: `scene_items_set_transform` now accepts `alignment`, `boundsAlignment`, `boundsType`, `boundsWidth`, `boundsHeight`
* **Auto-reconnect bootstrap**: MCP server constructs `ObsWebSocket` with `autoReconnect: true` so transient disconnects recover transparently
* **Refactor**: Extracted easing / lerp / transform interpolation / event-subscription parsing into `lib/src/animation_helpers.dart` for testability
* **Tests**: Added 14 unit tests covering animation helpers and event-subscription parsing
* **Skills**: Updated SKILL.md tool catalog, workflows, and gotchas to document the new tools
* **Dependency**: Requires `obs_websocket: ^5.7.0+3` for the new typed transform model and connection helpers

## 5.7.1+1

* **Documentation**: Improved README structure and clarity
  * Added Code Mode section with link to Cloudflare's code mode blog
  * Clarified that sample code in "What Can You Do?" is executed via the `execute` tool
  * Moved "What Can You Do?" section after Features table for better context
  * Removed manual server run step from Quick Start (server is auto-launched by MCP host)
  * Moved MCP Host Configuration section up to follow Quick Start
  * Relocated development instructions to "Development Setup" section

## 5.7.1

* **Fix**: Include generated `obs_mcp_server.mcp.dart` file in published package, which was previously excluded by `.pubignore`, causing `dart pub global activate obs_mcp` to fail with "No such file or directory" build error.

## 5.7.0

* Added comprehensive support for OBS WebSocket v5.7.0 features
* **Canvases**: New `canvases_list` tool to list all configured canvases
* **Input Audio Properties**: Full control over audio balance, sync offset, monitor type, and audio tracks
  * `inputs_get_audio_balance`, `inputs_set_audio_balance`
  * `inputs_get_audio_sync_offset`, `inputs_set_audio_sync_offset`
  * `inputs_get_audio_monitor_type`, `inputs_set_audio_monitor_type`
  * `inputs_get_audio_tracks`, `inputs_set_audio_tracks`
* **Input Properties Dialog**: Access to list property items and button presses
  * `inputs_get_properties_list_property_items`
  * `inputs_press_properties_button`
* **Scene Items Extended**: Access to source names and private settings
  * `scene_items_get_source`
  * `scene_items_get_private_settings`, `scene_items_set_private_settings`
* **Transitions**: Complete transition management (9 tools)
  * `transitions_get_kind_list`, `transitions_get_list`, `transitions_get_current`
  * `transitions_set_current`, `transitions_set_duration`, `transitions_set_settings`
  * `transitions_get_cursor`, `transitions_trigger_studio`, `transitions_set_tbar`
* **Filters**: Full filter lifecycle management (10 tools)
  * `filters_get_kind_list`, `filters_get_list`, `filters_get_default_settings`
  * `filters_create`, `filters_remove`, `filters_rename`
  * `filters_get`, `filters_set_index`, `filters_set_settings`, `filters_set_name`
* **Outputs Extended**: List all outputs, get/set output status and settings
  * `outputs_get_list`, `outputs_get_status`, `outputs_set_settings`
* Improved error handling with bootstrap error tracking
* Extracted monitor type parsing to reusable helper method
* Standardized @Tool annotation formatting for better readability
* Added clarifying comments for scene_items methods returning Map directly

## 5.6.0

* Initial release as standalone package
* Extracted MCP server from obs_websocket package
* Core OBS WebSocket v5.6.0 support
* Basic tools for inputs, scenes, streaming, recording, and outputs
