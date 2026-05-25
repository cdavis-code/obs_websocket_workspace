
# Easy OBS WebSocket CLI

A command line interface for controlling OBS with cli commands
- [Easy OBS WebSocket CLI](#easy-obs-websocket-cli)
  - [Installation](#installation)
  - [Quick start](#quick-start)
  - [Available Commands](#available-commands)
    - [authorize](#authorize)
    - [config](#config)
      - [config get-record-directory](#config-get-record-directory)
      - [config get-stream-service-settings](#config-get-stream-service-settings)
      - [config get-video-settings](#config-get-video-settings)
      - [config set-stream-service-settings](#config-set-stream-service-settings)
      - [config set-video-settings](#config-set-video-settings)
    - [filters](#filters)
      - [filters get-source-filter-kind-list](#filters-get-source-filter-kind-list)
      - [filters get-source-filter-list](#filters-get-source-filter-list)
      - [filters get-source-filter-default-settings](#filters-get-source-filter-default-settings)
      - [filters create-source-filter](#filters-create-source-filter)
      - [filters get-source-filter](#filters-get-source-filter)
      - [filters set-source-filter-settings](#filters-set-source-filter-settings)
      - [filters remove-source-filter](#filters-remove-source-filter)
      - [filters set-source-filter-name](#filters-set-source-filter-name)
      - [filters set-source-filter-index](#filters-set-source-filter-index)
      - [filters set-source-filter-enabled](#filters-set-source-filter-enabled)
    - [general](#general)
      - [general get-stats](#general-get-stats)
      - [general get-version](#general-get-version)
    - [inputs](#inputs)
      - [inputs get-input-kind-list](#inputs-get-input-kind-list)
      - [inputs get-input-list](#inputs-get-input-list)
      - [inputs get-input-mute](#inputs-get-input-mute)
      - [inputs get-input-volume](#inputs-get-input-volume)
      - [inputs set-input-volume](#inputs-set-input-volume)
      - [inputs get-input-deinterlace-mode](#inputs-get-input-deinterlace-mode)
      - [inputs set-input-deinterlace-mode](#inputs-set-input-deinterlace-mode)
      - [inputs get-input-deinterlace-field-order](#inputs-get-input-deinterlace-field-order)
      - [inputs set-input-deinterlace-field-order](#inputs-set-input-deinterlace-field-order)
      - [inputs get-input-audio-balance](#inputs-get-input-audio-balance)
      - [inputs set-input-audio-balance](#inputs-set-input-audio-balance)
      - [inputs get-input-audio-sync-offset](#inputs-get-input-audio-sync-offset)
      - [inputs set-input-audio-sync-offset](#inputs-set-input-audio-sync-offset)
      - [inputs get-input-audio-monitor-type](#inputs-get-input-audio-monitor-type)
      - [inputs set-input-audio-monitor-type](#inputs-set-input-audio-monitor-type)
      - [inputs get-input-audio-tracks](#inputs-get-input-audio-tracks)
      - [inputs set-input-audio-tracks](#inputs-set-input-audio-tracks)
      - [inputs get-input-properties-list-property-items](#inputs-get-input-properties-list-property-items)
      - [inputs press-input-properties-button](#inputs-press-input-properties-button)
      - [inputs remove-input](#inputs-remove-input)
      - [inputs set-input-mute](#inputs-set-input-mute)
      - [inputs set-input-name](#inputs-set-input-name)
      - [inputs toggle-input-mute](#inputs-toggle-input-mute)
    - [listen](#listen)
    - [outputs](#outputs)
      - [outputs get-virtual-cam-status](#outputs-get-virtual-cam-status)
      - [outputs toggle-virtual-cam](#outputs-toggle-virtual-cam)
      - [outputs start-virtual-cam](#outputs-start-virtual-cam)
      - [outputs stop-virtual-cam](#outputs-stop-virtual-cam)
      - [outputs get-replay-buffer-status](#outputs-get-replay-buffer-status)
      - [outputs toggle-replay-buffer](#outputs-toggle-replay-buffer)
      - [outputs start-replay-buffer](#outputs-start-replay-buffer)
      - [outputs stop-replay-buffer](#outputs-stop-replay-buffer)
      - [outputs save-replay-buffer](#outputs-save-replay-buffer)
      - [outputs get-output-list](#outputs-get-output-list)
      - [outputs get-output-status](#outputs-get-output-status)
      - [outputs toggle-output](#outputs-toggle-output)
      - [outputs start-output](#outputs-start-output)
      - [outputs stop-output](#outputs-stop-output)
      - [outputs get-output-settings](#outputs-get-output-settings)
      - [outputs set-output-settings](#outputs-set-output-settings)
    - [record](#record)
      - [record get-record-status](#record-get-record-status)
      - [record toggle-record](#record-toggle-record)
      - [record start-record](#record-start-record)
      - [record stop-record](#record-stop-record)
      - [record toggle-record-pause](#record-toggle-record-pause)
      - [record pause-record](#record-pause-record)
      - [record resume-record](#record-resume-record)
      - [record split-record-file](#record-split-record-file)
      - [record create-record-chapter](#record-create-record-chapter)
    - [scene-items](#scene-items)
      - [scene-items get-scene-item-list](#scene-items-get-scene-item-list)
      - [scene-items get-scene-item-locked](#scene-items-get-scene-item-locked)
      - [scene-items set-scene-item-locked](#scene-items-set-scene-item-locked)
    - [scenes](#scenes)
      - [scenes get-current-program-scene](#scenes-get-current-program-scene)
      - [scenes get-group-list](#scenes-get-group-list)
      - [scenes get-scenes-list](#scenes-get-scenes-list)
    - [send](#send)
    - [sources](#sources)
      - [sources get-source-active](#sources-get-source-active)
      - [sources get-source-screenshot](#sources-get-source-screenshot)
      - [sources save-source-screenshot](#sources-save-source-screenshot)
    - [stream](#stream)
      - [stream get-stream-status](#stream-get-stream-status)
      - [stream send-stream-caption](#stream-send-stream-caption)
      - [stream start-streaming](#stream-start-streaming)
      - [stream stop-streaming](#stream-stop-streaming)
      - [stream toggle-stream](#stream-toggle-stream)
    - [transitions](#transitions)
      - [transitions get-transition-kind-list](#transitions-get-transition-kind-list)
      - [transitions get-scene-transition-list](#transitions-get-scene-transition-list)
      - [transitions get-current-scene-transition](#transitions-get-current-scene-transition)
      - [transitions set-current-scene-transition](#transitions-set-current-scene-transition)
      - [transitions set-current-scene-transition-duration](#transitions-set-current-scene-transition-duration)
      - [transitions get-current-scene-transition-cursor](#transitions-get-current-scene-transition-cursor)
      - [transitions trigger-studio-mode-transition](#transitions-trigger-studio-mode-transition)
      - [transitions set-t-bar-position](#transitions-set-t-bar-position)
    - [ui](#ui)
      - [ui get-monitor-list](#ui-get-monitor-list)
      - [ui get-studio-mode-enabled](#ui-get-studio-mode-enabled)
      - [ui set-studio-mode-enabled](#ui-set-studio-mode-enabled)
    - [version](#version)
  - [Advanced Usage](#advanced-usage)
    - [Subscribing to an OBS event](#subscribing-to-an-obs-event)
    - [Trigger a shell command for an OBS event](#trigger-a-shell-command-for-an-obs-event)

## Installation

Install using `dart pub`:

For more information about `dart` and how to install it, check out [dart.dev](https://dart.dev/get-dart) 

```sh
dart pub global activate obs_cli
```

Install using `brew`:

For more information about the `brew` package manager and how to install it, check out [brew.sh](https://brew.sh/) 

```sh
brew tap cdavis-code/obs-websocket
brew install obs-cli
```

Install using `choco` (Windows):

For more information about the `choco` package manager and how to install it, check out [chocolatey.org](https://chocolatey.org/) 

```powershell
choco install obs-cli
```

Then check the install with,

```sh
obs --help
```

Result,

```text
A command line interface for controlling OBS.

Usage: obs <command> [arguments]

Global options:
-h, --help                        Print this usage information.
-u, --uri=<ws://[host]:[port]>    The url and port for OBS websocket
-t, --timeout=<int>               The timeout in seconds for the web socket connection.
-l, --log-level                   [all, debug, info, warning, error, off (default)]
-p, --passwd=<string>             The OBS websocket password, only required if enabled in OBS

Available commands:
  authorize     Generate an authentication file for an OBS connection
  config        Config Requests
  general       General commands
  inputs        Inputs Requests
  listen        Generate OBS events to stdout
  scene-items   Scene Items Requests
  scenes        Scenes Requests
  send          Send a low-level websocket request to OBS
  sources       Commands that manipulate OBS sources
  stream        Commands that manipulate OBS streams
  ui            Commands that manipulate the OBS user interface.
  version       Display the package name and version
```

| command | description |
| --- | --- |
| authorize | Generate an authentication file for an Onvif device |
| config | Config Requests - [documentation](https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md#config-requests) |
| general | General commands - [documentation](https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md#general-requests) |
| inputs | Inputs Requests - [documentation](https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md#inputs-requests) |
| listen | Generate OBS events to stdout - [documentation](https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md#events-table-of-contents) |
| scene-items | Scene Items Requests - [documentation](https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md#scene-items-requests) |
| scenes | Scenes Requests - [documentation](https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md#scenes-requests) |
| send | Send a low-level websocket request to OBS - [commands](https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md#requests-table-of-contents) |
| sources | Commands that manipulate OBS sources - [documentation](https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md#sources-requests) |
| ui | Commands that manipulate the OBS user interface - [documentation](https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md#ui-requests)
| stream | Commands that manipulate OBS streams -  [documentation](https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md#stream-requests) |
| version | The current package and version for this tool. |

Just like the main dart library, any responses provided through the above commands will be given in JSON format.  So ideally, you will want to use a command line json parser to interpret the results.  The recommended json parser for this purpose is [_jq_](https://stedolan.github.io/jq/).

## Quick start

For comprehensive examples and real-world usage patterns, see the [example/README.md](example/README.md) file.

```sh
# step 1 - Configure your OBS credentials in bin/.env
# Edit bin/.env with your OBS WebSocket URL and password
# OBS_WEBSOCKET_URL=ws://localhost:4455
# OBS_WEBSOCKET_PASSWORD=your_password
```

```sh
# step 2 - Generate the authentication file
obs authorize
```

```sh
# step 3 - Test the connection
obs stream get-stream-status
```

Gives result,

```text
{"outputActive":false,"outputReconnecting":false,"outputTimecode":"00:00:00.000","outputDuration":0,"outputCongestion":0.0,"outputBytes":0,"outputSkippedFrames":0,"outputTotalFrames":0}
```

```sh
# or using the jq utility
obs stream get-stream-status | jq -r '.outputActive'
```

Result is,

```text
false
```

```sh
# or alternatively use the low-level send command
obs send --command GetStreamStatus | jq -r '.responseData.outputActive'
# same output as before: false
```

## Available Commands

### authorize

```sh
obs authorize --help
```

```text
Validate OBS WebSocket credentials from bin/.env file by testing the connection

Usage: obs authorize [arguments]
-h, --help    Print this usage information.
```

The authorize command validates your OBS WebSocket credentials by attempting to connect to OBS using the configuration in `bin/.env`. This verifies that your credentials are correct and OBS is accessible.

**Required `.env` file format:**

```env
OBS_WEBSOCKET_URL=ws://[ip address or hostname]:[port]
OBS_WEBSOCKET_PASSWORD=[password]
```

**Setup instructions:**

1. Create or edit the `bin/.env` file in the obs_cli package directory
2. Add your OBS WebSocket URL and password
3. Run `obs authorize` to validate the connection

**Example output:**

```
Validating OBS WebSocket credentials from bin/.env...
✓ Successfully connected to OBS v30.1.2
✓ Credentials are valid

Authorization completed successfully.
Your OBS WebSocket credentials are working correctly.
```

If the connection fails, the command will display an error message with troubleshooting tips.

In general, this command is useful for verifying your OBS connection settings before running other commands.

### config

```sh
obs config --help
```

```text
Config Requests

Usage: obs config <subcommand> [arguments]
-h, --help    Print this usage information.

Available subcommands:
  get-record-directory          Gets the current directory that the record output is set to.
  get-stream-service-settings   Gets the current stream service settings (stream destination).
  get-video-settings            Gets the current video settings.
  set-stream-service-settings   Sets the current stream service settings (stream destination).
  set-video-settings            Sets the current video settings.
```

#### config get-record-directory

```sh
obs config get-record-directory --help
```

```text
Gets the current directory that the record output is set to.

Usage: obs config get-record-directory [arguments]
-h, --help    Print this usage information.
```


#### config get-stream-service-settings

```sh
obs config get-stream-service-settings --help
```

```text
Gets the current stream service settings (stream destination).

Usage: obs config get-stream-service-settings [arguments]
-h, --help    Print this usage information.
```

#### config get-video-settings

```sh
obs config get-video-settings --help
```

```text
Gets the current video settings.

Usage: obs config get-video-settings [arguments]
-h, --help    Print this usage information.
```

#### config set-stream-service-settings

```sh
obs config set-stream-service-settings --help
```

```text
Sets the current stream service settings (stream destination).

Usage: obs config set-stream-service-settings [arguments]
-h, --help                                          Print this usage information.
    --stream-service-type=<string> (mandatory)      Type of stream service to apply. Example: rtmp_common or rtmp_custom
    --stream-service-settings=<json> (mandatory)    Settings to apply to the service
```

#### config set-video-settings

```sh
obs config set-video-settings --help
```

```text
Sets the current video settings.

Usage: obs config set-video-settings [arguments]
-h, --help                                        Print this usage information.
    --fps-numerator=<int (greater than 0)>        Numerator of the fractional FPS value
    --fps-denominator=<int (greater than 0)>      Denominator of the fractional FPS value
    --base-width=<int (between 1 and 4096)>       Width of the base (canvas) resolution in pixels
    --base-height=<int (between 1 and 4096)>      Height of the base (canvas) resolution in pixels
    --output-width=<int (between 1 and 4096)>     Width of the output resolution in pixels
    --output-height=<int (between 1 and 4096)>    Height of the output resolution in pixels
```

### filters

```sh
obs filters --help
```

```text
Manage source filters.

Usage: obs filters <subcommand> [arguments]
-h, --help    Print this usage information.

Available subcommands:
  get-source-filter-kind-list          Gets an array of all available source filter kinds.
  get-source-filter-list               Gets an array of all of a source's filters.
  get-source-filter-default-settings   Gets the default settings for a filter kind.
  create-source-filter                 Creates a new filter, adding it to a source.
  get-source-filter                    Gets the info for a specific source filter.
  set-source-filter-settings           Sets the settings of a source filter.
  remove-source-filter                 Removes a filter from a source.
  set-source-filter-name               Sets the name of a source filter (rename).
  set-source-filter-index              Sets the index position of a filter on a source.
  set-source-filter-enabled            Sets the enable state of a source filter.
```

#### filters get-source-filter-kind-list

```sh
obs filters get-source-filter-kind-list --help
```

```text
Gets an array of all available source filter kinds.

Usage: obs filters get-source-filter-kind-list [arguments]
-h, --help    Print this usage information.
```

#### filters get-source-filter-list

```sh
obs filters get-source-filter-list --help
```

```text
Gets an array of all of a source's filters.

Usage: obs filters get-source-filter-list [arguments]
-h, --help              Print this usage information.
    --sourceName        Name of the source
```

**Example:**
```sh
obs filters get-source-filter-list --sourceName "Video Capture Device" | jq
```

#### filters get-source-filter-default-settings

```sh
obs filters get-source-filter-default-settings --help
```

```text
Gets the default settings for a filter kind.

Usage: obs filters get-source-filter-default-settings [arguments]
-h, --help              Print this usage information.
    --filterKind        The kind of filter
```

**Example:**
```sh
obs filters get-source-filter-default-settings --filterKind "color_correction_v2" | jq
```

#### filters create-source-filter

```sh
obs filters create-source-filter --help
```

```text
Creates a new filter, adding it to a source.

Usage: obs filters create-source-filter [arguments]
-h, --help                        Print this usage information.
    --sourceName                  Name of the source
    --filterName                  Name of the new filter
    --filterKind                  The kind of filter to create
    --filterSettings              JSON object of filter settings
```

**Notes:**
- `sourceName`, `filterName`, and `filterKind` are required
- `filterSettings` is optional and should be a JSON string

**Example:**
```sh
obs filters create-source-filter \
  --sourceName "Video Capture Device" \
  --filterName "My Color Correction" \
  --filterKind "color_correction_v2" \
  --filterSettings '{"gamma": 1.5}'
```

#### filters get-source-filter

```sh
obs filters get-source-filter --help
```

```text
Gets the info for a specific source filter.

Usage: obs filters get-source-filter [arguments]
-h, --help              Print this usage information.
    --sourceName        Name of the source
    --filterName        Name of the filter
```

**Example:**
```sh
obs filters get-source-filter \
  --sourceName "Video Capture Device" \
  --filterName "My Color Correction" | jq
```

#### filters set-source-filter-settings

```sh
obs filters set-source-filter-settings --help
```

```text
Sets the settings of a source filter.

Usage: obs filters set-source-filter-settings [arguments]
-h, --help                        Print this usage information.
    --sourceName                  Name of the source
    --filterName                  Name of the filter
    --filterSettings              JSON object of filter settings
    --overlay                     Whether to overlay settings instead of replacing
```

**Notes:**
- `sourceName`, `filterName`, and `filterSettings` are required
- `filterSettings` must be a valid JSON string
- Use `--overlay` to merge settings instead of replacing them

**Example:**
```sh
obs filters set-source-filter-settings \
  --sourceName "Video Capture Device" \
  --filterName "My Color Correction" \
  --filterSettings '{"gamma": 2.0}'
```

#### filters remove-source-filter

```sh
obs filters remove-source-filter --help
```

```text
Removes a filter from a source.

Usage: obs filters remove-source-filter [arguments]
-h, --help              Print this usage information.
    --sourceName        Name of the source
    --filterName        Name of the filter to remove
```

**Example:**
```sh
obs filters remove-source-filter \
  --sourceName "Video Capture Device" \
  --filterName "My Color Correction"
```

#### filters set-source-filter-name

```sh
obs filters set-source-filter-name --help
```

```text
Sets the name of a source filter (rename).

Usage: obs filters set-source-filter-name [arguments]
-h, --help              Print this usage information.
    --sourceName        Name of the source
    --filterName        Current name of the filter
    --newFilterName     New name for the filter
```

**Example:**
```sh
obs filters set-source-filter-name \
  --sourceName "Video Capture Device" \
  --filterName "My Color Correction" \
  --newFilterName "Better Color Correction"
```

#### filters set-source-filter-index

```sh
obs filters set-source-filter-index --help
```

```text
Sets the index position of a filter on a source.

Usage: obs filters set-source-filter-index [arguments]
-h, --help              Print this usage information.
    --sourceName        Name of the source
    --filterName        Name of the filter
    --filterIndex       New index position of the filter
```

**Notes:**
- Filter index starts at 0 (top of the filter list)

**Example:**
```sh
obs filters set-source-filter-index \
  --sourceName "Video Capture Device" \
  --filterName "My Color Correction" \
  --filterIndex 0
```

#### filters set-source-filter-enabled

```sh
obs filters set-source-filter-enabled --help
```

```text
Sets the enable state of a source filter.

Usage: obs filters set-source-filter-enabled [arguments]
-h, --help                  Print this usage information.
    --sourceName            Name of the source
    --filterName            Name of the filter
    --[no-]filterEnabled    Whether the filter is enabled (defaults to on)
```

**Example:**
```sh
# Enable filter
obs filters set-source-filter-enabled \
  --sourceName "Video Capture Device" \
  --filterName "My Color Correction"

# Disable filter
obs filters set-source-filter-enabled \
  --sourceName "Video Capture Device" \
  --filterName "My Color Correction" \
  --no-filterEnabled
```

### general

```sh
obs general --help
```

```text
General commands

Usage: obs general <subcommand> [arguments]
-h, --help    Print this usage information.

Available subcommands:
  get-stats     Gets statistics about OBS, obs-websocket, and the current session.
  get-version   Gets data about the current plugin and RPC version.
```

#### general get-stats

```sh
obs general get-stats --help
```

```text
Gets statistics about OBS, obs-websocket, and the current session.

Usage: obs general get-stats [arguments]
-h, --help    Print this usage information.
```

#### general get-version

```sh
obs general get-version --help
```

```text
Gets data about the current plugin and RPC version.

Usage: obs general get-version [arguments]
-h, --help    Print this usage information.
```

### inputs 

```sh
obs inputs --help
```

```text
Inputs Requests

Usage: obs inputs <subcommand> [arguments]
-h, --help    Print this usage information.

Available subcommands:
  get-input-kind-list                         Gets an array of all available input kinds in OBS.
  get-input-list                              Gets an array of all inputs in OBS.
  get-input-mute                              Gets the mute status of an input.
  get-input-volume                            Gets the current volume setting of an input.
  set-input-volume                            Sets the volume setting of an input.
  get-input-deinterlace-mode                  Gets the deinterlace mode of an input.
  set-input-deinterlace-mode                  Sets the deinterlace mode of an input.
  get-input-deinterlace-field-order           Gets the deinterlace field order of an input.
  set-input-deinterlace-field-order           Sets the deinterlace field order of an input.
  get-input-audio-balance                     Gets the audio balance of an input.
  set-input-audio-balance                     Sets the audio balance of an input.
  get-input-audio-sync-offset                 Gets the audio sync offset of an input.
  set-input-audio-sync-offset                 Sets the audio sync offset of an input.
  get-input-audio-monitor-type                Gets the audio monitor type of an input.
  set-input-audio-monitor-type                Sets the audio monitor type of an input.
  get-input-audio-tracks                      Gets the audio tracks of an input.
  set-input-audio-tracks                      Sets the audio tracks of an input.
  get-input-properties-list-property-items    Gets the items of a list property of an input.
  press-input-properties-button               Presses a button property of an input.
  remove-input                                Removes an existing input.
  set-input-mute                              Sets the mute status of an input.
  set-input-name                              Sets the name of an input (rename).
  toggle-input-mute                           Toggles the mute status of an input.
```

#### inputs get-input-kind-list

```sh
obs inputs get-input-kind-list --help
```

```text
Gets an array of all available input kinds in OBS.

Usage: obs inputs get-input-kind-list [arguments]
-h, --help                Print this usage information.
    --[no-]unversioned    Whether to get unversioned input kinds.
```

#### inputs get-input-list

```sh
obs inputs get-input-list --help
```

```text
Gets an array of all inputs in OBS.

Usage: obs inputs get-input-list [arguments]
-h, --help         Print this usage information.
    --inputKind    The kind of input to get.
```

#### inputs get-input-mute

```sh
obs inputs get-input-mute --help
```

```text
Gets the mute status of an input.

Usage: obs inputs get-input-mute [arguments]
-h, --help         Print this usage information.
    --inputName    The name of the input to get the mute status of.
```

#### inputs remove-input

```sh
obs inputs remove-input --help
```

```text
Removes an existing input.

Usage: obs inputs remove-input [arguments]
-h, --help         Print this usage information.
    --inputName    The name of the input to remove.
```

#### inputs set-input-mute

```sh
obs inputs set-input-mute --help
```

```text
Sets the mute status of an input.

Usage: obs inputs set-input-mute [arguments]
-h, --help         Print this usage information.
    --inputName    The name of the input to set the mute status of.
    --[no-]mute    Whether to mute the input.
```

#### inputs set-input-name

```sh
obs inputs set-input-name --help
```

```text
Sets the name of an input (rename).

Usage: obs inputs set-input-name [arguments]
-h, --help            Print this usage information.
    --inputName       The name of the input to rename.
    --newInputName    The new name of the input.
```

#### inputs toggle-input-mute

```sh
obs inputs toggle-input-mute --help
```

```text
Toggles the mute status of an input.

Usage: obs inputs toggle-input-mute [arguments]
-h, --help         Print this usage information.
    --inputName    The name of the input to toggle the mute status of.
```

#### inputs get-input-volume

```sh
obs inputs get-input-volume --help
```

```text
Gets the current volume setting of an input.

Usage: obs inputs get-input-volume [arguments]
-h, --help         Print this usage information.
    --inputName    Name of the input
    --inputUuid    UUID of the input
```

**Notes:**
- Either `inputName` or `inputUuid` must be provided

**Example:**
```sh
obs inputs get-input-volume --inputName "Audio Capture Device" | jq
```

#### inputs set-input-volume

```sh
obs inputs set-input-volume --help
```

```text
Sets the volume setting of an input.

Usage: obs inputs set-input-volume [arguments]
-h, --help                      Print this usage information.
    --inputName                 Name of the input
    --inputUuid                 UUID of the input
    --inputVolumeMul=<float>    Volume multiplier (0.0 to 20.0)
    --inputVolumeDb=<float>     Volume in dB (-100.0 to 26.0)
```

**Notes:**
- Either `inputName` or `inputUuid` must be provided
- Either `inputVolumeMul` or `inputVolumeDb` must be provided

**Example:**
```sh
obs inputs set-input-volume --inputName "Audio Capture Device" --inputVolumeDb -10.0
```

#### inputs get-input-deinterlace-mode

```sh
obs inputs get-input-deinterlace-mode --help
```

```text
Gets the deinterlace mode of an input.

Usage: obs inputs get-input-deinterlace-mode [arguments]
-h, --help         Print this usage information.
    --inputName    Name of the input
    --inputUuid    UUID of the input
```

#### inputs set-input-deinterlace-mode

```sh
obs inputs set-input-deinterlace-mode --help
```

```text
Sets the deinterlace mode of an input.

Usage: obs inputs set-input-deinterlace-mode [arguments]
-h, --help                    Print this usage information.
    --inputName               Name of the input
    --inputUuid               UUID of the input
    --deinterlaceMode=<mode>  Deinterlace mode

Allowed modes:
  disable, discard, retain, retain_top, retain_bottom
```

#### inputs get-input-deinterlace-field-order

```sh
obs inputs get-input-deinterlace-field-order --help
```

```text
Gets the deinterlace field order of an input.

Usage: obs inputs get-input-deinterlace-field-order [arguments]
-h, --help         Print this usage information.
    --inputName    Name of the input
    --inputUuid    UUID of the input
```

#### inputs set-input-deinterlace-field-order

```sh
obs inputs set-input-deinterlace-field-order --help
```

```text
Sets the deinterlace field order of an input.

Usage: obs inputs set-input-deinterlace-field-order [arguments]
-h, --help                       Print this usage information.
    --inputName                  Name of the input
    --inputUuid                  UUID of the input
    --deinterlaceFieldOrder=<order>  Field order

Allowed orders:
  top, bottom
```

#### inputs get-input-audio-balance

```sh
obs inputs get-input-audio-balance --help
```

```text
Gets the audio balance of an input.

Usage: obs inputs get-input-audio-balance [arguments]
-h, --help         Print this usage information.
    --inputName    Name of the input
    --inputUuid    UUID of the input
```

#### inputs set-input-audio-balance

```sh
obs inputs set-input-audio-balance --help
```

```text
Sets the audio balance of an input.

Usage: obs inputs set-input-audio-balance [arguments]
-h, --help                      Print this usage information.
    --inputName                 Name of the input
    --inputUuid                 UUID of the input
    --inputAudioBalance=<float> Audio balance (0.0 to 1.0)
```

#### inputs get-input-audio-sync-offset

```sh
obs inputs get-input-audio-sync-offset --help
```

```text
Gets the audio sync offset of an input.

Usage: obs inputs get-input-audio-sync-offset [arguments]
-h, --help         Print this usage information.
    --inputName    Name of the input
    --inputUuid    UUID of the input
```

#### inputs set-input-audio-sync-offset

```sh
obs inputs set-input-audio-sync-offset --help
```

```text
Sets the audio sync offset of an input.

Usage: obs inputs set-input-audio-sync-offset [arguments]
-h, --help                          Print this usage information.
    --inputName                     Name of the input
    --inputUuid                     UUID of the input
    --inputAudioSyncOffset=<int>    Sync offset in milliseconds
```

#### inputs get-input-audio-monitor-type

```sh
obs inputs get-input-audio-monitor-type --help
```

```text
Gets the audio monitor type of an input.

Usage: obs inputs get-input-audio-monitor-type [arguments]
-h, --help         Print this usage information.
    --inputName    Name of the input
    --inputUuid    UUID of the input
```

#### inputs set-input-audio-monitor-type

```sh
obs inputs set-input-audio-monitor-type --help
```

```text
Sets the audio monitor type of an input.

Usage: obs inputs set-input-audio-monitor-type [arguments]
-h, --help                         Print this usage information.
    --inputName                    Name of the input
    --inputUuid                    UUID of the input
    --monitorType=<type>           Monitor type

Allowed types:
  none, monitor only, monitor and output
```

#### inputs get-input-audio-tracks

```sh
obs inputs get-input-audio-tracks --help
```

```text
Gets the audio tracks of an input.

Usage: obs inputs get-input-audio-tracks [arguments]
-h, --help         Print this usage information.
    --inputName    Name of the input
    --inputUuid    UUID of the input
```

#### inputs set-input-audio-tracks

```sh
obs inputs set-input-audio-tracks --help
```

```text
Sets the audio tracks of an input.

Usage: obs inputs set-input-audio-tracks [arguments]
-h, --help                        Print this usage information.
    --inputName                   Name of the input
    --inputUuid                   UUID of the input
    --inputAudioTracks=<tracks>   Audio tracks (1-6)
```

#### inputs get-input-properties-list-property-items

```sh
obs inputs get-input-properties-list-property-items --help
```

```text
Gets the items of a list property of an input.

Usage: obs inputs get-input-properties-list-property-items [arguments]
-h, --help              Print this usage information.
    --inputName         Name of the input
    --inputUuid         UUID of the input
    --propertyName      Name of the list property
```

#### inputs press-input-properties-button

```sh
obs inputs press-input-properties-button --help
```

```text
Presses a button property of an input.

Usage: obs inputs press-input-properties-button [arguments]
-h, --help              Print this usage information.
    --inputName         Name of the input
    --inputUuid         UUID of the input
    --propertyName      Name of the button property
```

### listen 

```sh
obs listen --help
```

```text
Generate OBS events to stdout

Usage: obs listen [arguments]
-h, --help      Print this usage information.
    --event-subscriptions=<Supply one more more values comma separated.
    See https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md#eventsubscription>
    Name of the source to get the active state of.

          [all] (default)               Helper to receive all non-high-volume events.
          [config]                      Subscription value to receive events in the Config category.
          [filters]                     Subscription value to receive events in the Filters category.
          [general]                     Subscription value to receive events in the General category.
          [inputActiveStateChanged]     Subscription value to receive the InputActiveStateChanged high-volume event.
          [inputShowStateChanged]       Subscription value to receive the InputShowStateChanged high-volume event.
          [inputVolumeMeters]           Subscription value to receive the InputVolumeMeters high-volume event.
          [inputs]                      Subscription value to receive events in the Inputs category.
          [mediaInputs]                 Subscription value to receive events in the MediaInputs category.
          [none]                        Subscription value used to disable all events.
          [outputs]                     Subscription value to receive events in the Outputs category.
          [sceneItemTransformChanged]   Subscription value to receive the SceneItemTransformChanged high-volume event.
          [sceneItems]                  Subscription value to receive events in the SceneItems category.
          [scenes]                      Subscription value to receive events in the Scenes category.
          [transitions]                 Subscription value to receive events in the Transitions category.
          [ui]                          Subscription value to receive events in the Ui category.
          [vendors]                     Subscription value to receive the VendorEvent event.
```

### outputs

```sh
obs outputs --help
```

```text
Manage OBS outputs (virtual cam, replay buffer, generic outputs).

Usage: obs outputs <subcommand> [arguments]
-h, --help    Print this usage information.

Available subcommands:
  get-virtual-cam-status       Gets the status of the virtual cam output.
  toggle-virtual-cam           Toggles the state of the virtual cam output.
  start-virtual-cam            Starts the virtual cam output.
  stop-virtual-cam             Stops the virtual cam output.
  get-replay-buffer-status     Gets the status of the replay buffer output.
  toggle-replay-buffer         Toggles the state of the replay buffer output.
  start-replay-buffer          Starts the replay buffer output.
  stop-replay-buffer           Stops the replay buffer output.
  save-replay-buffer           Saves the replay buffer output to disk.
  get-output-list              Gets the list of available outputs.
  get-output-status            Gets the status of a specific output.
  toggle-output                Toggles the status of a specific output.
  start-output                 Starts a specific output.
  stop-output                  Stops a specific output.
  get-output-settings          Gets the settings of a specific output.
  set-output-settings          Sets the settings of a specific output.
```

#### outputs get-virtual-cam-status

```sh
obs outputs get-virtual-cam-status --help
```

```text
Gets the status of the virtual cam output.

Usage: obs outputs get-virtual-cam-status [arguments]
-h, --help    Print this usage information.
```

#### outputs toggle-virtual-cam

```sh
obs outputs toggle-virtual-cam --help
```

```text
Toggles the state of the virtual cam output.

Usage: obs outputs toggle-virtual-cam [arguments]
-h, --help    Print this usage information.
```

#### outputs start-virtual-cam

```sh
obs outputs start-virtual-cam --help
```

```text
Starts the virtual cam output.

Usage: obs outputs start-virtual-cam [arguments]
-h, --help    Print this usage information.
```

#### outputs stop-virtual-cam

```sh
obs outputs stop-virtual-cam --help
```

```text
Stops the virtual cam output.

Usage: obs outputs stop-virtual-cam [arguments]
-h, --help    Print this usage information.
```

#### outputs get-replay-buffer-status

```sh
obs outputs get-replay-buffer-status --help
```

```text
Gets the status of the replay buffer output.

Usage: obs outputs get-replay-buffer-status [arguments]
-h, --help    Print this usage information.
```

#### outputs toggle-replay-buffer

```sh
obs outputs toggle-replay-buffer --help
```

```text
Toggles the state of the replay buffer output.

Usage: obs outputs toggle-replay-buffer [arguments]
-h, --help    Print this usage information.
```

#### outputs start-replay-buffer

```sh
obs outputs start-replay-buffer --help
```

```text
Starts the replay buffer output.

Usage: obs outputs start-replay-buffer [arguments]
-h, --help    Print this usage information.
```

#### outputs stop-replay-buffer

```sh
obs outputs stop-replay-buffer --help
```

```text
Stops the replay buffer output.

Usage: obs outputs stop-replay-buffer [arguments]
-h, --help    Print this usage information.
```

#### outputs save-replay-buffer

```sh
obs outputs save-replay-buffer --help
```

```text
Saves the replay buffer output to disk.

Usage: obs outputs save-replay-buffer [arguments]
-h, --help    Print this usage information.
```

#### outputs get-output-list

```sh
obs outputs get-output-list --help
```

```text
Gets the list of available outputs.

Usage: obs outputs get-output-list [arguments]
-h, --help    Print this usage information.
```

#### outputs get-output-status

```sh
obs outputs get-output-status --help
```

```text
Gets the status of a specific output.

Usage: obs outputs get-output-status [arguments]
-h, --help          Print this usage information.
    --outputName    Name of the output
```

#### outputs toggle-output

```sh
obs outputs toggle-output --help
```

```text
Toggles the status of a specific output.

Usage: obs outputs toggle-output [arguments]
-h, --help          Print this usage information.
    --outputName    Name of the output
```

#### outputs start-output

```sh
obs outputs start-output --help
```

```text
Starts a specific output.

Usage: obs outputs start-output [arguments]
-h, --help          Print this usage information.
    --outputName    Name of the output
```

#### outputs stop-output

```sh
obs outputs stop-output --help
```

```text
Stops a specific output.

Usage: obs outputs stop-output [arguments]
-h, --help          Print this usage information.
    --outputName    Name of the output
```

#### outputs get-output-settings

```sh
obs outputs get-output-settings --help
```

```text
Gets the settings of a specific output.

Usage: obs outputs get-output-settings [arguments]
-h, --help          Print this usage information.
    --outputName    Name of the output
```

#### outputs set-output-settings

```sh
obs outputs set-output-settings --help
```

```text
Sets the settings of a specific output.

Usage: obs outputs set-output-settings [arguments]
-h, --help                  Print this usage information.
    --outputName            Name of the output
    --outputSettings        JSON object of output settings
```

**Notes:**
- `outputSettings` must be a valid JSON string

**Example:**
```sh
obs outputs set-output-settings \
  --outputName "virtualcam_output" \
  --outputSettings '{"key": "value"}'
```

### record

```sh
obs record --help
```

```text
Manage OBS recording.

Usage: obs record <subcommand> [arguments]
-h, --help    Print this usage information.

Available subcommands:
  get-record-status       Gets the status of the record output.
  toggle-record           Toggles the status of the record output.
  start-record            Starts the record output.
  stop-record             Stops the record output.
  toggle-record-pause     Toggles pause on the record output.
  pause-record            Pauses the record output.
  resume-record           Resumes the record output.
  split-record-file       Splits the current recording file.
  create-record-chapter   Creates a new chapter in the recording.
```

#### record get-record-status

```sh
obs record get-record-status --help
```

```text
Gets the status of the record output.

Usage: obs record get-record-status [arguments]
-h, --help    Print this usage information.
```

#### record toggle-record

```sh
obs record toggle-record --help
```

```text
Toggles the status of the record output.

Usage: obs record toggle-record [arguments]
-h, --help    Print this usage information.
```

#### record start-record

```sh
obs record start-record --help
```

```text
Starts the record output.

Usage: obs record start-record [arguments]
-h, --help    Print this usage information.
```

#### record stop-record

```sh
obs record stop-record --help
```

```text
Stops the record output.

Usage: obs record stop-record [arguments]
-h, --help    Print this usage information.
```

#### record toggle-record-pause

```sh
obs record toggle-record-pause --help
```

```text
Toggles pause on the record output.

Usage: obs record toggle-record-pause [arguments]
-h, --help    Print this usage information.
```

#### record pause-record

```sh
obs record pause-record --help
```

```text
Pauses the record output.

Usage: obs record pause-record [arguments]
-h, --help    Print this usage information.
```

#### record resume-record

```sh
obs record resume-record --help
```

```text
Resumes the record output.

Usage: obs record resume-record [arguments]
-h, --help    Print this usage information.
```

#### record split-record-file

```sh
obs record split-record-file --help
```

```text
Splits the current recording file.

Usage: obs record split-record-file [arguments]
-h, --help    Print this usage information.
```

**Notes:**
- This feature requires recording format to support chapters (e.g., MKV)

#### record create-record-chapter

```sh
obs record create-record-chapter --help
```

```text
Creates a new chapter in the recording.

Usage: obs record create-record-chapter [arguments]
-h, --help            Print this usage information.
    --chapterName     Name of the chapter
```

**Notes:**
- `chapterName` is optional
- This feature requires recording format to support chapters (e.g., MKV)

### scene-items

```sh
obs scene-items --help
```

```text
Scene Items Requests

Usage: obs scene-items <subcommand> [arguments]
-h, --help    Print this usage information.

Available subcommands:
  get-scene-item-list     Gets the lock state of a scene item.
  get-scene-item-locked   Gets the lock state of a scene item.
  set-scene-item-locked   Sets the lock state of a scene item.
```

#### scene-items get-scene-item-list

```sh
obs scene-items get-scene-item-list --help
```

```text
Gets a list of all scene items in a scene.

Usage: obs scene-items get-scene-item-list [arguments]
-h, --help                               Print this usage information.
-n, --scene-name=<string> (mandatory)    Name of the scene to get the items of
```

#### scene-items get-scene-item-locked

```sh
obs scene-items get-scene-item-locked --help
```

```text
Gets the lock state of a scene item.

Usage: obs scene-items get-scene-item-locked [arguments]
-h, --help                               Print this usage information.
-n, --scene-name=<string> (mandatory)    Name of the scene the item is in
-i, --scene-item-id=<int> (mandatory)    Numeric ID of the scene item
```

#### scene-items set-scene-item-locked

```sh
obs scene-items set-scene-item-locked --help
```

```text
Sets the lock state of a scene item.

Usage: obs scene-items set-scene-item-locked [arguments]
-h, --help                               Print this usage information.
-n, --scene-name=<string> (mandatory)    Name of the scene the item is in
-i, --scene-item-id=<int> (mandatory)    Numeric ID of the scene item
-l, --[no-]scene-item-locked             New lock state of the scene item
```

### scenes

```sh
obs scenes --help
```

```text
Scenes Requests

Usage: obs scenes <subcommand> [arguments]
-h, --help    Print this usage information.

Available subcommands:
  get-current-program-scene   Gets the current program scene.
  get-group-list              Gets an array of all groups in OBS.
  get-scenes-list             Gets an array of all scenes in OBS.
```

#### scenes get-current-program-scene

```sh
obs scenes get-current-program-scene --help
```

```text
Gets the current program scene.

Usage: obs scenes get-current-program-scene [arguments]
-h, --help    Print this usage information.
```

#### scenes get-group-list

```sh
obs scenes get-group-list --help
```

```text
Gets an array of all groups in OBS.

Usage: obs scenes get-group-list [arguments]
-h, --help    Print this usage information.
```

#### scenes get-scenes-list

```sh
obs scenes get-scenes-list --help
```

```text
Gets an array of all scenes in OBS.

Usage: obs scenes get-scenes-list [arguments]
-h, --help    Print this usage information.
```

### send

```sh
obs send --help
```

```text
Option command is mandatory.

Usage: obs send [arguments]
-h, --help                            Print this usage information.
-c, --command=<string> (mandatory)    One of the OBS web socket supported requests - https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md#requests-table-of-contents
-a, --args=<json string>              The json representing the arguments necessary for the supplied command.
```

### sources

```sh
obs sources --help
```

```text
Commands that manipulate OBS sources

Usage: obs sources <subcommand> [arguments]
-h, --help    Print this usage information.

Available subcommands:
  get-source-active        Gets the active and show state of a source.
  get-source-screenshot    Gets a Base64-encoded screenshot of a source.
  save-source-screenshot   Saves a screenshot of a source to the filesystem.
```

#### sources get-source-active

```sh
obs sources get-source-active --help
```

```text
Gets the active and show state of a source.

Usage: obs sources get-source-active [arguments]
-h, --help                                Print this usage information.
    --source-name=<string> (mandatory)    Name of the source to get the active state of
```

#### sources get-source-screenshot

```sh
obs sources get-source-screenshot --help
```

```text
Gets a Base64-encoded screenshot of a source.

Usage: obs sources get-source-screenshot [arguments]
-h, --help                                 Print this usage information.
    --source-name=<string> (mandatory)     Name of the source to take a screenshot of
    --image-format=<string> (mandatory)    Image compression format to use. Use GetVersion to get compatible image formats
```

#### sources save-source-screenshot

```sh
obs sources save-source-screenshot --help
```

```text
Saves a screenshot of a source to the filesystem.

Usage: obs sources save-source-screenshot [arguments]
-h, --help                                    Print this usage information.
    --source-name=<string> (mandatory)        Name of the source to take a screenshot of
    --image-format=<string> (mandatory)       Image compression format to use. Use GetVersion to get compatible image formats
    --image-file-path=<string> (mandatory)    Path to save the screenshot file to.
```

### stream

```sh
obs stream --help
```

```text
Commands that manipulate OBS streams

Usage: obs stream <subcommand> [arguments]
-h, --help    Print this usage information.

Available subcommands:
  get-stream-status     Gets the status of the stream output.
  send-stream-caption   Sends CEA-608 caption text over the stream output.
  start-streaming       Starts the stream output.
  stop-streaming        Stops the stream output.
  toggle-stream         Toggles the status of the stream output.
```

#### stream get-stream-status

```sh
obs stream get-stream-status --help
```

```text
Gets the status of the stream output.

Usage: obs stream get-stream-status [arguments]
-h, --help    Print this usage information.
```

#### stream send-stream-caption

```sh
obs stream send-stream-caption --help
```

```text
Sends CEA-608 caption text over the stream output.

Usage: obs stream send-stream-caption [arguments]
-h, --help                                 Print this usage information.
    --caption-Text=<string> (mandatory)    Caption text
```

#### stream start-streaming

```sh
obs stream start-streaming --help
```

```text
Starts the stream output.

Usage: obs stream start-streaming [arguments]
-h, --help    Print this usage information.
``` 

#### stream stop-streaming

```sh
obs stream stop-streaming --help
```

```text
Stops the stream output.

Usage: obs stream stop-streaming [arguments]
-h, --help    Print this usage information.
```


#### stream toggle-stream

```sh
obs stream toggle-stream --help
```

```text
Toggles the status of the stream output.

Usage: obs stream toggle-stream [arguments]
-h, --help    Print this usage information.
``` 

### transitions

```sh
obs transitions --help
```

```text
Manage OBS scene transitions.

Usage: obs transitions <subcommand> [arguments]
-h, --help    Print this usage information.

Available subcommands:
  get-transition-kind-list            Gets an array of all available transition kinds.
  get-scene-transition-list           Gets an array of all scene transitions.
  get-current-scene-transition        Gets the current scene transition.
  set-current-scene-transition        Sets the current scene transition.
  set-current-scene-transition-duration    Sets the duration of the current scene transition.
  get-current-scene-transition-cursor  Gets the cursor position of the current scene transition.
  trigger-studio-mode-transition      Triggers a transition in studio mode.
  set-t-bar-position                  Sets the position of the T-Bar.
```

#### transitions get-transition-kind-list

```sh
obs transitions get-transition-kind-list --help
```

```text
Gets an array of all available transition kinds.

Usage: obs transitions get-transition-kind-list [arguments]
-h, --help    Print this usage information.
```

#### transitions get-scene-transition-list

```sh
obs transitions get-scene-transition-list --help
```

```text
Gets an array of all scene transitions.

Usage: obs transitions get-scene-transition-list [arguments]
-h, --help    Print this usage information.
```

#### transitions get-current-scene-transition

```sh
obs transitions get-current-scene-transition --help
```

```text
Gets the current scene transition.

Usage: obs transitions get-current-scene-transition [arguments]
-h, --help    Print this usage information.
```

#### transitions set-current-scene-transition

```sh
obs transitions set-current-scene-transition --help
```

```text
Sets the current scene transition.

Usage: obs transitions set-current-scene-transition [arguments]
-h, --help                  Print this usage information.
    --transitionName        Name of the transition to set as current
```

#### transitions set-current-scene-transition-duration

```sh
obs transitions set-current-scene-transition-duration --help
```

```text
Sets the duration of the current scene transition.

Usage: obs transitions set-current-scene-transition-duration [arguments]
-h, --help                      Print this usage information.
    --transitionDuration        Duration of the transition in milliseconds
```

#### transitions get-current-scene-transition-cursor

```sh
obs transitions get-current-scene-transition-cursor --help
```

```text
Gets the cursor position of the current scene transition.

Usage: obs transitions get-current-scene-transition-cursor [arguments]
-h, --help    Print this usage information.
```

**Notes:**
- Returns the current position of the transition cursor (0.0 to 1.0)
- Only applicable when a transition is in progress

#### transitions trigger-studio-mode-transition

```sh
obs transitions trigger-studio-mode-transition --help
```

```text
Triggers a transition in studio mode.

Usage: obs transitions trigger-studio-mode-transition [arguments]
-h, --help    Print this usage information.
```

**Notes:**
- Studio mode must be enabled for this command to work

#### transitions set-t-bar-position

```sh
obs transitions set-t-bar-position --help
```

```text
Sets the position of the T-Bar.

Usage: obs transitions set-t-bar-position [arguments]
-h, --help              Print this usage information.
    --position          Position of the T-Bar (0.0 to 1.0)
```

**Notes:**
- The T-Bar is used for manual transition control
- Position 0.0 is the start, 1.0 is the end

### ui

```sh
obs ui --help
```

```text
Commands that manipulate the OBS user interface.

Usage: obs ui <subcommand> [arguments]
-h, --help    Print this usage information.

Available subcommands:
  get-monitor-list          Gets a list of connected monitors and information about them.
  get-studio-mode-enabled   Gets whether studio is enabled.
  set-studio-mode-enabled   Enables or disables studio mode.
```


#### ui get-monitor-list 

```sh
obs ui get-monitor-list  --help
```

```text
Gets a list of connected monitors and information about them.

Usage: obs ui get-monitor-list [arguments]
-h, --help    Print this usage information.
``` 


#### ui get-studio-mode-enabled

```sh
obs ui get-studio-mode-enabled  --help
```

```text
Gets whether studio is enabled.

Usage: obs ui get-studio-mode-enabled [arguments]
-h, --help    Print this usage information.
``` 


#### ui set-studio-mode-enabled

```sh
obs ui set-studio-mode-enabled  --help
```

```text
Enables or disables studio mode.

Usage: obs ui set-studio-mode-enabled [arguments]
-h, --help                Print this usage information.
-m, --[no-]studio-mode    
``` 

### version

```sh
obs version --help
```

```text
Display the package name and version

Usage: obs version [arguments]
-h, --help    Print this usage information.
```

## Advanced Usage

### Subscribing to an OBS event

```sh
# will output json for any "scene" related event 
obs listen --event-subscriptions scenes
```

Gives the following result,

```text
{"eventType":"CurrentProgramSceneChanged","eventIntent":4,"eventData":{"sceneName":"Scene 2"}}
{"eventType":"CurrentProgramSceneChanged","eventIntent":4,"eventData":{"sceneName":"MY Scene"}}
{"eventType":"CurrentProgramSceneChanged","eventIntent":4,"eventData":{"sceneName":"Scene 2"}}
```

Now pipe the result through the `jq` command for each event

```sh
# jq will parse the json
obs listen --event-subscriptions scenes | jq -r '.eventType + "\t" + .eventData.sceneName'
```

Gives this result,

```text
CurrentProgramSceneChanged	Scene 2
CurrentProgramSceneChanged	MY Scene
CurrentProgramSceneChanged	Scene 2
```

### Trigger a shell command for an OBS event

The `listen` command provides an optional `--command` argument that allows the user to specify the shell command that will be executed each time OBS fires one of the events that has been subscribed to.  The example below will send a separate email containing the JSON payload of each event fired.

```sh
# send an email for every scene event
obs listen --event-subscriptions scenes --command 'mutt -s "OBS Scene Event" address@email.com'
```

### More Examples

For additional examples including:
- Scene management workflows
- Input control scripts
- Stream and recording automation
- Filter management
- Event monitoring patterns
- Integration with Python, Bash, and other tools

See the comprehensive [example/README.md](example/README.md) documentation with real-world usage patterns and scripting examples.