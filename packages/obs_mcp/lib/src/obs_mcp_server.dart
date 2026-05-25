/// MCP facade for the OBS WebSocket client.
///
/// [ObsMcpServer] wraps [ObsWebSocket] and exposes every OBS request group
/// (`general`, `config`, `scenes`, `inputs`, `media_inputs`, `outputs`,
/// `record`, `scene_items`, `sources`, `stream`, `transitions`, `ui`) as
/// MCP tools via the `easy_api_annotations` package.
///
/// The class is annotated with
/// `@Server(transport: McpTransport.stdio)` so the generator
/// produces a stdio MCP server at `obs_mcp_server.mcp.dart`.
///
/// Because the generated dispatcher constructs a fresh [ObsMcpServer] instance
/// for every tool invocation, the live connection is kept in a static field
/// so it survives across calls. All `Future<void>` wrappers return
/// `<String, dynamic>{'ok': true}` instead — the generator serialises the
/// return value into the MCP response payload and does not compile against
/// raw `void`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:easy_api_annotations/mcp_annotations.dart';
import 'package:obs_mcp/src/animation_helpers.dart';
import 'package:obs_websocket/event.dart';
import 'package:obs_websocket/obs_websocket.dart';

/// Unified MCP facade exposing the OBS WebSocket v5.1.0 protocol as tools.
///
/// Callers invoke [connect] once (or rely on [bootstrapFromEnv] to connect
/// automatically from `OBS_WEBSOCKET_*` environment variables), then use any
/// of the grouped tools (`obs_scenes_list`, `obs_inputs_set_mute`,
/// `obs_stream_start`, etc.).
@Server(
  transport: McpTransport.stdio,
  codeMode: true,
  toolPrefix: 'obs_',
  logErrors: true,
)
class ObsMcpServer {
  /// Environment variable holding the OBS WebSocket URL, e.g.
  /// `ws://localhost:4455`.
  static const String envUrl = 'OBS_WEBSOCKET_URL';

  /// Environment variable holding the OBS WebSocket password. Leave unset
  /// for anonymous connections.
  static const String envPassword = 'OBS_WEBSOCKET_PASSWORD';

  /// Environment variable holding the connect timeout in seconds. Defaults
  /// to 120 when unset.
  static const String envTimeout = 'OBS_WEBSOCKET_TIMEOUT';

  /// Static so the connection persists across per-tool-call instances
  /// created by the generated dispatcher.
  static ObsWebSocket? _client;

  /// Stores the last bootstrap error to provide better error messages.
  static String? _bootstrapError;

  /// Canonical acknowledgement payload for tools that have no natural
  /// return value. The generator cannot serialise `void` so every mutator
  /// returns a JSON-friendly ack.
  static const Map<String, dynamic> _ok = <String, dynamic>{'ok': true};

  /// Returns the active client or throws a descriptive [StateError] when the
  /// caller forgot to invoke [connect].
  static ObsWebSocket get _obs {
    final client = _client;
    if (client == null) {
      final errorContext = _bootstrapError != null
          ? ' Last attempt failed: $_bootstrapError'
          : '';
      throw StateError(
        'Not connected to OBS. Set $envUrl (and optionally $envPassword) in '
        'the environment or a .env file, or call obs_connect(url, password).'
        '$errorContext',
      );
    }
    return client;
  }

  // ---------------------------------------------------------------------------
  // Environment bootstrap
  // ---------------------------------------------------------------------------

  /// Loads OBS credentials from the process environment and/or a dotenv
  /// file, and — when a URL is present — opens the connection so tools are
  /// immediately usable. Safe to call more than once: subsequent calls are
  /// no-ops once connected.
  ///
  /// Resolution order for each variable:
  ///   1. [Platform.environment].
  ///   2. Key-value pairs parsed from the first readable dotenv candidate
  ///      in [dotenvPaths] (defaults to `.env`, `bin/.env`, and a `.env`
  ///      sibling of the running script).
  static Future<void> bootstrapFromEnv({List<String>? dotenvPaths}) async {
    if (_client != null) return;

    final fileEnv = _loadDotenvCandidates(
      dotenvPaths ?? _defaultDotenvCandidates(),
    );
    String? lookup(String key) => Platform.environment[key] ?? fileEnv[key];

    final url = lookup(envUrl);
    if (url == null || url.isEmpty) return;

    final password = lookup(envPassword);
    final timeoutSeconds = int.tryParse(lookup(envTimeout) ?? '') ?? 120;

    try {
      _client = await ObsWebSocket.connect(
        url,
        password: password,
        timeout: Duration(seconds: timeoutSeconds),
        autoReconnect: true,
      );
      _bootstrapError = null; // Clear any previous error on success
    } on ObsAuthenticationException catch (error) {
      _bootstrapError = 'Authentication failed: ${error.message}';
      stderr.writeln('[obs_mcp] bootstrapFromEnv: $_bootstrapError');
    } on ObsException catch (error) {
      _bootstrapError = 'Connect failed: ${error.message}';
      stderr.writeln('[obs_mcp] bootstrapFromEnv: $_bootstrapError');
    } on Object catch (error) {
      // Surface the failure on stderr so MCP hosts can see it, but don't
      // abort startup — callers can still invoke obs_connect() manually.
      _bootstrapError = 'Connect failed: $error';
      stderr.writeln('[obs_mcp] bootstrapFromEnv: $_bootstrapError');
    }
  }

  /// Default dotenv search paths. Relative entries are resolved against the
  /// current working directory; an additional candidate sits next to the
  /// running script so launching from any cwd still finds `bin/.env`.
  static List<String> _defaultDotenvCandidates() {
    final candidates = <String>['.env', 'bin/.env'];
    try {
      final scriptDir = File.fromUri(Platform.script).parent.path;
      candidates.add('$scriptDir/.env');
    } on Object catch (_) {
      // Platform.script may not resolve to a file (e.g. under tests).
    }
    return candidates;
  }

