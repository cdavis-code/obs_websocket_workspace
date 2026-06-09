# Changelog

## 5.7.0+4

* Version bump

## 5.7.0+3

* **New typed transform model**
  * Added `SceneItemTransform` model with named fields, `fromJson`/`toJson`, `copyWith`, and `merge`
  * Added `ObsAlignment` enum (top-left, top-center, top-right, center-left, center, center-right, bottom-left, bottom-center, bottom-right) with OBS bit-flag values
  * Added `ObsBoundsType` enum (`OBS_BOUNDS_NONE`, `OBS_BOUNDS_STRETCH`, `OBS_BOUNDS_SCALE_INNER`, `OBS_BOUNDS_SCALE_OUTER`, `OBS_BOUNDS_SCALE_TO_WIDTH`, `OBS_BOUNDS_SCALE_TO_HEIGHT`, `OBS_BOUNDS_MAX_ONLY`)
  * `setSceneItemTransform` now validates keys and rejects unknown fields
* **Connection resilience**
  * Added `autoReconnect` constructor flag with exponential backoff (200 ms → 5 s, max 5 attempts)
  * Added `Stream<ObsConnectionState> onConnectionStateChanged` for reactive connection monitoring
  * Added lightweight `ping()` helper using `GetVersion` for heartbeat checks
* **Event awaitable helpers**
  * Added `waitForEvent({eventType, predicate?, timeout?})` for polling-free event waiting
  * Added `waitForTypedEvent<T>({eventType, predicate?, timeout?})` for typed events
* Exported new symbols from the main library entry point

## 5.7.0+1

* Removed `envied` dependency for compile-time `.env` loading
* Implemented runtime `.env` file parsing from current working directory
* Added `ObsUtil.parseDotenvFile()` utility method for reusable dotenv parsing
* Improved cross-platform compatibility with safe `.env` file loading (try-catch for web/mobile)
* Updated documentation to clarify runtime `.env` loading behavior

## 5.7.0

* Canvases (New in OBS WebSocket v5.7.0)
  * GetCanvasList request
* Inputs - Audio Properties
  * GetInputAudioBalance request
  * SetInputAudioBalance request
  * GetInputAudioSyncOffset request
  * SetInputAudioSyncOffset request
  * GetInputAudioMonitorType request
  * SetInputAudioMonitorType request
  * GetInputAudioTracks request
  * SetInputAudioTracks request
* Inputs - Properties Dialog
  * GetInputPropertiesListPropertyItems request
  * PressInputPropertiesButton request
* Scene Items
  * GetSceneItemSource request *(Added in v5.4.0)*
  * GetSceneItemPrivateSettings request *(Added in v5.6.0)*
  * SetSceneItemPrivateSettings request *(Added in v5.6.0)*
* Transitions Requests
  * GetTransitionKindList request
  * GetSceneTransitionList request
  * GetCurrentSceneTransition request
  * SetCurrentSceneTransition request
  * SetCurrentSceneTransitionDuration request
  * SetCurrentSceneTransitionSettings request
  * GetCurrentSceneTransitionCursor request
  * TriggerStudioModeTransition request
  * SetTBarPosition request
* Filters Requests
  * GetSourceFilterKindList request *(Added in v5.4.0)*
  * GetSourceFilterList request
  * GetSourceFilterDefaultSettings request
  * CreateSourceFilter request
  * RemoveSourceFilter request
  * SetSourceFilterName request
  * GetSourceFilter request
  * SetSourceFilterIndex request
  * SetSourceFilterSettings request
  * SetSourceFilterEnabled request
* Outputs Requests
  * GetOutputList request
  * GetOutputStatus request
  * ToggleOutput request
  * StartOutput request
  * StopOutput request
  * GetOutputSettings request
  * SetOutputSettings request
* Record Requests
  * GetRecordStatus request
  * ToggleRecord request
  * StartRecord request
  * StopRecord request
  * ToggleRecordPause request
  * PauseRecord request
  * ResumeRecord request
* Events
  * SourceFilterSettingsChanged event
  * CanvasCreated event
  * CanvasRemoved event
  * CanvasNameChanged event  
* Updated repository URL
* Added LICENSE file to package
* Improved documentation and examples

## 5.2.3+2

* Events
  * Inputs
    - InputActiveStateChanged
    - InputAudioBalanceChanged
    - InputAudioMonitorTypeChanged
    - InputAudioSyncOffsetChanged
    - InputAudioTracksChanged
    - InputCreated
    - InputMuteStateChanged
    - InputNameChanged
    - InputRemoved
    - InputSettingsChanged
    - InputShowStateChanged
    - InputVolumeChanged
    - InputVolumeMeters

