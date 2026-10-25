# OBS WebSocket Dart Workspace

A comprehensive Dart monorepo providing SDK and CLI implementations for controlling OBS Studio via the obs-websocket protocol.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Dart](https://github.com/cdavis-code/obs_websocket_workspace/workflows/Dart/badge.svg)](https://github.com/cdavis-code/obs_websocket_workspace/actions)
[![GitHub last commit](https://shields.io/github/last-commit/cdavis-code/obs_websocket_workspace)](https://shields.io/github/last-commit/cdavis-code/obs_websocket_workspace)

---

## Quick Start

```sh
# Clone the repository
git clone https://github.com/cdavis-code/obs_websocket_workspace.git
cd obs_websocket_workspace

# Install Melos (workspace manager)
dart pub global activate melos

# Bootstrap workspace dependencies
melos bootstrap

# Run all tests
melos run test
```

---

## Packages

This workspace contains two packages, each serving a distinct purpose:

| Package | Version | Description |
|---------|---------|-------------|
| [**obs_websocket**](packages/obs_websocket/) | 5.7.0+7 | Core Dart SDK for OBS WebSocket protocol v5.x |
| [**obs_cli**](packages/obs_cli/) | 5.2.3+2 | Command-line interface for controlling OBS from terminal |

---

## obs_websocket — Dart SDK

A production-ready Dart client library that abstracts the OBS WebSocket JSON-RPC protocol into intuitive, typed API methods.

### Features

- **Full Protocol Support** — Comprehensive coverage of OBS WebSocket v5.x protocol (Requests + Events)
- **Typed Responses** — All API calls return strongly-typed Dart objects with `json_serializable`
- **Event System** — Type-safe event handlers using generic `addHandler<T>()` pattern
- **Category-Based API** — Organized by domain: `obsWebSocket.inputs`, `obsWebSocket.scenes`, `obsWebSocket.transitions`, etc.
- **Low-Level Fallback** — Raw `send()` method available for unimplemented protocol methods
- **Cross-Platform** — Uses `universal_io` for Flutter Web, desktop, and server compatibility

### Usage Example

```dart
import 'package:obs_websocket/obs_websocket.dart';

// Connect to OBS
final obs = await ObsWebSocket.connect(
  'ws://localhost:4455',
  password: 'your-password',
);

// Get current scene
final currentScene = await obs.scenes.getCurrentProgramScene();
print('Current scene: $currentScene');

// Start streaming
final status = await obs.stream.getStreamStatus();
if (!status.outputActive) {
  await obs.stream.start();
  print('Stream started!');
}

// Listen to events
await obs.listen(EventSubscription.all);
obs.addHandler<SceneItemEnableStateChanged>((event) {
  print('Scene item ${event.sceneItemId} enabled: ${event.sceneItemEnabled}');
});

// Don't forget to close
await obs.close();
```

### Supported Categories

| Category | Requests | Events |
|----------|----------|--------|
| **General** | GetVersion, GetStats, BroadcastCustomEvent, CallVendorRequest, GetHotkeyList, TriggerHotkeyByName, TriggerHotkeyByKeySequence, Sleep | ExitStarted, VendorEvent |
| **Config** | Get/SetPersistentData, SceneCollection management, Profile management, Get/SetVideoSettings, Get/SetStreamServiceSettings, Get/SetRecordDirectory | SceneCollection changing/changed/list, Profile changing/changed/list |
| **Canvases** | GetCanvasList | CanvasCreated, CanvasRemoved, CanvasNameChanged |
| **Scenes** | GetSceneList, GetGroupList, GetCurrent/SetCurrentProgramScene, GetCurrent/SetCurrentPreviewScene, Create/RemoveScene, SetSceneName, Get/SetSceneSceneTransitionOverride | SceneCreated, SceneRemoved, SceneNameChanged, CurrentProgramSceneChanged, CurrentPreviewSceneChanged, SceneListChanged |
| **Inputs** | GetInputList, GetInputKindList, GetSpecialInputs, Create/RemoveInput, SetInputName, Get/SetInputSettings, GetInputDefaultSettings, Get/SetInputMute, ToggleInputMute, Get/SetInputVolume, Get/SetInputDeinterlaceMode, Get/SetInputAudioBalance, Get/SetInputAudioSyncOffset, Get/SetInputAudioMonitorType, Get/SetInputAudioTracks, GetInputPropertiesListPropertyItems, PressInputPropertiesButton | InputCreated, InputRemoved, InputNameChanged, InputSettingsChanged, InputActiveStateChanged, InputShowStateChanged, InputMuteStateChanged, InputVolumeChanged, InputAudioBalanceChanged, InputAudioSyncOffsetChanged, InputAudioTracksChanged, InputAudioMonitorTypeChanged, InputVolumeMeters |
| **Transitions** | GetTransitionKindList, GetSceneTransitionList, GetCurrentSceneTransition, SetCurrentSceneTransition, SetCurrentSceneTransitionDuration, SetCurrentSceneTransitionSettings, GetCurrentSceneTransitionCursor, TriggerStudioModeTransition, SetTBarPosition | CurrentSceneTransitionChanged, CurrentSceneTransitionDurationChanged, SceneTransitionStarted, SceneTransitionEnded, SceneTransitionVideoEnded |
| **Filters** | GetSourceFilterKindList, GetSourceFilterList, GetSourceFilterDefaultSettings, CreateSourceFilter, RemoveSourceFilter, SetSourceFilterName, GetSourceFilter, SetSourceFilterIndex, SetSourceFilterSettings, SetSourceFilterEnabled | SourceFilterListReindexed, SourceFilterCreated, SourceFilterRemoved, SourceFilterNameChanged, SourceFilterEnableStateChanged, SourceFilterSettingsChanged |
| **Scene Items** | GetSceneItemList, GetGroupSceneItemList, GetSceneItemId, GetSceneItemSource, CreateSceneItem, RemoveSceneItem, DuplicateSceneItem, Get/SetSceneItemTransform, Get/SetSceneItemEnabled, Get/SetSceneItemLocked, Get/SetSceneItemIndex, Get/SetSceneItemBlendMode, Get/SetSceneItemPrivateSettings | SceneItemCreated, SceneItemRemoved, SceneItemListReindexed, SceneItemEnableStateChanged, SceneItemLockStateChanged, SceneItemSelected, SceneItemTransformChanged |
| **Outputs** | GetVirtualCamStatus, ToggleVirtualCam, Start/StopVirtualCam, GetReplayBufferStatus, ToggleReplayBuffer, Start/StopReplayBuffer, SaveReplayBuffer, GetOutputList, GetOutputStatus, ToggleOutput, Start/StopOutput, GetOutputSettings, SetOutputSettings | StreamStateChanged, RecordStateChanged, RecordFileChanged, ReplayBufferStateChanged, VirtualcamStateChanged, ReplayBufferSaved |
| **Stream** | GetStreamStatus, ToggleStream, StartStream, StopStream, SendStreamCaption | *(see Outputs)* |
| **Record** | GetRecordStatus, ToggleRecord, StartRecord, StopRecord, ToggleRecordPause, PauseRecord, ResumeRecord, SplitRecordFile, CreateRecordChapter | *(see Outputs)* |
| **Media Inputs** | GetMediaInputStatus, SetMediaInputCursor, OffsetMediaInputCursor, TriggerMediaInputAction | MediaInputPlaybackStarted, MediaInputPlaybackEnded, MediaInputActionTriggered |
| **Sources** | GetSourceActive, GetSourceScreenshot, SaveSourceScreenshot, Get/SetSourcePrivateSettings | — |
| **Ui** | Get/SetStudioModeEnabled, OpenInputPropertiesDialog, OpenInputFiltersDialog, OpenInputInteractDialog, GetMonitorList, OpenVideoMixProjector, OpenSourceProjector | StudioModeStateChanged, ScreenshotSaved |

For complete API documentation, see [packages/obs_websocket/README.md](packages/obs_websocket/README.md).

---

## obs_cli — Command-Line Interface

Control OBS Studio directly from your terminal with intuitive subcommands.

### Installation

```sh
# Via dart pub
dart pub global activate obs_websocket

# Via Homebrew (macOS)
brew tap cdavis-code/obs_websocket_workspace
brew install obs
```

### Quick Start

```sh
# Step 1: Configure credentials in packages/obs_cli/bin/.env
# OBS_WEBSOCKET_URL=ws://localhost:4455
# OBS_WEBSOCKET_PASSWORD=your_password

# Step 2: Generate authentication file
obs authorize

# Step 3: Test connection
obs stream get-stream-status
```

### Available Commands

| Command | Description |
|---------|-------------|
| `obs authorize` | Generate authentication file from `.env` credentials |
| `obs config` | Config requests (record directory, video settings, stream service) |
| `obs general` | General commands (get-stats, get-version) |
| `obs inputs` | Input management (list, mute, rename, remove) |
| `obs listen` | Stream OBS events to stdout with optional shell command triggers |
| `obs scene-items` | Scene item operations (list, lock/unlock) |
| `obs scenes` | Scene operations (get current, list, groups) |
| `obs send` | Low-level raw WebSocket request sender |
| `obs sources` | Source operations (active state, screenshots) |
| `obs stream` | Stream control (start, stop, toggle, captions) |
| `obs ui` | UI operations (studio mode, monitor list) |
| `obs version` | Display CLI version |

### Advanced Usage

```sh
# Listen to scene change events
obs listen --event-subscriptions scenes

# Parse events with jq
obs listen --event-subscriptions scenes | jq -r '.eventType + "\t" + .eventData.sceneName'

# Trigger shell command on events
obs listen --event-subscriptions scenes --command 'echo "Scene changed!" | mail -s "OBS Alert" user@example.com'
```

For complete CLI documentation, see [packages/obs_cli/README.md](packages/obs_cli/README.md).

---

## Workspace Development

### Prerequisites

- **Dart SDK** ≥ 3.8.0
- **Melos** ≥ 7.5.1 (workspace manager)
- **OBS Studio** with obs-websocket plugin enabled

### Common Commands

```sh
# Install dependencies across all packages
melos bootstrap

# Run tests
melos run test

# Run code analysis
melos run analyze

# Format code
melos run format

# Run all linting (analyze + format check)
melos run lint:all

# Generate JSON serialization code
melos run build

# Generate API documentation
melos run dartdoc
```

### Project Structure

```
obs_websocket_workspace/
├── packages/
│   ├── obs_websocket/          # Core SDK library
│   │   ├── lib/
│   │   │   ├── src/
│   │   │   │   ├── request/    # Category-based request methods
│   │   │   │   ├── model/      # Event and response models
│   │   │   │   └── ...
│   │   │   ├── obs_websocket.dart
│   │   │   ├── event.dart
│   │   │   └── request.dart
│   │   ├── test/
│   │   └── README.md
│   ├── obs_cli/                # Command-line interface
│   │   ├── bin/
│   │   ├── lib/src/
│   │   ├── test/
│   │   └── README.md
├── pubspec.yaml                # Workspace root
├── melos_obs_websocket_workspace.iml
└── .github/workflows/dart.yml  # CI/CD pipeline
```

### Architecture Patterns

- **Category-Based Organization** — Requests grouped by domain (inputs, scenes, transitions, etc.)
- **One File, One Class** — Each model/event in its own file for maintainability
- **FromJsonSingleton Pattern** — Centralized event factory registration for runtime dispatch
- **Dual Method Naming** — Short alias + full RPC name (e.g., `obs.inputs.list()` + `obs.inputs.getInputList()`)
- **JSON Serializable** — All models use `@JsonSerializable()` with `build_runner` code generation

---

## Requirements

- **OBS Studio** v27.x or above with obs-websocket plugin enabled
- Network access to OBS instance (local or remote)
- WebSocket URL and password (configurable in OBS: Tools → obs-websocket Settings)

---

## Contributing

Any help from the open-source community is always welcome!

- **Found an issue?** — Please file a bug report with details
- **Need a feature?** — Open a feature request with use cases
- **Fix a bug?** — Submit a pull request
- **Implement a feature?** — We love new contributors!
- **Improve tests?** — Additional test coverage is always appreciated
- **Using this project?** — Promote it with an article or post

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests: `melos run test`
5. Run analysis: `melos run analyze`
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

---

## CI/CD

This project uses GitHub Actions for continuous integration:

- **Pana Analysis** — Package quality scoring for pub.dev
- **Code Formatting** — Verify consistent code style
- **Static Analysis** — Catch errors with `dart analyze --fatal-infos`
- **Test Suite** — Run all unit tests across packages

See [.github/workflows/dart.yml](.github/workflows/dart.yml) for details.

---

## License

[MIT License](LICENSE)

---

## Contributors

- [faithoflifedev](https://github.com/faithoflifedev)

---

## Interesting Projects

- [Using Flutter as a source in OBS](https://www.aloisdeniel.com/blog/using-flutter-as-a-source-in-obs) — Blog post by Aloïs Deniel showing how to use Flutter applications as custom sources in OBS for animated scenes on Twitch live streams.

---

## References

- [OBS WebSocket Protocol Documentation](https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md)
- [OBS Studio](https://obsproject.com/)
- [obs-websocket Plugin](https://github.com/obsproject/obs-websocket)
- [Dart Language](https://dart.dev/)
- [Melos Workspace Manager](https://melos.invertase.dev/)