  /// Reads the first existing file from [paths] and returns its parsed
  /// contents. Returns an empty map when no file is found.
  static Map<String, String> _loadDotenvCandidates(Iterable<String> paths) {
    for (final path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        return _parseDotenv(file.readAsStringSync());
      }
    }
    return const <String, String>{};
  }

  /// Minimal dependency-free dotenv parser. Supports `KEY=VALUE`,
  /// `#` comments, blank lines, `export KEY=VALUE`, and single/double-quoted
  /// values. Values are trimmed of surrounding whitespace.
  static Map<String, String> _parseDotenv(String contents) {
    final result = <String, String>{};
    for (final rawLine in const LineSplitter().convert(contents)) {
      var line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('export ')) line = line.substring(7).trimLeft();
      final eq = line.indexOf('=');
      if (eq <= 0) continue;
      final key = line.substring(0, eq).trim();
      var value = line.substring(eq + 1).trim();
      var wasQuoted = false;
      if (value.length >= 2) {
        final first = value[0];
        final last = value[value.length - 1];
        if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
          value = value.substring(1, value.length - 1);
          wasQuoted = true;
        }
      }
      // Strip trailing inline comments for unquoted values only.
      if (!wasQuoted) {
        final hashIdx = value.indexOf(' #');
        if (hashIdx >= 0) value = value.substring(0, hashIdx).trimRight();
      }
      result[key] = value;
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Connection lifecycle
  // ---------------------------------------------------------------------------

  /// Opens a WebSocket connection to OBS Studio and completes the v5.1.0
  /// identify handshake. Reuses the single in-process connection until
  /// [disconnect] is called.
  @Tool(
    name: 'connect',
    description:
        'Connect to an OBS WebSocket server (ws:// or wss://) and '
        'authenticate. Required before any other tool can be invoked.',
  )
  Future<Map<String, dynamic>> connect({
    @Parameter(
      title: 'OBS WebSocket URL',
      description:
          'Full URL of the OBS WebSocket server. Accepts ws://host:port or '
          'wss://host:port. Bare host:port is also accepted.',
      example: 'ws://localhost:4455',
    )
    required String url,
    @Parameter(
      title: 'Password',
      description: 'OBS WebSocket password. Omit for anonymous connections.',
      sensitive: true,
    )
    String? password,
    @Parameter(
      title: 'Connect Timeout (seconds)',
      description: 'How long to wait for the TCP/WebSocket handshake.',
      example: 120,
    )
    int? timeoutSeconds,
    @Parameter(
      title: 'Auto Reconnect',
      description:
          'Automatically reconnect with exponential backoff if the OBS '
          'WebSocket drops (default true).',
    )
    bool? autoReconnect,
  }) async {
    await _client?.close();
    _client = await ObsWebSocket.connect(
      url,
      password: password,
      timeout: Duration(seconds: timeoutSeconds ?? 120),
      autoReconnect: autoReconnect ?? true,
    );
    return <String, dynamic>{
      'connected': true,
      'negotiatedRpcVersion': _obs.negotiatedRpcVersion,
      'autoReconnect': autoReconnect ?? true,
    };
  }

  /// Closes the active OBS WebSocket connection.
  @Tool(
    name: 'disconnect',
    description: 'Close the active OBS WebSocket connection.',
  )
  Future<Map<String, dynamic>> disconnect() async {
    await _client?.close();
    _client = null;
    return <String, dynamic>{'connected': false};
  }

  /// Reports whether a connection is currently established.
  @Tool(
    name: 'is_connected',
    description: 'Return whether a live OBS WebSocket connection is held.',
  )
  bool isConnected() => _client != null;

  /// Low-level request escape hatch for any OBS request type that does not
  /// have a dedicated tool wrapper here.
  @Tool(
    name: 'send_raw',
    description:
        'Send a raw OBS WebSocket request (requestType + optional data map) '
        'and return the response payload. Use this for requests that are not '
        'exposed directly as tools.',
  )
  Future<Map<String, dynamic>?> sendRaw({
    @Parameter(
      title: 'Request Type',
      description:
          'OBS request name, e.g. GetVersion or SetCurrentProgramScene.',
      example: 'GetVersion',
    )
    required String requestType,
    @Parameter(
      title: 'Request Data',
      description:
          'Optional JSON object of parameters accepted by the request type.',
    )
    Map<String, dynamic>? requestData,
  }) async {
    final response = await _obs.send(requestType, requestData);
    return response?.responseData;
  }

  // ---------------------------------------------------------------------------
  // General
  // ---------------------------------------------------------------------------

  /// Returns OBS and obs-websocket plugin version strings.
  @Tool(
    name: 'general_version',
    description: 'Return OBS Studio + obs-websocket version information.',
  )
  Future<Map<String, dynamic>> generalVersion() async =>
      (await _obs.general.getVersion()).toJson();

  /// Returns CPU, memory, frame-rate and render statistics.
  @Tool(
    name: 'general_stats',
    description: 'Return OBS runtime statistics (cpu, memory, frame rate).',
  )
  Future<Map<String, dynamic>> generalStats() async =>
      (await _obs.general.getStats()).toJson();

  /// Lists the names of all registered hotkeys.
  @Tool(
    name: 'general_hotkeys',
    description: 'Return the names of every registered hotkey in OBS.',
  )
  Future<List<String>> generalHotkeys() => _obs.general.getHotkeyList();

  /// Triggers a hotkey by its registered name.
  @Tool(
    name: 'general_trigger_hotkey',
    description: 'Trigger a hotkey by its registered name.',
  )
  Future<Map<String, dynamic>> generalTriggerHotkey(
    @Parameter(title: 'Hotkey Name', example: 'OBSBasic.StartStreaming')
    String hotkeyName,
  ) async {
    await _obs.general.triggerHotkeyByName(hotkeyName);
    return _ok;
  }

  /// Pauses the request pipeline for a period. Useful for orchestration
  /// scripts in code mode.
  @Tool(
    name: 'general_sleep',
    description:
        'Sleep for a duration in milliseconds or frames (executed server-side).',
  )
  Future<Map<String, dynamic>> generalSleep({
    @Parameter(
      title: 'Sleep Milliseconds',
      description: 'Wait time in milliseconds. Exclusive with sleepFrames.',
    )
    int? sleepMillis,
    @Parameter(
      title: 'Sleep Frames',
      description: 'Wait time in frames. Exclusive with sleepMillis.',
    )
    int? sleepFrames,
  }) async {
    await _obs.general.sleep(
      sleepMillis: sleepMillis,
      sleepFrames: sleepFrames,
    );
    return _ok;
  }

  /// Broadcasts a vendor-specific event payload over the websocket.
  @Tool(
    name: 'general_broadcast_custom_event',
    description: 'Broadcast a custom JSON event to all connected clients.',
  )
  Future<Map<String, dynamic>> generalBroadcastCustomEvent(
    Map<String, dynamic> eventData,
  ) async {
    await _obs.general.broadcastCustomEvent(eventData);
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // Scenes
  // ---------------------------------------------------------------------------

  /// Returns the list of scenes along with the current program/preview scene.
  @Tool(
    name: 'scenes_list',
    description:
        'Return all scenes plus the current program and preview scene.',
  )
  Future<Map<String, dynamic>> scenesList() async =>
      (await _obs.scenes.list()).toJson();

  /// Returns the names of all defined groups.
  @Tool(
    name: 'scenes_group_list',
    description: 'Return the names of all groups in OBS.',
  )
  Future<List<String>> scenesGroupList() => _obs.scenes.groupList();

  /// Returns the name of the scene currently on program output.
  @Tool(
    name: 'scenes_get_current_program',
    description: 'Return the name of the scene currently on the program bus.',
  )
  Future<String> scenesGetCurrentProgram() => _obs.scenes.getCurrentProgram();

  /// Switches the program scene.
  @Tool(
    name: 'scenes_set_current_program',
    description: 'Set the program scene to the given sceneName.',
  )
  Future<Map<String, dynamic>> scenesSetCurrentProgram(
    @Parameter(title: 'Scene Name', example: 'Starting Soon') String sceneName,
  ) async {
    await _obs.scenes.setCurrentProgram(sceneName);
    return _ok;
  }

  /// Returns the name of the scene currently shown in preview
  /// (studio mode only).
  @Tool(
    name: 'scenes_get_current_preview',
    description:
        'Return the name of the preview scene (studio mode only). Throws if '
        'studio mode is disabled.',
  )
  Future<String> scenesGetCurrentPreview() => _obs.scenes.getCurrentPreview();

  /// Switches the preview scene (studio mode only).
  @Tool(
    name: 'scenes_set_current_preview',
    description: 'Set the preview scene (studio mode only).',
  )
  Future<Map<String, dynamic>> scenesSetCurrentPreview(String sceneName) async {
    await _obs.scenes.setCurrentPreview(sceneName);
    return _ok;
  }

  /// Creates a new scene.
  @Tool(
    name: 'scenes_create',
    description: 'Create a new scene with the given name.',
  )
  Future<Map<String, dynamic>> scenesCreate(
    @Parameter(title: 'Scene Name') String sceneName,
  ) async {
    await _obs.scenes.create(sceneName);
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // Scene Items
  // ---------------------------------------------------------------------------

  /// Returns the scene items in a given scene (sources placed on the canvas).
  @Tool(
    name: 'scene_items_list',
    description: 'List the scene items (sources) contained in a scene.',
  )
  Future<List<Map<String, dynamic>>> sceneItemsList(String sceneName) async {
    final items = await _obs.sceneItems.list(sceneName);
    return items.map((e) => e.toJson()).toList();
  }

  /// Returns scene items inside a group.
  @Tool(
    name: 'scene_items_group_list',
    description: 'List the scene items contained in a group.',
  )
  Future<List<Map<String, dynamic>>> sceneItemsGroupList(
    String sceneName,
  ) async {
    final items = await _obs.sceneItems.groupList(sceneName);
    return items.map((e) => e.toJson()).toList();
  }

  /// Returns the numeric id for a scene item by its source name.
  @Tool(
    name: 'scene_items_get_id',
    description:
        'Return the numeric sceneItemId for a source placed in a given scene.',
  )
  Future<int> sceneItemsGetId({
    required String sceneName,
    required String sourceName,
  }) => _obs.sceneItems.getSceneItemId(
    sceneName: sceneName,
    sourceName: sourceName,
  );

  /// Returns whether a scene item is visible/enabled.
  @Tool(
    name: 'scene_items_get_enabled',
    description: 'Return whether a scene item is currently enabled (visible).',
  )
  Future<bool> sceneItemsGetEnabled({
    required String sceneName,
    required int sceneItemId,
  }) => _obs.sceneItems.getSceneItemEnabled(
    sceneName: sceneName,
    sceneItemId: sceneItemId,
  );

  /// Shows or hides a scene item.
  @Tool(
    name: 'scene_items_set_enabled',
    description: 'Show or hide a scene item by id.',
  )
  Future<Map<String, dynamic>> sceneItemsSetEnabled({
    required String sceneName,
    required int sceneItemId,
    required bool sceneItemEnabled,
  }) async {
    await _obs.sceneItems.setSceneItemEnabled(
      SceneItemEnableStateChanged(
        sceneName: sceneName,
        sceneItemId: sceneItemId,
        sceneItemEnabled: sceneItemEnabled,
      ),
    );
    return _ok;
  }

  /// Returns whether a scene item is locked.
  @Tool(
    name: 'scene_items_get_locked',
    description: 'Return whether a scene item is locked (uneditable).',
  )
  Future<bool> sceneItemsGetLocked({
    required String sceneName,
    required int sceneItemId,
  }) => _obs.sceneItems.getSceneItemLocked(
    sceneName: sceneName,
    sceneItemId: sceneItemId,
  );

  /// Locks or unlocks a scene item.
  @Tool(
    name: 'scene_items_set_locked',
    description: 'Lock or unlock a scene item by id.',
  )
  Future<Map<String, dynamic>> sceneItemsSetLocked({
    required String sceneName,
    required int sceneItemId,
    required bool sceneItemLocked,
  }) async {
    await _obs.sceneItems.setSceneItemLocked(
      sceneName: sceneName,
      sceneItemId: sceneItemId,
      sceneItemLocked: sceneItemLocked,
    );
    return _ok;
  }

  /// Sets the transform (position, scale, rotation, crop, alignment, bounds)
  /// for a scene item. Every field is optional — only the supplied fields are
  /// forwarded to OBS.
  @Tool(
    name: 'scene_items_set_transform',
    description:
        'Set the transform properties (position, scale, rotation, crop, '
        'alignment, bounds) for a scene item. Only provide the fields you want '
        'to change. Returns the new transform as a flat object.',
  )
  Future<Map<String, dynamic>> sceneItemsSetTransform({
    @Parameter(title: 'Scene Name', example: 'Scene') required String sceneName,
    @Parameter(title: 'Scene Item ID', example: 4) required int sceneItemId,
    @Parameter(
      title: 'Position X',
      description: 'Horizontal position in pixels.',
    )
    num? positionX,
    @Parameter(title: 'Position Y', description: 'Vertical position in pixels.')
    num? positionY,
    @Parameter(
      title: 'Scale X',
      description: 'Horizontal scale factor (1.0 = 100%).',
    )
    num? scaleX,
    @Parameter(
      title: 'Scale Y',
      description: 'Vertical scale factor (1.0 = 100%).',
    )
    num? scaleY,
    @Parameter(title: 'Rotation', description: 'Rotation in degrees clockwise.')
    num? rotation,
    @Parameter(
      title: 'Crop Left',
      description: 'Pixels to crop from the left edge.',
    )
    int? cropLeft,
    @Parameter(
      title: 'Crop Top',
      description: 'Pixels to crop from the top edge.',
    )
    int? cropTop,
    @Parameter(
      title: 'Crop Right',
      description: 'Pixels to crop from the right edge.',
    )
    int? cropRight,
    @Parameter(
      title: 'Crop Bottom',
      description: 'Pixels to crop from the bottom edge.',
    )
    int? cropBottom,
    @Parameter(
      title: 'Alignment',
      description:
          'OBS alignment bit-flag. 0=center, 1=left, 2=right, 4=top, '
          '5=topLeft, 6=topRight, 8=bottom, 9=bottomLeft, 10=bottomRight.',
      example: 5,
    )
    int? alignment,
    @Parameter(
      title: 'Bounds Type',
      description:
          'OBS bounds type protocol string. One of: OBS_BOUNDS_NONE, '
          'OBS_BOUNDS_STRETCH, OBS_BOUNDS_SCALE_INNER, OBS_BOUNDS_SCALE_OUTER, '
          'OBS_BOUNDS_SCALE_TO_WIDTH, OBS_BOUNDS_SCALE_TO_HEIGHT, '
          'OBS_BOUNDS_MAX_ONLY.',
      example: 'OBS_BOUNDS_NONE',
    )
    String? boundsType,
    @Parameter(
      title: 'Bounds Alignment',
      description: 'Alignment of the source within its bounding box.',
    )
    int? boundsAlignment,
    @Parameter(
      title: 'Bounds Width',
      description: 'Width of the bounding box in pixels.',
    )
    num? boundsWidth,
    @Parameter(
      title: 'Bounds Height',
      description: 'Height of the bounding box in pixels.',
    )
    num? boundsHeight,
  }) async {
    final transform = SceneItemTransform(
      positionX: positionX?.toDouble(),
      positionY: positionY?.toDouble(),
      scaleX: scaleX?.toDouble(),
      scaleY: scaleY?.toDouble(),
      rotation: rotation?.toDouble(),
      cropLeft: cropLeft,
      cropTop: cropTop,
      cropRight: cropRight,
      cropBottom: cropBottom,
      alignment: alignment,
      boundsAlignment: boundsAlignment,
      boundsType: boundsType,
      boundsWidth: boundsWidth?.toDouble(),
      boundsHeight: boundsHeight?.toDouble(),
    );

    await _obs.sceneItems.setSceneItemTransformTyped(
      sceneName: sceneName,
      sceneItemId: sceneItemId,
      transform: transform,
    );

    // Re-read so the agent gets the canonical, flattened result.
    final updated = await _obs.sceneItems.getSceneItemTransformTyped(
      sceneName: sceneName,
      sceneItemId: sceneItemId,
    );
    return updated.toJson();
  }

  // ---------------------------------------------------------------------------
  // Inputs
  // ---------------------------------------------------------------------------

  /// Lists all inputs, optionally filtered by input kind.
  @Tool(
    name: 'inputs_list',
    description:
        'List all inputs in OBS. Provide inputKind to filter to a single kind.',
  )
  Future<List<Map<String, dynamic>>> inputsList({String? inputKind}) async {
    final inputs = await _obs.inputs.getInputList(inputKind);
    return inputs.map((e) => e.toJson()).toList();
  }

  /// Lists the available input kinds on the OBS instance.
  @Tool(
    name: 'inputs_kind_list',
    description: 'Return the list of available input kinds on this OBS.',
  )
  Future<List<String>> inputsKindList({bool? unversioned}) =>
      _obs.inputs.getInputKindList(unversioned ?? false);

  /// Returns the names of the "special" inputs (mic/aux).
  @Tool(
    name: 'inputs_special',
    description: 'Return the names of OBS special inputs (mic/aux/etc.).',
  )
  Future<Map<String, dynamic>> inputsSpecial() async =>
      (await _obs.inputs.getSpecialInputs()).toJson();

  /// Returns whether an input is muted.
  @Tool(
    name: 'inputs_get_mute',
    description: 'Return whether an input is currently muted.',
  )
  Future<bool> inputsGetMute(String inputName) =>
      _obs.inputs.getInputMute(inputName);

  /// Sets the mute state of an input.
  @Tool(
    name: 'inputs_set_mute',
    description: 'Mute or unmute an input (by name or uuid).',
  )
  Future<Map<String, dynamic>> inputsSetMute({
    String? inputName,
    String? inputUuid,
    required bool inputMuted,
  }) async {
    await _obs.inputs.setInputMute(
      inputName: inputName,
      inputUuid: inputUuid,
      inputMuted: inputMuted,
    );
    return _ok;
  }

  /// Toggles the mute state of an input and returns the new value.
  @Tool(
    name: 'inputs_toggle_mute',
    description: 'Toggle mute on an input and return the new muted state.',
  )
  Future<bool> inputsToggleMute({String? inputName, String? inputUuid}) =>
      _obs.inputs.toggleInputMute(inputName: inputName, inputUuid: inputUuid);

  /// Returns volume (mul + dB) for an input.
  @Tool(
    name: 'inputs_get_volume',
    description: 'Return the volume of an input as both multiplier and dB.',
  )
  Future<Map<String, dynamic>> inputsGetVolume({
    String? inputName,
    String? inputUuid,
  }) async {
    final response = await _obs.inputs.getInputVolume(
      inputName: inputName,
      inputUuid: inputUuid,
    );
    return response.toJson();
  }

  /// Returns the current settings JSON for an input.
  @Tool(
    name: 'inputs_get_settings',
    description: 'Return the current settings payload for an input.',
  )
  Future<Map<String, dynamic>> inputsGetSettings({
    String? inputName,
    String? inputUuid,
  }) async {
    final response = await _obs.inputs.getInputSettings(
      inputName: inputName,
      inputUuid: inputUuid,
    );
    return response.toJson();
  }

  /// Overwrites the settings JSON for an input.
  @Tool(
    name: 'inputs_set_settings',
    description: 'Overwrite or merge an input settings payload.',
  )
  Future<Map<String, dynamic>> inputsSetSettings({
    String? inputName,
    String? inputUuid,
    required Map<String, dynamic> inputSettings,
    bool? overlay,
  }) async {
    await _obs.inputs.setInputSettings(
      inputName: inputName,
      inputUuid: inputUuid,
      inputSettings: inputSettings,
      overlay: overlay ?? true,
    );
    return _ok;
  }

  /// Renames an input.
  @Tool(name: 'inputs_set_name', description: 'Rename an input.')
  Future<Map<String, dynamic>> inputsSetName({
    String? inputName,
    String? inputUuid,
    required String newInputName,
  }) async {
    await _obs.inputs.setInputName(
      inputName: inputName,
      inputUuid: inputUuid,
      newInputName: newInputName,
    );
    return _ok;
  }

  /// Creates an input inside a scene.
  @Tool(
    name: 'inputs_create',
    description: 'Create a new input as a scene item inside a scene.',
  )
  Future<Map<String, dynamic>> inputsCreate({
    String? sceneName,
    String? sceneUuid,
    required String inputName,
    required String inputKind,
    Map<String, dynamic>? inputSettings,
    bool? sceneItemEnabled,
  }) async {
    final response = await _obs.inputs.createInput(
      sceneName: sceneName,
      sceneUuid: sceneUuid,
      inputName: inputName,
      inputKind: inputKind,
      inputSettings: inputSettings,
      sceneItemEnabled: sceneItemEnabled,
    );
    return response.toJson();
  }

  /// Removes an input.
  @Tool(name: 'inputs_remove', description: 'Delete an input by name or uuid.')
  Future<Map<String, dynamic>> inputsRemove({
    String? inputName,
    String? inputUuid,
  }) async {
    await _obs.inputs.removeInput(inputName: inputName, inputUuid: inputUuid);
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // Stream
  // ---------------------------------------------------------------------------

  /// Returns the live streaming status (active / reconnecting / bytes).
  @Tool(
    name: 'stream_status',
    description: 'Return the current streaming status.',
  )
  Future<Map<String, dynamic>> streamStatus() async =>
      (await _obs.stream.getStreamStatus()).toJson();

  /// Starts streaming.
  @Tool(name: 'stream_start', description: 'Start the active streaming output.')
  Future<Map<String, dynamic>> streamStart() async {
    await _obs.stream.start();
    return _ok;
  }

  /// Stops streaming.
  @Tool(name: 'stream_stop', description: 'Stop the active streaming output.')
  Future<Map<String, dynamic>> streamStop() async {
    await _obs.stream.stop();
    return _ok;
  }

  /// Toggles streaming and returns the new active state.
  @Tool(
    name: 'stream_toggle',
    description: 'Toggle streaming. Returns the resulting active state.',
  )
  Future<bool> streamToggle() => _obs.stream.toggle();

  /// Sends a caption to the live stream (requires caption-capable output).
  @Tool(
    name: 'stream_send_caption',
    description: 'Send a caption line to the active stream.',
  )
  Future<Map<String, dynamic>> streamSendCaption(String captionText) async {
    await _obs.stream.sendStreamCaption(captionText);
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // Record
  // ---------------------------------------------------------------------------

  /// Returns recording status (active / paused / duration / bytes).
  @Tool(
    name: 'record_status',
    description: 'Return the current recording status.',
  )
  Future<Map<String, dynamic>> recordStatus() async =>
      (await _obs.record.getRecordStatus()).toJson();

  /// Starts recording.
  @Tool(name: 'record_start', description: 'Start a new recording.')
  Future<Map<String, dynamic>> recordStart() async {
    await _obs.record.start();
    return _ok;
  }

  /// Stops recording and returns the output file path.
  @Tool(
    name: 'record_stop',
    description:
        'Stop the current recording and return the resulting file path.',
  )
  Future<String> recordStop() => _obs.record.stop();

  /// Toggles recording.
  @Tool(name: 'record_toggle', description: 'Toggle recording on/off.')
  Future<Map<String, dynamic>> recordToggle() async {
    await _obs.record.toggle();
    return _ok;
  }

  /// Pauses a recording in progress.
  @Tool(name: 'record_pause', description: 'Pause the active recording.')
  Future<Map<String, dynamic>> recordPause() async {
    await _obs.record.pause();
    return _ok;
  }

  /// Resumes a paused recording.
  @Tool(name: 'record_resume', description: 'Resume a paused recording.')
  Future<Map<String, dynamic>> recordResume() async {
    await _obs.record.resume();
    return _ok;
  }

  /// Toggles pause state on a recording.
  @Tool(
    name: 'record_toggle_pause',
    description: 'Toggle pause state of the active recording.',
  )
  Future<Map<String, dynamic>> recordTogglePause() async {
    await _obs.record.togglePause();
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // Outputs (virtual cam, replay buffer, arbitrary outputs)
  // ---------------------------------------------------------------------------

  /// Returns whether the virtual camera output is active.
  @Tool(
    name: 'outputs_virtual_cam_status',
    description: 'Return whether the virtual camera output is active.',
  )
  Future<bool> outputsVirtualCamStatus() => _obs.outputs.getVirtualCamStatus();

  /// Toggles the virtual camera and returns the new state.
  @Tool(
    name: 'outputs_virtual_cam_toggle',
    description: 'Toggle the virtual camera output. Returns new state.',
  )
  Future<bool> outputsVirtualCamToggle() => _obs.outputs.toggleVirtualCam();

  /// Starts the virtual camera output.
  @Tool(
    name: 'outputs_virtual_cam_start',
    description: 'Start the virtual camera output.',
  )
  Future<Map<String, dynamic>> outputsVirtualCamStart() async {
    await _obs.outputs.startVirtualCam();
    return _ok;
  }

  /// Stops the virtual camera output.
  @Tool(
    name: 'outputs_virtual_cam_stop',
    description: 'Stop the virtual camera output.',
  )
  Future<Map<String, dynamic>> outputsVirtualCamStop() async {
    await _obs.outputs.stopVirtualCam();
    return _ok;
  }

  /// Returns whether the replay buffer is active.
  @Tool(
    name: 'outputs_replay_buffer_status',
    description: 'Return whether the replay buffer is currently active.',
  )
  Future<bool> outputsReplayBufferStatus() =>
      _obs.outputs.getReplayBufferStatus();

  /// Toggles the replay buffer.
  @Tool(
    name: 'outputs_replay_buffer_toggle',
    description: 'Toggle the replay buffer. Returns the new active state.',
  )
  Future<bool> outputsReplayBufferToggle() => _obs.outputs.toggleReplayBuffer();

  /// Starts the replay buffer.
  @Tool(
    name: 'outputs_replay_buffer_start',
    description: 'Start the replay buffer.',
  )
  Future<Map<String, dynamic>> outputsReplayBufferStart({
    String? outputName,
  }) async {
    await _obs.outputs.startReplayBuffer(outputName ?? '');
    return _ok;
  }

  /// Stops the replay buffer.
  @Tool(
    name: 'outputs_replay_buffer_stop',
    description: 'Stop the replay buffer.',
  )
  Future<Map<String, dynamic>> outputsReplayBufferStop({
    String? outputName,
  }) async {
    await _obs.outputs.stopReplayBuffer(outputName ?? '');
    return _ok;
  }

  /// Saves the contents of the replay buffer to disk.
  @Tool(
    name: 'outputs_replay_buffer_save',
    description: 'Flush the replay buffer contents to a replay file.',
  )
  Future<Map<String, dynamic>> outputsReplayBufferSave({
    String? outputName,
  }) async {
    await _obs.outputs.saveReplayBuffer(outputName ?? '');
    return _ok;
  }

  /// Toggles a named output and returns the new state.
  @Tool(
    name: 'outputs_toggle',
    description: 'Toggle a named OBS output. Returns the new active state.',
  )
  Future<bool> outputsToggle(String outputName) =>
      _obs.outputs.toggleOutput(outputName);

  /// Starts a named output.
  @Tool(name: 'outputs_start', description: 'Start a named OBS output.')
  Future<Map<String, dynamic>> outputsStart(String outputName) async {
    await _obs.outputs.start(outputName);
    return _ok;
  }

  /// Stops a named output.
  @Tool(name: 'outputs_stop', description: 'Stop a named OBS output.')
  Future<Map<String, dynamic>> outputsStop(String outputName) async {
    await _obs.outputs.stop(outputName);
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // Config
  // ---------------------------------------------------------------------------

  /// Returns the currently configured recording directory.
  @Tool(
    name: 'config_record_directory',
    description: 'Return the current recording directory.',
  )
  Future<String> configRecordDirectory() async =>
      (await _obs.config.getRecordDirectory()).recordDirectory;

  /// Returns the active streaming service name + settings.
  @Tool(
    name: 'config_stream_service_settings',
    description: 'Return the active streaming service name + settings.',
  )
  Future<Map<String, dynamic>> configStreamServiceSettings() async =>
      (await _obs.config.getStreamServiceSettings()).toJson();

  // ---------------------------------------------------------------------------
  // UI / Studio Mode
  // ---------------------------------------------------------------------------

  /// Returns whether studio mode is enabled.
  @Tool(
    name: 'ui_studio_mode_enabled',
    description: 'Return whether OBS studio mode is currently enabled.',
  )
  Future<bool> uiStudioModeEnabled() => _obs.ui.getStudioModeEnabled();

  /// Enables or disables studio mode.
  @Tool(
    name: 'ui_set_studio_mode',
    description: 'Enable or disable OBS studio mode.',
  )
  Future<Map<String, dynamic>> uiSetStudioMode(bool enabled) async {
    await _obs.ui.setStudioModeEnabled(enabled);
    return _ok;
  }

  /// Opens the properties dialog for the given input.
  @Tool(
    name: 'ui_open_input_properties',
    description:
        'Open the properties dialog window in the OBS UI for the given input.',
  )
  Future<Map<String, dynamic>> uiOpenInputProperties(String inputName) async {
    await _obs.ui.openInputPropertiesDialog(inputName);
    return _ok;
  }

  /// Opens the filters dialog for the given input.
  @Tool(
    name: 'ui_open_input_filters',
    description: 'Open the filters dialog in the OBS UI for the given input.',
  )
  Future<Map<String, dynamic>> uiOpenInputFilters(String inputName) async {
    await _obs.ui.openInputFiltersDialog(inputName);
    return _ok;
  }

  /// Opens the interact window for the given input (browser sources etc.).
  @Tool(
    name: 'ui_open_input_interact',
    description: 'Open the interact dialog in the OBS UI for the given input.',
  )
  Future<Map<String, dynamic>> uiOpenInputInteract(String inputName) async {
    await _obs.ui.openInputInteractDialog(inputName);
    return _ok;
  }

  /// Returns the list of monitors that can host a projector.
  @Tool(
    name: 'ui_monitor_list',
    description: 'Return the list of connected monitors.',
  )
  Future<List<Map<String, dynamic>>> uiMonitorList() async {
    final monitors = await _obs.ui.getMonitorList();
    return monitors.map((e) => e.toJson()).toList();
  }

  // ---------------------------------------------------------------------------
  // Transitions
  // ---------------------------------------------------------------------------

  /// Triggers the studio-mode preview→program transition.
  @Tool(
    name: 'transitions_trigger_studio',
    description:
        'Trigger the studio-mode transition from the preview scene to program.',
  )
  Future<Map<String, dynamic>> transitionsTriggerStudio() async {
    await _obs.transitions.triggerStudioModeTransition();
    return _ok;
  }

  /// Returns the list of all available transition kinds.
  @Tool(
    name: 'transitions_kind_list',
    description: 'Return the list of all available transition kinds.',
  )
  Future<List<String>> transitionsKindList() =>
      _obs.transitions.getTransitionKindList();

  /// Returns the list of all scene transitions in OBS.
  @Tool(
    name: 'transitions_scene_list',
    description: 'Return the list of all scene transitions configured in OBS.',
  )
  Future<Map<String, dynamic>> transitionsSceneList() async =>
      await _obs.transitions.getSceneTransitionList();

  /// Returns information about the current scene transition.
  @Tool(
    name: 'transitions_get_current',
    description: 'Return information about the current scene transition.',
  )
  Future<Map<String, dynamic>> transitionsGetCurrent() async =>
      await _obs.transitions.getCurrentSceneTransition();

  /// Sets the current scene transition.
  @Tool(
    name: 'transitions_set_current',
    description: 'Set the current scene transition by name.',
  )
  Future<Map<String, dynamic>> transitionsSetCurrent(
    @Parameter(title: 'Transition Name', example: 'Fade') String transitionName,
  ) async {
    await _obs.transitions.setCurrentSceneTransition(transitionName);
    return _ok;
  }

  /// Sets the duration of the current scene transition.
  @Tool(
    name: 'transitions_set_duration',
    description:
        'Set the duration of the current scene transition in milliseconds (50-20000).',
  )
  Future<Map<String, dynamic>> transitionsSetDuration(
    @Parameter(title: 'Duration (ms)', example: 300) int duration,
  ) async {
    await _obs.transitions.setCurrentSceneTransitionDuration(duration);
    return _ok;
  }

  /// Sets the settings of the current scene transition.
  @Tool(
    name: 'transitions_set_settings',
    description: 'Set the settings of the current scene transition.',
  )
  Future<Map<String, dynamic>> transitionsSetSettings({
    @Parameter(title: 'Transition Settings')
    required Map<String, dynamic> transitionSettings,
    @Parameter(title: 'Overlay', description: 'Merge with existing settings.')
    bool? overlay,
  }) async {
    await _obs.transitions.setCurrentSceneTransitionSettings(
      transitionSettings: transitionSettings,
      overlay: overlay,
    );
    return _ok;
  }

  /// Returns the cursor position of the current scene transition.
  @Tool(
    name: 'transitions_get_cursor',
    description:
        'Return the cursor position (0.0-1.0) of the current scene transition.',
  )
  Future<double> transitionsGetCursor() async =>
      await _obs.transitions.getCurrentSceneTransitionCursor();

  /// Sets the position of the T-Bar (transition slider).
  @Tool(
    name: 'transitions_set_tbar',
    description:
        'Set the T-Bar position (0.0-1.0). Requires Studio Mode to be enabled.',
  )
  Future<Map<String, dynamic>> transitionsSetTBar({
    @Parameter(
      title: 'Position',
      description: 'Position between 0.0 and 1.0.',
      example: 0.5,
    )
    required double position,
    @Parameter(
      title: 'Release',
      description: 'Whether to release the T-Bar after setting.',
    )
    bool? release,
  }) async {
    await _obs.transitions.setTBarPosition(
      position: position,
      release: release,
    );
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // Sources (New - Comprehensive coverage)
  // ---------------------------------------------------------------------------

  /// Gets the active and show state of a source.
  @Tool(
    name: 'sources_get_active',
    description:
        'Return whether a source is active (shown in preview/program) and visible.',
  )
  Future<Map<String, dynamic>> sourcesGetActive(
    @Parameter(title: 'Source Name', example: 'Video Capture Device')
    String sourceName,
  ) async {
    final response = await _obs.sources.active(sourceName);
    return response.toJson();
  }

  /// Gets a Base64-encoded screenshot of a source.
  @Tool(
    name: 'sources_get_screenshot',
    description:
        'Get a Base64-encoded screenshot of a source. Returns image data as Base64 string.',
  )
  Future<Map<String, dynamic>> sourcesGetScreenshot({
    @Parameter(title: 'Source Name') required String sourceName,
    @Parameter(
      title: 'Image Format',
      description: 'Image format (png, jpg, jpeg, bmp, webp).',
      example: 'png',
    )
    required String imageFormat,
    @Parameter(
      title: 'Image Width',
      description: 'Width to scale to (keeps aspect ratio).',
    )
    int? imageWidth,
    @Parameter(
      title: 'Image Height',
      description: 'Height to scale to (keeps aspect ratio).',
    )
    int? imageHeight,
    @Parameter(
      title: 'Compression Quality',
      description: 'Compression quality (1-100, only for jpg/jpeg).',
    )
    int? compressionQuality,
  }) async {
    final screenshot = SourceScreenshot(
      sourceName: sourceName,
      imageFormat: imageFormat,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      imageCompressionQuality: compressionQuality,
    );
    final response = await _obs.sources.screenshot(screenshot);
    return response.toJson();
  }

  /// Saves a screenshot of a source to the filesystem.
  @Tool(
    name: 'sources_save_screenshot',
    description:
        'Save a screenshot of a source to a file path on the filesystem.',
  )
  Future<Map<String, dynamic>> sourcesSaveScreenshot({
    @Parameter(title: 'Source Name') required String sourceName,
    @Parameter(title: 'File Path') required String filePath,
    @Parameter(
      title: 'Image Format',
      description: 'Image format (png, jpg, jpeg, bmp, webp).',
      example: 'png',
    )
    required String imageFormat,
    @Parameter(
      title: 'Image Width',
      description: 'Width to scale to (keeps aspect ratio).',
    )
    int? imageWidth,
    @Parameter(
      title: 'Image Height',
      description: 'Height to scale to (keeps aspect ratio).',
    )
    int? imageHeight,
    @Parameter(
      title: 'Compression Quality',
      description: 'Compression quality (1-100, only for jpg/jpeg).',
    )
    int? compressionQuality,
  }) async {
    final screenshot = SourceScreenshot(
      sourceName: sourceName,
      imageFormat: imageFormat,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      imageCompressionQuality: compressionQuality,
    );
    final response = await _obs.sources.saveScreenshot(screenshot);
    return response.toJson();
  }

  /// Gets the private settings of a source.
  @Tool(
    name: 'sources_get_private_settings',
    description:
        'Return the private settings of a source (e.g., global audio devices).',
  )
  Future<Map<String, dynamic>> sourcesGetPrivateSettings({
    @Parameter(title: 'Source Name') String? sourceName,
    @Parameter(title: 'Source UUID') String? sourceUuid,
  }) async {
    final response = await _obs.sources.getSourcePrivateSettings(
      sourceName: sourceName,
      sourceUuid: sourceUuid,
    );
    return response;
  }

  /// Sets the private settings of a source.
  @Tool(
    name: 'sources_set_private_settings',
    description:
        'Set the private settings of a source (e.g., global audio devices).',
  )
  Future<Map<String, dynamic>> sourcesSetPrivateSettings({
    @Parameter(title: 'Source Name') String? sourceName,
    @Parameter(title: 'Source UUID') String? sourceUuid,
    @Parameter(title: 'Source Settings')
    required Map<String, dynamic> sourceSettings,
  }) async {
    await _obs.sources.setSourcePrivateSettings(
      sourceName: sourceName,
      sourceUuid: sourceUuid,
      sourceSettings: sourceSettings,
    );
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // Media Inputs (New - Full media control)
  // ---------------------------------------------------------------------------

  /// Gets the status of a media input (playing, paused, stopped, etc.).
  @Tool(
    name: 'media_inputs_get_status',
    description:
        'Return the status of a media input (state, duration, cursor, etc.).',
  )
  Future<Map<String, dynamic>> mediaInputsGetStatus({
    @Parameter(title: 'Input Name') String? inputName,
    @Parameter(title: 'Input UUID') String? inputUuid,
  }) async {
    final response = await _obs.mediaInputs.getMediaInputStatus(
      inputName: inputName,
      inputUuid: inputUuid,
    );
    return response.toJson();
  }

  /// Sets the cursor position of a media input.
  @Tool(
    name: 'media_inputs_set_cursor',
    description: 'Set the cursor position (in milliseconds) of a media input.',
  )
  Future<Map<String, dynamic>> mediaInputsSetCursor({
    @Parameter(title: 'Input Name') String? inputName,
    @Parameter(title: 'Input UUID') String? inputUuid,
    @Parameter(
      title: 'Media Cursor (ms)',
      description: 'New cursor position in milliseconds.',
      example: 5000,
    )
    required int mediaCursor,
  }) async {
    await _obs.mediaInputs.setMediaInputCursor(
      inputName: inputName,
      inputUuid: inputUuid,
      mediaCursor: mediaCursor,
    );
    return _ok;
  }

  /// Offsets the current cursor position of a media input.
  @Tool(
    name: 'media_inputs_offset_cursor',
    description:
        'Offset the current cursor position of a media input by the specified value (in milliseconds).',
  )
  Future<Map<String, dynamic>> mediaInputsOffsetCursor({
    @Parameter(title: 'Input Name') String? inputName,
    @Parameter(title: 'Input UUID') String? inputUuid,
    @Parameter(
      title: 'Cursor Offset (ms)',
      description: 'Value to offset the cursor by in milliseconds.',
      example: 1000,
    )
    required int mediaCursorOffset,
  }) async {
    await _obs.mediaInputs.offsetMediaInputCursor(
      inputName: inputName,
      inputUuid: inputUuid,
      mediaCursorOffset: mediaCursorOffset,
    );
    return _ok;
  }

  /// Triggers an action on a media input (play, pause, stop, restart, next, previous).
  @Tool(
    name: 'media_inputs_trigger_action',
    description:
        'Trigger an action on a media input (play, pause, stop, restart, next, previous).',
  )
  Future<Map<String, dynamic>> mediaInputsTriggerAction({
    @Parameter(title: 'Input Name') String? inputName,
    @Parameter(title: 'Input UUID') String? inputUuid,
    @Parameter(
      title: 'Media Action',
      description:
          'Action to trigger: play, pause, stop, restart, next, previous.',
      example: 'play',
    )
    required String mediaAction,
  }) async {
    final action = _parseMediaAction(mediaAction);
    await _obs.mediaInputs.triggerMediaInputAction(
      inputName: inputName,
      inputUuid: inputUuid,
      mediaAction: action,
    );
    return _ok;
  }

  /// Parses a string media action into ObsMediaInputAction enum.
  static ObsMediaInputAction _parseMediaAction(String value) {
    return switch (value.toLowerCase()) {
      'play' => ObsMediaInputAction.play,
      'pause' => ObsMediaInputAction.pause,
      'stop' => ObsMediaInputAction.stop,
      'restart' => ObsMediaInputAction.restart,
      'next' => ObsMediaInputAction.next,
      'previous' => ObsMediaInputAction.previous,
      _ => throw ArgumentError(
        'Invalid media action: $value. Must be one of: play, pause, stop, restart, next, previous.',
      ),
    };
  }

  // ---------------------------------------------------------------------------
  // Inputs - Deinterlace (New in OBS WebSocket v5.7.0 MCP exposure)
  // ---------------------------------------------------------------------------

  /// Gets the deinterlace mode of an input.
  @Tool(
    name: 'inputs_get_deinterlace_mode',
    description:
        'Return the deinterlace mode of an input (none, discard, retro, etc.).',
  )
  Future<Map<String, dynamic>> inputsGetDeinterlaceMode({
    String? inputName,
    String? inputUuid,
  }) async {
    final response = await _obs.inputs.getInputDeinterlaceMode(
      inputName: inputName,
      inputUuid: inputUuid,
    );
    return response.toJson();
  }

  /// Sets the deinterlace mode of an input.
  @Tool(
    name: 'inputs_set_deinterlace_mode',
    description:
        'Set the deinterlace mode of an input (none, discard, retro, etc.).',
  )
  Future<Map<String, dynamic>> inputsSetDeinterlaceMode({
    String? inputName,
    String? inputUuid,
    @Parameter(
      title: 'Deinterlace Mode',
      description:
          'Mode: none, discard, retro, discard_top_field_first, discard_bottom_field_first.',
      example: 'discard',
    )
    required String deinterlaceMode,
  }) async {
    final mode = _parseDeinterlaceMode(deinterlaceMode);
    await _obs.inputs.setInputDeinterlaceMode(
      inputName: inputName,
      inputUuid: inputUuid,
      deinterlaceMode: mode,
    );
    return _ok;
  }

  /// Parses a string deinterlace mode into ObsDeinterlaceMode enum.
  static ObsDeinterlaceMode _parseDeinterlaceMode(String value) {
    return switch (value.toLowerCase()) {
      'disable' => ObsDeinterlaceMode.disable,
      'discard' => ObsDeinterlaceMode.discard,
      'retro' => ObsDeinterlaceMode.retro,
      'blend' => ObsDeinterlaceMode.blend,
      'blend_2x' => ObsDeinterlaceMode.blend2x,
      'linear' => ObsDeinterlaceMode.linear,
      'linear_2x' => ObsDeinterlaceMode.linear2x,
      'yadif' => ObsDeinterlaceMode.yadif,
      'yadif_2x' => ObsDeinterlaceMode.yadif2x,
      _ => throw ArgumentError(
        'Invalid deinterlace mode: $value. Must be one of: disable, discard, retro, blend, blend_2x, linear, linear_2x, yadif, yadif_2x.',
      ),
    };
  }

  /// Gets the deinterlace field order of an input.
  @Tool(
    name: 'inputs_get_deinterlace_field_order',
    description: 'Return the deinterlace field order of an input.',
  )
  Future<Map<String, dynamic>> inputsGetDeinterlaceFieldOrder({
    String? inputName,
    String? inputUuid,
  }) async {
    final response = await _obs.inputs.getInputDeinterlaceFieldOrder(
      inputName: inputName,
      inputUuid: inputUuid,
    );
    return response.toJson();
  }

  /// Sets the deinterlace field order of an input.
  @Tool(
    name: 'inputs_set_deinterlace_field_order',
    description: 'Set the deinterlace field order of an input.',
  )
  Future<Map<String, dynamic>> inputsSetDeinterlaceFieldOrder({
    String? inputName,
    String? inputUuid,
    @Parameter(
      title: 'Field Order',
      description: 'Field order: top_field_first, bottom_field_first.',
      example: 'top_field_first',
    )
    required String deinterlaceFieldOrder,
  }) async {
    final order = _parseDeinterlaceFieldOrder(deinterlaceFieldOrder);
    await _obs.inputs.setInputDeinterlaceFieldOrder(
      inputName: inputName,
      inputUuid: inputUuid,
      deinterlaceFieldOrder: order,
    );
    return _ok;
  }

  /// Parses a string deinterlace field order into ObsDeinterlaceFieldOrder enum.
  static ObsDeinterlaceFieldOrder _parseDeinterlaceFieldOrder(String value) {
    return switch (value.toLowerCase()) {
      'top' => ObsDeinterlaceFieldOrder.top,
      'bottom' => ObsDeinterlaceFieldOrder.bottom,
      _ => throw ArgumentError(
        'Invalid field order: $value. Must be one of: top, bottom.',
      ),
    };
  }

  // ---------------------------------------------------------------------------
  // Inputs - Volume & Default Settings (New)
  // ---------------------------------------------------------------------------

  /// Sets the volume of an input.
  @Tool(
    name: 'inputs_set_volume',
    description: 'Set the volume of an input (0.0-1.0 multiplier).',
  )
  Future<Map<String, dynamic>> inputsSetVolume({
    String? inputName,
    String? inputUuid,
    @Parameter(
      title: 'Input Volume',
      description: 'Volume as multiplier (0.0 = silence, 1.0 = 100%).',
      example: 0.8,
    )
    required double inputVolume,
  }) async {
    await _obs.inputs.setInputVolume(
      inputName: inputName,
      inputUuid: inputUuid,
      inputVolume: inputVolume,
    );
    return _ok;
  }

  /// Gets the default settings for an input kind.
  @Tool(
    name: 'inputs_get_default_settings',
    description:
        'Return the default settings for a given input kind (before customization).',
  )
  Future<Map<String, dynamic>> inputsGetDefaultSettings({
    @Parameter(
      title: 'Input Kind',
      description: 'Type of input (e.g., video_capture_device, image_source).',
      example: 'video_capture_device',
    )
    required String inputKind,
  }) async {
    final response = await _obs.inputs.getInputDefaultSettings(
      inputKind: inputKind,
    );
    return response.toJson();
  }

  // ---------------------------------------------------------------------------
  // General - Extended (Vendor requests, hotkeys)
  // ---------------------------------------------------------------------------

  /// Calls a vendor-specific request.
  @Tool(
    name: 'general_call_vendor_request',
    description:
        'Call a request registered to a third-party vendor/plugin (e.g., obs-browser).',
  )
  Future<Map<String, dynamic>> generalCallVendorRequest({
    @Parameter(
      title: 'Vendor Name',
      description: 'Name of the vendor (e.g., obs-browser).',
      example: 'obs-browser',
    )
    required String vendorName,
    @Parameter(
      title: 'Request Type',
      description: 'Name of the vendor request to call.',
      example: 'emit_event',
    )
    required String requestType,
    @Parameter(title: 'Request Data') Map<String, dynamic>? requestData,
  }) async {
    final response = await _obs.general.callVendorRequest(
      vendorName: vendorName,
      requestType: requestType,
      requestData: requestData != null
          ? RequestData.fromJson(requestData)
          : null,
    );
    return response.toJson();
  }

  /// Triggers a hotkey by key sequence.
  @Tool(
    name: 'general_trigger_hotkey_by_key',
    description: 'Trigger a hotkey using a key sequence (e.g., Ctrl+Shift+A).',
  )
  Future<Map<String, dynamic>> generalTriggerHotkeyByKey({
    @Parameter(
      title: 'Key ID',
      description: 'Key identifier (e.g., OBS_KEY_A, OBS_KEY_F1).',
      example: 'OBS_KEY_A',
    )
    required String keyId,
    @Parameter(title: 'Shift Key') bool? keyModifiersShift,
    @Parameter(title: 'Control Key') bool? keyModifiersCtrl,
    @Parameter(title: 'Alt Key') bool? keyModifiersAlt,
    @Parameter(title: 'Command Key') bool? keyModifiersCmd,
  }) async {
    final modifiers = KeyModifiers(
      shift: keyModifiersShift,
      control: keyModifiersCtrl,
      alt: keyModifiersAlt,
      command: keyModifiersCmd,
    );
    await _obs.general.triggerHotkeyByKeySequence(
      keyId: keyId,
      keyModifiers: modifiers,
    );
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // Scene Items - Create/Duplicate/Remove/Transform (New)
  // ---------------------------------------------------------------------------

  /// Creates a new scene item by adding an existing source to a scene.
  @Tool(
    name: 'scene_items_create',
    description: 'Add an existing source as a new scene item in a scene.',
  )
  Future<Map<String, dynamic>> sceneItemsCreate({
    @Parameter(title: 'Scene Name', example: 'Scene') required String sceneName,
    @Parameter(
      title: 'Source Name',
      description: 'Name of the source to add to the scene.',
      example: 'Video Capture Device',
    )
    required String sourceName,
    @Parameter(title: 'Scene Item Enabled') bool? sceneItemEnabled,
  }) async {
    final response = await _obs.sceneItems.createSceneItem(
      sceneName: sceneName,
      sourceName: sourceName,
      sceneItemEnabled: sceneItemEnabled,
    );
    return <String, dynamic>{'sceneItemId': response};
  }

  /// Duplicates a scene item (copies it within or between scenes).
  @Tool(
    name: 'scene_items_duplicate',
    description:
        'Duplicate a scene item, copying it to the same or a different scene.',
  )
  Future<Map<String, dynamic>> sceneItemsDuplicate({
    @Parameter(title: 'Source Scene Name', example: 'Scene')
    required String sceneName,
    @Parameter(title: 'Scene Item ID') required int sceneItemId,
    @Parameter(
      title: 'Destination Scene Name',
      description: 'Scene to copy to (defaults to same scene).',
    )
    String? destinationSceneName,
  }) async {
    final response = await _obs.sceneItems.duplicateSceneItem(
      sceneName: sceneName,
      sceneItemId: sceneItemId,
      destinationSceneName: destinationSceneName,
    );
    return <String, dynamic>{'sceneItemId': response};
  }

  /// Removes a scene item from a scene.
  @Tool(
    name: 'scene_items_remove',
    description:
        'Remove a scene item from a scene (does not delete the source).',
  )
  Future<Map<String, dynamic>> sceneItemsRemove({
    @Parameter(title: 'Scene Name', example: 'Scene') required String sceneName,
    @Parameter(title: 'Scene Item ID') required int sceneItemId,
  }) async {
    await _obs.sceneItems.removeSceneItem(
      sceneName: sceneName,
      sceneItemId: sceneItemId,
    );
    return _ok;
  }

  /// Gets the transform of a scene item. Returned as a flat JSON object so
  /// the shape is symmetric with [sceneItemsSetTransform] (the legacy nested
  /// `{sceneItemTransform: {...}}` payload is also included for callers that
  /// still rely on it).
  @Tool(
    name: 'scene_items_get_transform',
    description:
        'Return the transform properties of a scene item as flat top-level '
        'fields (positionX, positionY, scaleX, scaleY, rotation, cropLeft, '
        'cropTop, cropRight, cropBottom, alignment, boundsType, '
        'boundsAlignment, boundsWidth, boundsHeight, sourceWidth, '
        'sourceHeight, width, height). Symmetric with set_transform.',
  )
  Future<Map<String, dynamic>> sceneItemsGetTransform({
    @Parameter(title: 'Scene Name', example: 'Scene') required String sceneName,
    @Parameter(title: 'Scene Item ID') required int sceneItemId,
  }) async {
    final transform = await _obs.sceneItems.getSceneItemTransformTyped(
      sceneName: sceneName,
      sceneItemId: sceneItemId,
    );
    return transform.toJson();
  }

  // ---------------------------------------------------------------------------
  // Canvases (New in OBS WebSocket v5.7.0)
  // ---------------------------------------------------------------------------

  /// Returns the list of canvases configured in OBS.
  @Tool(
    name: 'canvases_list',
    description: 'Return the list of all canvases configured in OBS (v5.7.0+).',
  )
  Future<Map<String, dynamic>> canvasesList() async =>
      (await _obs.canvas.getCanvasList()).toJson();

  /// Returns the canvas video settings (base/output dimensions and FPS).
  @Tool(
    name: 'video_settings',
    description:
        'Return base/output canvas dimensions and FPS via the legacy GetVideoSettings request. Works on every OBS WebSocket v5+ build (use this on builds older than v5.7.0 where canvases_list errors).',
  )
  Future<Map<String, dynamic>> videoSettings() async =>
      (await _obs.config.getVideoSettings()).toJson();

  // ---------------------------------------------------------------------------
  // Filters (New in OBS WebSocket v5.7.0 MCP exposure)
  // ---------------------------------------------------------------------------

  /// Returns the list of all available source filter kinds.
  @Tool(
    name: 'filters_kind_list',
    description: 'Return the list of all available source filter kinds.',
  )
  Future<List<String>> filtersKindList() =>
      _obs.filters.getSourceFilterKindList();

  /// Returns the list of filters for a source.
  @Tool(
    name: 'filters_list',
    description: 'Return the list of filters applied to a source.',
  )
  Future<List<Map<String, dynamic>>> filtersList(String sourceName) async =>
      await _obs.filters.getSourceFilterList(sourceName);

  /// Returns the default settings for a filter kind.
  @Tool(
    name: 'filters_default_settings',
    description: 'Return the default settings for a given filter kind.',
  )
  Future<Map<String, dynamic>> filtersDefaultSettings(
    String filterKind,
  ) async => await _obs.filters.getSourceFilterDefaultSettings(filterKind);

  /// Creates a new filter on a source.
  @Tool(
    name: 'filters_create',
    description: 'Create a new filter and apply it to a source.',
  )
  Future<Map<String, dynamic>> filtersCreate({
    @Parameter(title: 'Source Name', example: 'Video Capture Device')
    required String sourceName,
    @Parameter(title: 'Filter Name', example: 'Color Correction')
    required String filterName,
    @Parameter(title: 'Filter Kind', example: 'color_correction_v2')
    required String filterKind,
    @Parameter(title: 'Filter Settings') Map<String, dynamic>? filterSettings,
  }) async {
    await _obs.filters.createSourceFilter(
      sourceName: sourceName,
      filterName: filterName,
      filterKind: filterKind,
      filterSettings: filterSettings,
    );
    return _ok;
  }

  /// Removes a filter from a source.
  @Tool(name: 'filters_remove', description: 'Remove a filter from a source.')
  Future<Map<String, dynamic>> filtersRemove({
    @Parameter(title: 'Source Name') required String sourceName,
    @Parameter(title: 'Filter Name') required String filterName,
  }) async {
    await _obs.filters.removeSourceFilter(
      sourceName: sourceName,
      filterName: filterName,
    );
    return _ok;
  }

  /// Renames a filter on a source.
  @Tool(name: 'filters_rename', description: 'Rename a filter on a source.')
  Future<Map<String, dynamic>> filtersRename({
    @Parameter(title: 'Source Name') required String sourceName,
    @Parameter(title: 'Current Filter Name') required String filterName,
    @Parameter(title: 'New Filter Name') required String newFilterName,
  }) async {
    await _obs.filters.setSourceFilterName(
      sourceName: sourceName,
      filterName: filterName,
      newFilterName: newFilterName,
    );
    return _ok;
  }

  /// Returns information about a specific filter.
  @Tool(
    name: 'filters_get',
    description: 'Return information about a specific filter on a source.',
  )
  Future<Map<String, dynamic>> filtersGet({
    @Parameter(title: 'Source Name') required String sourceName,
    @Parameter(title: 'Filter Name') required String filterName,
  }) async => await _obs.filters.getSourceFilter(
    sourceName: sourceName,
    filterName: filterName,
  );

  /// Sets the index position of a filter on a source.
  @Tool(
    name: 'filters_set_index',
    description: 'Set the index position (order) of a filter on a source.',
  )
  Future<Map<String, dynamic>> filtersSetIndex({
    @Parameter(title: 'Source Name') required String sourceName,
    @Parameter(title: 'Filter Name') required String filterName,
    @Parameter(title: 'Filter Index', example: 0) required int filterIndex,
  }) async {
    await _obs.filters.setSourceFilterIndex(
      sourceName: sourceName,
      filterName: filterName,
      filterIndex: filterIndex,
    );
    return _ok;
  }

  /// Sets the settings of a filter.
  @Tool(
    name: 'filters_set_settings',
    description: 'Set or merge the settings of a filter on a source.',
  )
  Future<Map<String, dynamic>> filtersSetSettings({
    @Parameter(title: 'Source Name') required String sourceName,
    @Parameter(title: 'Filter Name') required String filterName,
    @Parameter(title: 'Filter Settings')
    required Map<String, dynamic> filterSettings,
    @Parameter(title: 'Overlay', description: 'Merge with existing settings.')
    bool? overlay,
  }) async {
    await _obs.filters.setSourceFilterSettings(
      sourceName: sourceName,
      filterName: filterName,
      filterSettings: filterSettings,
      overlay: overlay,
    );
    return _ok;
  }

  /// Sets the enabled state of a filter.
  @Tool(
    name: 'filters_set_enabled',
    description: 'Enable or disable a filter on a source.',
  )
  Future<Map<String, dynamic>> filtersSetEnabled({
    @Parameter(title: 'Source Name') required String sourceName,
    @Parameter(title: 'Filter Name') required String filterName,
    @Parameter(title: 'Filter Enabled', example: true)
    required bool filterEnabled,
  }) async {
    await _obs.filters.setSourceFilterEnabled(
      sourceName: sourceName,
      filterName: filterName,
      filterEnabled: filterEnabled,
    );
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // Outputs - Extended (New in OBS WebSocket v5.7.0 MCP exposure)
  // ---------------------------------------------------------------------------

  /// Returns the list of all available outputs.
  @Tool(
    name: 'outputs_list',
    description: 'Return the list of all available outputs in OBS.',
  )
  Future<List<Map<String, dynamic>>> outputsList() async =>
      await _obs.outputs.getOutputList();

  /// Returns the status of a specific output.
  @Tool(
    name: 'outputs_get_status',
    description: 'Return the status of a named output.',
  )
  Future<Map<String, dynamic>> outputsGetStatus(String outputName) async =>
      await _obs.outputs.getOutputStatus(outputName);

  /// Returns the settings of a specific output.
  @Tool(
    name: 'outputs_get_settings',
    description: 'Return the settings of a named output.',
  )
  Future<Map<String, dynamic>> outputsGetSettings(String outputName) async =>
      await _obs.outputs.getOutputSettings(outputName);

  /// Sets the settings of a specific output.
  @Tool(
    name: 'outputs_set_settings',
    description: 'Set the settings of a named output.',
  )
  Future<Map<String, dynamic>> outputsSetSettings({
    @Parameter(title: 'Output Name') required String outputName,
    @Parameter(title: 'Output Settings')
    required Map<String, dynamic> outputSettings,
  }) async {
    await _obs.outputs.setOutputSettings(
      outputName: outputName,
      outputSettings: outputSettings,
    );
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // Inputs - Audio Properties (New in OBS WebSocket v5.7.0 MCP exposure)
  // ---------------------------------------------------------------------------

  /// Returns the audio balance of an input.
  @Tool(
    name: 'inputs_get_audio_balance',
    description: 'Return the audio balance (left-right) of an input.',
  )
  Future<Map<String, dynamic>> inputsGetAudioBalance({
    String? inputName,
    String? inputUuid,
  }) async {
    final response = await _obs.inputs.getInputAudioBalance(
      inputName: inputName,
      inputUuid: inputUuid,
    );
    return response.toJson();
  }

  /// Sets the audio balance of an input.
  @Tool(
    name: 'inputs_set_audio_balance',
    description:
        'Set the audio balance of an input (0.0 = left, 1.0 = right, 0.5 = center).',
  )
  Future<Map<String, dynamic>> inputsSetAudioBalance({
    String? inputName,
    String? inputUuid,
    @Parameter(
      title: 'Audio Balance',
      description: '0.0 = full left, 1.0 = full right, 0.5 = center.',
      example: 0.5,
    )
    required double inputAudioBalance,
  }) async {
    await _obs.inputs.setInputAudioBalance(
      inputName: inputName,
      inputUuid: inputUuid,
      inputAudioBalance: inputAudioBalance,
    );
    return _ok;
  }

  /// Returns the audio sync offset of an input.
  @Tool(
    name: 'inputs_get_audio_sync_offset',
    description: 'Return the audio sync offset of an input in milliseconds.',
  )
  Future<Map<String, dynamic>> inputsGetAudioSyncOffset({
    String? inputName,
    String? inputUuid,
  }) async {
    final response = await _obs.inputs.getInputAudioSyncOffset(
      inputName: inputName,
      inputUuid: inputUuid,
    );
    return response.toJson();
  }

  /// Sets the audio sync offset of an input.
  @Tool(
    name: 'inputs_set_audio_sync_offset',
    description: 'Set the audio sync offset of an input in milliseconds.',
  )
  Future<Map<String, dynamic>> inputsSetAudioSyncOffset({
    String? inputName,
    String? inputUuid,
    @Parameter(
      title: 'Sync Offset (ms)',
      description: 'Audio sync offset in milliseconds.',
      example: 0,
    )
    required int inputAudioSyncOffset,
  }) async {
    await _obs.inputs.setInputAudioSyncOffset(
      inputName: inputName,
      inputUuid: inputUuid,
      inputAudioSyncOffset: inputAudioSyncOffset,
    );
    return _ok;
  }

  /// Returns the audio monitor type of an input.
  @Tool(
    name: 'inputs_get_audio_monitor_type',
    description:
        'Return the audio monitor type of an input (none, monitor only, monitor and output).',
  )
  Future<Map<String, dynamic>> inputsGetAudioMonitorType({
    String? inputName,
    String? inputUuid,
  }) async {
    final response = await _obs.inputs.getInputAudioMonitorType(
      inputName: inputName,
      inputUuid: inputUuid,
    );
    return response.toJson();
  }

  /// Sets the audio monitor type of an input.
  @Tool(
    name: 'inputs_set_audio_monitor_type',
    description:
        'Set the audio monitor type of an input (0 = none, 1 = monitor only, 2 = monitor and output).',
  )
  Future<Map<String, dynamic>> inputsSetAudioMonitorType({
    String? inputName,
    String? inputUuid,
    @Parameter(
      title: 'Monitor Type',
      description: '0 = none, 1 = monitor only, 2 = monitor and output.',
      example: 0,
    )
    required int monitorType,
  }) async {
    final type = _parseMonitorType(monitorType);

    await _obs.inputs.setInputAudioMonitorType(
      inputName: inputName,
      inputUuid: inputUuid,
      monitorType: type,
    );
    return _ok;
  }

  /// Parses an integer monitor type value into ObsMonitoringType enum.
  static ObsMonitoringType _parseMonitorType(int value) {
    return switch (value) {
      0 => ObsMonitoringType.none,
      1 => ObsMonitoringType.monitorOnly,
      2 => ObsMonitoringType.monitorAndOutput,
      _ => throw ArgumentError(
        'Invalid monitor type: $value. Must be 0 (none), 1 (monitor only), or 2 (monitor and output).',
      ),
    };
  }

  /// Returns the audio tracks of an input.
  @Tool(
    name: 'inputs_get_audio_tracks',
    description: 'Return the audio track bitmask of an input.',
  )
  Future<Map<String, dynamic>> inputsGetAudioTracks({
    String? inputName,
    String? inputUuid,
  }) async {
    final response = await _obs.inputs.getInputAudioTracks(
      inputName: inputName,
      inputUuid: inputUuid,
    );
    return response.toJson();
  }

  /// Sets the audio tracks of an input.
  @Tool(
    name: 'inputs_set_audio_tracks',
    description:
        'Set the audio tracks of an input (bitmask: 1=track1, 2=track2, 4=track3, etc.).',
  )
  Future<Map<String, dynamic>> inputsSetAudioTracks({
    String? inputName,
    String? inputUuid,
    @Parameter(
      title: 'Audio Tracks',
      description:
          'Bitmask representing audio tracks (1=track1, 2=track2, 4=track3, 8=track4, 16=track5, 32=track6).',
      example: 1,
    )
    required int inputAudioTracks,
  }) async {
    await _obs.inputs.setInputAudioTracks(
      inputName: inputName,
      inputUuid: inputUuid,
      inputAudioTracks: inputAudioTracks,
    );
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // Inputs - Properties Dialog (New in OBS WebSocket v5.7.0 MCP exposure)
  // ---------------------------------------------------------------------------

  /// Returns the items of a list property from an input's properties.
  @Tool(
    name: 'inputs_get_properties_list_items',
    description:
        'Return the items of a list property from an input\'s properties dialog.',
  )
  Future<Map<String, dynamic>> inputsGetPropertiesListItems({
    String? inputName,
    String? inputUuid,
    @Parameter(title: 'Property Name') required String propertyName,
  }) async {
    final response = await _obs.inputs.getInputPropertiesListPropertyItems(
      inputName: inputName,
      inputUuid: inputUuid,
      propertyName: propertyName,
    );
    return response.toJson();
  }

  /// Presses a button in the input's properties dialog.
  @Tool(
    name: 'inputs_press_properties_button',
    description: 'Press a button property in an input\'s properties dialog.',
  )
  Future<Map<String, dynamic>> inputsPressPropertiesButton({
    String? inputName,
    String? inputUuid,
    @Parameter(title: 'Property Name') required String propertyName,
  }) async {
    await _obs.inputs.pressInputPropertiesButton(
      inputName: inputName,
      inputUuid: inputUuid,
      propertyName: propertyName,
    );
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // Scene Items - Extended (New in OBS WebSocket v5.7.0 MCP exposure)
  // ---------------------------------------------------------------------------

  /// Returns the source name for a scene item.
  @Tool(
    name: 'scene_items_get_source',
    description: 'Return the source name for a given scene item.',
  )
  Future<Map<String, dynamic>> sceneItemsGetSource({
    @Parameter(title: 'Scene Name') String? sceneName,
    @Parameter(title: 'Scene UUID') String? sceneUuid,
    @Parameter(title: 'Scene Item ID') required int sceneItemId,
  }) async {
    final response = await _obs.sceneItems.getSceneItemSource(
      sceneName: sceneName,
      sceneUuid: sceneUuid,
      sceneItemId: sceneItemId,
    );
    // Returns Map<String, dynamic> directly from the library (no .toJson() needed)
    return response;
  }

  /// Returns the private settings of a scene item.
  @Tool(
    name: 'scene_items_get_private_settings',
    description: 'Return the private settings of a scene item.',
  )
  Future<Map<String, dynamic>> sceneItemsGetPrivateSettings({
    @Parameter(title: 'Scene Name') String? sceneName,
    @Parameter(title: 'Scene UUID') String? sceneUuid,
    @Parameter(title: 'Scene Item ID') required int sceneItemId,
  }) async {
    final response = await _obs.sceneItems.getSceneItemPrivateSettings(
      sceneName: sceneName,
      sceneUuid: sceneUuid,
      sceneItemId: sceneItemId,
    );
    // Returns Map<String, dynamic> directly from the library (no .toJson() needed)
    return response;
  }

  /// Sets the private settings of a scene item.
  @Tool(
    name: 'scene_items_set_private_settings',
    description: 'Set the private settings of a scene item.',
  )
  Future<Map<String, dynamic>> sceneItemsSetPrivateSettings({
    @Parameter(title: 'Scene Name') String? sceneName,
    @Parameter(title: 'Scene UUID') String? sceneUuid,
    @Parameter(title: 'Scene Item ID') required int sceneItemId,
    @Parameter(title: 'Private Settings')
    required Map<String, dynamic> sceneItemSettings,
  }) async {
    await _obs.sceneItems.setSceneItemPrivateSettings(
      sceneName: sceneName,
      sceneUuid: sceneUuid,
      sceneItemId: sceneItemId,
      sceneItemSettings: sceneItemSettings,
    );
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // Reliability / lifecycle convenience tools
  // ---------------------------------------------------------------------------

  /// Returns a snapshot of the live connection state.
  @Tool(
    name: 'connection_status',
    description:
        'Return the current OBS WebSocket connection state '
        '(disconnected | connecting | connected | reconnecting | failed) '
        'plus the negotiated RPC version when available.',
  )
  Map<String, dynamic> connectionStatus() {
    final client = _client;
    if (client == null) {
      return <String, dynamic>{
        'connected': false,
        'state': 'disconnected',
        if (_bootstrapError != null) 'bootstrapError': _bootstrapError,
      };
    }
    return <String, dynamic>{
      'connected': client.connectionState == ObsConnectionState.connected,
      'state': client.connectionState.name,
      'negotiatedRpcVersion': client.negotiatedRpcVersion,
    };
  }

  /// Round-trips a `GetVersion` request to verify the connection is alive.
  @Tool(
    name: 'connection_ping',
    description:
        'Round-trip a GetVersion request and return latency in ms. Use this '
        'as a cheap liveness probe before issuing batched commands.',
  )
  Future<Map<String, dynamic>> connectionPing() async {
    final start = DateTime.now();
    final version = await _obs.ping();
    final elapsed = DateTime.now().difference(start);
    return <String, dynamic>{
      'ok': true,
      'latencyMs': elapsed.inMilliseconds,
      'obsVersion': version.obsVersion,
      'obsWebSocketVersion': version.obsWebSocketVersion,
      'rpcVersion': version.rpcVersion,
    };
  }

  /// Updates the active event subscription mask.
  @Tool(
    name: 'events_subscribe',
    description:
        'Update the active OBS event subscription mask. Accepts either an '
        'integer bitmask or a list of subscription names '
        '(general, config, scenes, inputs, transitions, filters, outputs, '
        'sceneItems, mediaInputs, vendors, ui, canvases, all, '
        'inputVolumeMeters, inputActiveStateChanged, inputShowStateChanged, '
        'sceneItemTransformChanged). Required before wait_for_event for any '
        'event type that is not in the default subscription set.',
  )
  Future<Map<String, dynamic>> eventsSubscribe({
    @Parameter(
      title: 'Subscription Mask',
      description:
          'Combined integer bitmask. Mutually exclusive with subscriptions.',
    )
    int? mask,
    @Parameter(
      title: 'Subscriptions',
      description:
          'List of EventSubscription names to OR together. Mutually exclusive '
          'with mask.',
    )
    List<String>? subscriptions,
  }) async {
    final resolved = parseEventSubscription(mask, subscriptions);
    await _obs.listenForMask(resolved);
    return <String, dynamic>{'ok': true, 'mask': resolved};
  }

  /// Awaits the next OBS event matching the given type.
  @Tool(
    name: 'wait_for_event',
    description:
        'Wait for the next OBS event whose eventType matches the given name '
        '(e.g. RecordStateChanged, SceneItemTransformChanged). Times out '
        'after timeoutMs (default 30000). The caller MUST have subscribed to '
        'the relevant event group first via events_subscribe.',
  )
  Future<Map<String, dynamic>> waitForEvent({
    @Parameter(
      title: 'Event Type',
      description: 'OBS event name, e.g. RecordStateChanged.',
      example: 'RecordStateChanged',
    )
    required String eventType,
    @Parameter(
      title: 'Timeout (ms)',
      description: 'Maximum time to wait before throwing TimeoutException.',
      example: 30000,
    )
    int? timeoutMs,
  }) async {
    final event = await _obs.waitForEvent(
      eventType: eventType,
      timeout: Duration(milliseconds: timeoutMs ?? 30000),
    );
    return <String, dynamic>{
      'eventType': event.eventType,
      'eventIntent': event.eventIntent,
      'eventData': event.eventData ?? <String, dynamic>{},
    };
  }

  /// Server-side sleep so JS code inside the execute() sandbox does not need
  /// to keep the Node.js subprocess alive with setTimeout (which competes
  /// with the 30s sandbox timeout). The wait happens on the MCP host where
  /// the live OBS connection lives.
  @Tool(
    name: 'client_sleep',
    description:
        'Pause server-side for the requested number of milliseconds. Prefer '
        'this over setTimeout/Promise inside execute() JS so the sandbox '
        'subprocess stays idle while the MCP host holds the wall clock. '
        'Maximum 25000ms per call to leave headroom under the sandbox '
        'timeout.',
  )
  Future<Map<String, dynamic>> clientSleep({
    @Parameter(
      title: 'Milliseconds',
      description: 'Sleep duration in milliseconds (1..25000).',
      example: 500,
    )
    required int ms,
  }) async {
    if (ms < 1 || ms > 25000) {
      throw ArgumentError(
        'client_sleep ms must be between 1 and 25000 (got $ms).',
      );
    }
    final start = DateTime.now();
    await Future.delayed(Duration(milliseconds: ms));
    return <String, dynamic>{
      'ok': true,
      'requestedMs': ms,
      'actualMs': DateTime.now().difference(start).inMilliseconds,
    };
  }

  // ---------------------------------------------------------------------------
  // Server-side animation
  // ---------------------------------------------------------------------------

  /// Animates a scene item transform server-side over a fixed duration so the
  /// caller does not need to spawn a sleep loop inside the execute() sandbox
  /// (which is bound by the 30s subprocess timeout and cannot survive a
  /// reconnect).
  @Tool(
    name: 'scene_items_animate_transform',
    description:
        'Smoothly animate a scene item transform from its current state to '
        'the supplied target over durationMs. Runs server-side at frameRate '
        'fps (clamped 1-60). Fields omitted from the target hold steady. '
        'Easing options: linear, easeIn, easeOut, easeInOut, easeOutBounce.',
  )
  Future<Map<String, dynamic>> sceneItemsAnimateTransform({
    @Parameter(title: 'Scene Name', example: 'Scene') required String sceneName,
    @Parameter(title: 'Scene Item ID', example: 4) required int sceneItemId,
    @Parameter(title: 'Duration (ms)', example: 1000) required int durationMs,
    @Parameter(title: 'Target Position X') num? targetPositionX,
    @Parameter(title: 'Target Position Y') num? targetPositionY,
    @Parameter(title: 'Target Scale X') num? targetScaleX,
    @Parameter(title: 'Target Scale Y') num? targetScaleY,
    @Parameter(title: 'Target Rotation') num? targetRotation,
    @Parameter(title: 'Target Crop Left') int? targetCropLeft,
    @Parameter(title: 'Target Crop Top') int? targetCropTop,
    @Parameter(title: 'Target Crop Right') int? targetCropRight,
    @Parameter(title: 'Target Crop Bottom') int? targetCropBottom,
    @Parameter(
      title: 'Frame Rate',
      description: 'Frames per second to render. Clamped to 1..60.',
      example: 30,
    )
    int? frameRate,
    @Parameter(
      title: 'Easing',
      description:
          'linear | easeIn | easeOut | easeInOut | easeOutBounce. '
          'Defaults to linear.',
    )
    String? easing,
    @Parameter(
      title: 'Restore On Complete',
      description:
          'When true the original transform is reapplied after the animation '
          'finishes. Useful for transient "bump" animations.',
    )
    bool? restoreOnComplete,
  }) async {
    final fps = (frameRate ?? 30).clamp(1, 60);
    final ease = resolveEasing(easing);
    final start = await _obs.sceneItems.getSceneItemTransformTyped(
      sceneName: sceneName,
      sceneItemId: sceneItemId,
    );
    final target = SceneItemTransform(
      positionX: targetPositionX?.toDouble() ?? start.positionX,
      positionY: targetPositionY?.toDouble() ?? start.positionY,
      scaleX: targetScaleX?.toDouble() ?? start.scaleX,
      scaleY: targetScaleY?.toDouble() ?? start.scaleY,
      rotation: targetRotation?.toDouble() ?? start.rotation,
      cropLeft: targetCropLeft ?? start.cropLeft,
      cropTop: targetCropTop ?? start.cropTop,
      cropRight: targetCropRight ?? start.cropRight,
      cropBottom: targetCropBottom ?? start.cropBottom,
      alignment: start.alignment,
      boundsType: start.boundsType,
      boundsAlignment: start.boundsAlignment,
      boundsWidth: start.boundsWidth,
      boundsHeight: start.boundsHeight,
    );
    final totalFrames = math.max(1, (durationMs * fps / 1000).round());
    final frameInterval = Duration(microseconds: (1000000 / fps).round());
    final stopwatch = Stopwatch()..start();
    var framesRendered = 0;
    for (var i = 1; i <= totalFrames; i++) {
      final t = ease(i / totalFrames);
      final isLast = i == totalFrames;
      final frame = isLast ? target : interpolateTransform(start, target, t);
      await _obs.sceneItems.setSceneItemTransformTyped(
        sceneName: sceneName,
        sceneItemId: sceneItemId,
        transform: frame,
      );
      framesRendered++;
      if (!isLast) {
        await Future.delayed(frameInterval);
      }
    }
    if (restoreOnComplete == true) {
      await _obs.sceneItems.setSceneItemTransformTyped(
        sceneName: sceneName,
        sceneItemId: sceneItemId,
        transform: start,
      );
    }
    stopwatch.stop();
    return <String, dynamic>{
      'ok': true,
      'framesRendered': framesRendered,
      'frameRate': fps,
      'durationMs': durationMs,
      'elapsedMs': stopwatch.elapsedMilliseconds,
      'easing': easing ?? 'linear',
      'restored': restoreOnComplete == true,
    };
  }

  // ---------------------------------------------------------------------------
  // Internal helpers (not exposed as MCP tools)
  // ---------------------------------------------------------------------------

  // Animation/easing helpers live in `animation_helpers.dart` so they can be
  // unit-tested without spinning up an MCP server or OBS connection.
}