## 5.2.3+1

* dependency bump
* Media Inputs
  - Added GetMediaInputStatus request
  - Added inputUuid parameter to SetMediaInputCursor and OffsetMediaInputCursor requests
  - Added TriggerMediaInputAction request
## 5.2.3

* dependency bump
* Scenes Events
  * SceneCreated
  * SceneRemoved
  * SceneNameChanged
  * CurrentProgramSceneChanged
  * CurrentPreviewSceneChanged
* Inputs
  * GetSpecialInputs
  * CreateInput
  * GetInputDefaultSettings
  * GetInputSettings
  * SetInputSettings
* Tests
  * Inputs
    * GetInputKindList
    * GetInputList
    * GetSpecialInputs
    * CreateInput
    * RemoveInput
    * SetInputName
    * GetInputDefaultSettings
    * GetInputSettings
    * SetInputSettings
    * GetInputMute
    * SetInputMute
    * ToggleInputMute
* cli
 * Inputs
  * GetSpecialInputs
  * CreateInput
  * GetInputDefaultSettings
  * GetInputSettings
  * SetInputSettings

## 5.1.0+9

* dependency bump

## 5.1.0+8

* Inputs Requests
  * GetInputList
  * GetInputKindList
* README Correction
* Issue [#28](https:&#x2F;&#x2F;github.com&#x2F;cdavis-code&#x2F;obs_websocket_workspace&#x2F;issues&#x2F;28)
* Inputs features are now available in the CLI

## 5.1.0+7

* updated README
* dependency bump

## 5.1.0+6

* Media Inputs
  * OffsetMediaInputCursor
* dependency bump

## 5.1.0+5

* more events
* dependency bump
* less code duplication

## 5.1.0+4

* dart fix
* dependency bump

## 5.1.0+3

* readme update
* dependency bump

## 5.1.0+2

* Scenes
  * GetSceneSceneTransitionOverride
  * SetSceneSceneTransitionOverride
* CLI Commands
  * scenes
    * get-current-program-scene
    * get-group-list
    * get-scenes-list

## 5.1.0+1

* README

## 5.1.0

* stream
  * SendStreamCaption
* config
  * GetRecordDirectory
* ui event
  * ScreenshotSaved
* commands
  * stream
    * SendStreamCaption
  * config
    * GetRecordDirectory

## 5.0.0+15

* fix publish_tools dependency

## 5.0.0+14

* #27 - onDone functionality returned

## 5.0.0+13

* scene items
  * GetSceneItemLocked
  * SetSceneItemLocked
* cli
  * scene items
    * GetSceneItemList
    * GetSceneItemLocked
    * SetSceneItemLocked
* tests
  * scene items
    * GetSceneItemList
    * GetSceneItemLocked
    * SetSceneItemLocked

## 5.0.0+12

* dependency bumps
* ui
  * GetMonitorList
* cli
  * ui
    * GetStudioModeEnabled
    * SetStudioModeEnabled
    * GetMonitorList
* tests
  * ui
    * GetStudioModeEnabled
    * SetStudioModeEnabled
    * GetMonitorList

## 5.0.0+11

* events supported
  * Config - CurrentProfileChanging
  * Config - CurrentProfileChanged
  * Config - ProfileListChanged
* PR #26

## 5.0.0+10

* commands
  * Outputs - ToggleReplayBuffer
  * Outputs - StartReplayBuffer
  * Outputs - StopReplayBuffer
  * Outputs - SaveReplayBuffer
* unit tests
  * ToggleReplayBuffer

## 5.0.0+9

* dependency bump for publish_tools again

## 5.0.0+8

* updated dependency for publish_tools

## 5.0.0+7

* using publish_tools from pub.dev

## 5.0.0+6

* additional events supported
  * Config - CurrentSceneCollectionChanging
  * Config - CurrentSceneCollectionChanged
  * Config - SceneCollectionListChanged

## 5.0.0+5

* improved build tools (using publish_tools package)
* issue #25 implemented
* cli commands
  * general - BroadcastCustomEventCommand
  * general - CallVendorRequestCommand
  * general - BrowserEventCommand (helper method)
  * general - GetHotkeyListCommand
  * general - TriggerHotkeyByNameCommand
  * general - TriggerHotkeyByKeySequenceCommand
  * general - SleepCommand
* unit tests
  * GetVersion
  * CallVendorRequest
  * obsBrowserEvent
  * GetHotkeyList

## 5.0.0+5

* improved build tools (using publish_tools package)
* issue #25 implemented
* cli commands
  * general - BroadcastCustomEventCommand
  * general - CallVendorRequestCommand
  * general - BrowserEventCommand (helper method)
  * general - GetHotkeyListCommand
  * general - TriggerHotkeyByNameCommand
  * general - TriggerHotkeyByKeySequenceCommand
  * general - SleepCommand
* unit tests
  * GetVersion
  * CallVendorRequest
  * obsBrowserEvent
  * GetHotkeyList

## 5.0.0+5

* improved build tools (using publish_tools package)
* issue #25 implemented
* cli commands
  * general - BroadcastCustomEventCommand
  * general - CallVendorRequestCommand
  * general - BrowserEventCommand (helper method)
  * general - GetHotkeyListCommand
  * general - TriggerHotkeyByNameCommand
  * general - TriggerHotkeyByKeySequenceCommand
  * general - SleepCommand
* unit tests
  * GetVersion
  * CallVendorRequest
  * obsBrowserEvent
  * GetHotkeyList

## 5.0.0+4

* build tool changes
* fix for issue #23

## 5.0.0+3

* SetPersistentData, GetSceneCollectionList, SetCurrentSceneCollection, CreateSceneCollection, GetProfileList, GetProfileParameter, SetProfileParameter now supported as high level commands
* more tests
* improved build tools

## 5.0.0+2

* resolving some release issues

## 5.0.0+1

* support for GetSceneItemIndex and SetSceneItemIndex
* improved build tools

## 5.0.0

* production release
* obs cli can run shell commands with `listen`
* improved cli README

## 5.0.0-dev.6

* ui module now supports: OpenInputPropertiesDialog, OpenInputFiltersDialog, OpenInputInteractDialog, OpenVideoMixProjector, OpenSourceProjector
* changed LICENSE

## 5.0.0-dev.5

* obs at the command prompt
* updated README
* `obs version` to confirm installed package from cli

## 5.0.0-dev.4

 - SceneListResponse fix null currentPreviewSceneName 
 - batch operations now supported
 - add batch.dart example
 - fix Flutter web `Enum` error Issue #16
 
## 5.0.0-dev.3

- typed responses, additional helper methods
  
## 5.0.0-dev.2

- bug fixes (mostly events), additional helper methods
  
## 5.0.0-dev.1

- new release for obs websocket v5.0.0 protocol

## 2.4.3

- README fix and grind improvement

## 2.4.2

- added fallbackEvent back in

## 2.4.1

- issue #11

## 2.4.0

- restructure of the cli functionality

## 2.3.1

- fix for &quot;web&quot; platform

## 2.3.0

- support for &quot;web&quot; platform

## 2.2.12

- updated package layout

## 2.2.11

- more fix for GetSourceActive and GetSourceActive

## 2.2.10

- fix for GetSourceActive and GetSourceActive

## 2.2.9

- readme typo

## 2.2.8

- added GetMediaSourcesList, GetSourcesList, GetSourceActive and GetSourceActive

## 2.2.7

- added SaveStreamSettings, TakeSourceScreenshot, SetCurrentProfile, GetCurrentProfile and RefreshBrowserSource

## 2.2.6

- disable studio mode

## 2.2.5

- adjustments to the publish workflow

## 2.2.4

- code tweaks from Sabuto merged

## 2.2.3

- improved API docs

## 2.2.2

- correction of some class names in the readme

## 2.2.1

- restructured the event model

## 2.2.0

- file name changed to match publish spec

## 2.1.2

- runtime js compatibility

## 2.1.1

- tweak readme

## 2.0.8

- added grind for a simplified workflow

## 2.0.7

- more readme improvements

## 2.0.6

- improved readme and example

## 2.0.5

- trying to remove the dart:io dependency, for greater platform support

## 2.0.4

- using pedantic for static analysis, upgrade to some dependencies

## 2.0.3

- universal_io package replaces dart:io to maybe support web

## 2.0.2

- updated API docs

## 2.0.1

- static analysis improvements

## 2.0.0

- null safety, method based commands and event handling

## 1.0.0

- included example matches the README and addition of bin/ws-obs.app command lne app for OSX

## 0.0.2

- initial simplified support for responses

## 0.0.1

- initial commit, no support for responses to commands