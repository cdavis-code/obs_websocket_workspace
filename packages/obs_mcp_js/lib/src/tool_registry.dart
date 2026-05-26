/// Tool registry — single source of truth for all OBS MCP tool definitions.
///
/// Every OBS WebSocket tool is registered here with its name, description,
/// parameter schema, and dispatch handler. The [MCPServerWithToolsJs] in
/// `obs_mcp_server_js.mcp.dart` reads [ObsMcpServer.toolDefs] to build tool
/// specs and route tool calls.
///
/// ## Adding a new tool
/// 1. Add the server method to [ObsMcpServer]
/// 2. Add ONE [ToolDef] entry to [buildRegistry] below
/// 3. Rebuild: `dart compile js lib/obs_mcp_js.dart -o bin/obs-mcp-server.js`
library;

import 'package:obs_websocket/obs_websocket.dart';

import 'obs_mcp_server_js.dart';

/// Builds the complete tool registry once at startup.
///
/// Each entry maps a tool name to its metadata and dispatch handler.
/// The handler receives the raw MCP arguments map and an [ObsMcpServer]
/// instance to call method on.
/// ignore_for_file: lines_longer_than_120_chars
List<ToolDef> buildRegistry() => <ToolDef>[
  // ========================================================================
  // Connection
  // ========================================================================
  ToolDef(
    name: 'obs_connect',
    description:
        'Connect to an OBS WebSocket server (ws:// or wss://) and authenticate.',
    parameters: [
      {'name': 'url', 'type': 'string', 'required': true},
      {'name': 'password', 'type': 'string', 'required': false},
      {'name': 'timeoutSeconds', 'type': 'number', 'required': false},
      {'name': 'autoReconnect', 'type': 'boolean', 'required': false},
    ],
    dispatch: (args, s) => s.connect(
      url: args!['url'] as String,
      password: args['password'] as String?,
      timeoutSeconds: args['timeoutSeconds'] as int?,
      autoReconnect: args['autoReconnect'] as bool?,
    ),
  ),
  ToolDef(
    name: 'obs_disconnect',
    description: 'Close the active OBS WebSocket connection.',
    dispatch: (_, s) => s.disconnect(),
  ),
  ToolDef(
    name: 'obs_is_connected',
    description: 'Return whether a live OBS WebSocket connection is held.',
    dispatch: (_, s) => s.isConnected(),
  ),
  ToolDef(
    name: 'obs_connection_status',
    description:
        'Return the current OBS WebSocket connection state plus negotiated RPC version.',
    dispatch: (_, s) => s.connectionStatus(),
  ),
  ToolDef(
    name: 'obs_connection_ping',
    description: 'Round-trip a GetVersion request and return latency in ms.',
    dispatch: (_, s) => s.connectionPing(),
  ),
  ToolDef(
    name: 'obs_send_raw',
    description:
        'Send a raw OBS WebSocket request and return the response payload.',
    parameters: [
      {'name': 'requestType', 'type': 'string', 'required': true},
      {'name': 'requestData', 'type': 'object', 'required': false},
    ],
    dispatch: (args, s) => s.sendRaw(
      requestType: args!['requestType'] as String,
      requestData: args['requestData'],
    ),
  ),

  // ========================================================================
  // General
  // ========================================================================
  ToolDef(
    name: 'obs_general_version',
    description: 'Return OBS Studio + obs-websocket version information.',
    dispatch: (_, s) => s.generalVersion(),
  ),
  ToolDef(
    name: 'obs_general_stats',
    description: 'Return OBS runtime statistics (cpu, memory, frame rate).',
    dispatch: (_, s) => s.generalStats(),
  ),
  ToolDef(
    name: 'obs_general_hotkeys',
    description: 'Return the names of every registered hotkey in OBS.',
    dispatch: (_, s) => s.generalHotkeys(),
  ),
  ToolDef(
    name: 'obs_general_trigger_hotkey',
    description: 'Trigger a hotkey by its registered name.',
    parameters: [
      {'name': 'hotkeyName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) =>
        s.generalTriggerHotkey(args!['hotkeyName'] as String),
  ),
  ToolDef(
    name: 'obs_general_trigger_hotkey_by_key',
    description: 'Trigger a hotkey using a key sequence (e.g., Ctrl+Shift+A).',
    parameters: [
      {'name': 'keyId', 'type': 'string', 'required': true},
      {'name': 'shift', 'type': 'boolean', 'required': false},
      {'name': 'control', 'type': 'boolean', 'required': false},
      {'name': 'alt', 'type': 'boolean', 'required': false},
      {'name': 'command', 'type': 'boolean', 'required': false},
    ],
    dispatch: (args, s) => s.generalTriggerHotkeyByKey(
      keyId: args!['keyId'] as String,
      keyModifiersShift: args['shift'] as bool?,
      keyModifiersCtrl: args['control'] as bool?,
      keyModifiersAlt: args['alt'] as bool?,
      keyModifiersCmd: args['command'] as bool?,
    ),
  ),
  ToolDef(
    name: 'obs_general_sleep',
    description:
        'Sleep for a duration in milliseconds or frames (executed server-side).',
    parameters: [
      {'name': 'sleepMillis', 'type': 'number', 'required': false},
      {'name': 'sleepFrames', 'type': 'number', 'required': false},
    ],
    dispatch: (args, s) => s.generalSleep(
      sleepMillis: args?['sleepMillis'] as int?,
      sleepFrames: args?['sleepFrames'] as int?,
    ),
  ),
  ToolDef(
    name: 'obs_general_broadcast_custom_event',
    description: 'Broadcast a custom JSON event to all connected clients.',
    parameters: [
      {'name': 'eventData', 'type': 'object', 'required': true},
    ],
    dispatch: (args, s) => s.generalBroadcastCustomEvent(
      args!['eventData'] as Map<String, dynamic>,
    ),
  ),
  ToolDef(
    name: 'obs_general_call_vendor_request',
    description: 'Call a request registered to a third-party vendor/plugin.',
    parameters: [
      {'name': 'vendorName', 'type': 'string', 'required': true},
      {'name': 'requestType', 'type': 'string', 'required': true},
      {'name': 'requestData', 'type': 'object', 'required': false},
    ],
    dispatch: (args, s) => s.generalCallVendorRequest(
      vendorName: args!['vendorName'] as String,
      requestType: args['requestType'] as String,
      requestData: args['requestData'] as Map<String, dynamic>?,
    ),
  ),

  // ========================================================================
  // Scenes
  // ========================================================================
  ToolDef(
    name: 'obs_scenes_list',
    description:
        'Return all scenes plus the current program and preview scene.',
    dispatch: (_, s) => s.scenesList(),
  ),
  ToolDef(
    name: 'obs_scenes_group_list',
    description: 'Return the names of all groups in OBS.',
    dispatch: (_, s) => s.scenesGroupList(),
  ),
  ToolDef(
    name: 'obs_scenes_get_current_program',
    description: 'Return the name of the scene currently on the program bus.',
    dispatch: (_, s) => s.scenesGetCurrentProgram(),
  ),
  ToolDef(
    name: 'obs_scenes_set_current_program',
    description: 'Set the program scene to the given sceneName.',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) =>
        s.scenesSetCurrentProgram(args!['sceneName'] as String),
  ),
  ToolDef(
    name: 'obs_scenes_get_current_preview',
    description: 'Return the name of the preview scene (studio mode only).',
    dispatch: (_, s) => s.scenesGetCurrentPreview(),
  ),
  ToolDef(
    name: 'obs_scenes_set_current_preview',
    description: 'Set the preview scene (studio mode only).',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) =>
        s.scenesSetCurrentPreview(args!['sceneName'] as String),
  ),
  ToolDef(
    name: 'obs_scenes_create',
    description: 'Create a new scene with the given name.',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.scenesCreate(args!['sceneName'] as String),
  ),
  ToolDef(
    name: 'obs_scenes_remove',
    description: 'Remove a scene from OBS.',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.scenesRemove(args!['sceneName'] as String),
  ),
  ToolDef(
    name: 'obs_scenes_set_name',
    description: 'Set the name of a scene (rename).',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.scenesSetName(args!['sceneName'] as String),
  ),
  ToolDef(
    name: 'obs_scenes_get_transition_override',
    description: 'Get the scene transition override configured for a scene.',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) =>
        s.scenesGetSceneTransitionOverride(args!['sceneName'] as String),
  ),
  ToolDef(
    name: 'obs_scenes_set_transition_override',
    description:
        'Set the scene transition override for a scene (transitionName, transitionDuration).',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
      {'name': 'transitionName', 'type': 'string', 'required': false},
      {'name': 'transitionDuration', 'type': 'number', 'required': false},
    ],
    dispatch: (args, s) => s.scenesSetSceneTransitionOverride(
      args!['sceneName'] as String,
      transitionName: args['transitionName'] as String?,
      transitionDuration: args['transitionDuration'] as int?,
    ),
  ),

  // ========================================================================
  // Scene Items
  // ========================================================================
  ToolDef(
    name: 'obs_scene_items_list',
    description: 'List the scene items (sources) contained in a scene.',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.sceneItemsList(args!['sceneName'] as String),
  ),
  ToolDef(
    name: 'obs_scene_items_group_list',
    description: 'List the scene items contained in a group.',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.sceneItemsGroupList(args!['sceneName'] as String),
  ),
  ToolDef(
    name: 'obs_scene_items_get_id',
    description:
        'Return the numeric sceneItemId for a source placed in a given scene.',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
      {'name': 'sourceName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.sceneItemsGetId(
      sceneName: args!['sceneName'] as String,
      sourceName: args['sourceName'] as String,
    ),
  ),
  ToolDef(
    name: 'obs_scene_items_get_enabled',
    description: 'Return whether a scene item is currently enabled (visible).',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
      {'name': 'sceneItemId', 'type': 'number', 'required': true},
    ],
    dispatch: (args, s) => s.sceneItemsGetEnabled(
      sceneName: args!['sceneName'] as String,
      sceneItemId: args['sceneItemId'] as int,
    ),
  ),
  ToolDef(
    name: 'obs_scene_items_set_enabled',
    description: 'Show or hide a scene item by id.',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
      {'name': 'sceneItemId', 'type': 'number', 'required': true},
      {'name': 'sceneItemEnabled', 'type': 'boolean', 'required': true},
    ],
    dispatch: (args, s) => s.sceneItemsSetEnabled(
      sceneName: args!['sceneName'] as String,
      sceneItemId: args['sceneItemId'] as int,
      sceneItemEnabled: args['sceneItemEnabled'] as bool,
    ),
  ),
  ToolDef(
    name: 'obs_scene_items_get_locked',
    description: 'Return whether a scene item is locked (uneditable).',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
      {'name': 'sceneItemId', 'type': 'number', 'required': true},
    ],
    dispatch: (args, s) => s.sceneItemsGetLocked(
      sceneName: args!['sceneName'] as String,
      sceneItemId: args['sceneItemId'] as int,
    ),
  ),
  ToolDef(
    name: 'obs_scene_items_set_locked',
    description: 'Lock or unlock a scene item by id.',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
      {'name': 'sceneItemId', 'type': 'number', 'required': true},
      {'name': 'sceneItemLocked', 'type': 'boolean', 'required': true},
    ],
    dispatch: (args, s) => s.sceneItemsSetLocked(
      sceneName: args!['sceneName'] as String,
      sceneItemId: args['sceneItemId'] as int,
      sceneItemLocked: args['sceneItemLocked'] as bool,
    ),
  ),
  ToolDef(
    name: 'obs_scene_items_get_transform',
    description:
        'Return the transform properties of a scene item (position, scale, rotation, crop, bounds).',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
      {'name': 'sceneItemId', 'type': 'number', 'required': true},
    ],
    dispatch: (args, s) => s.sceneItemsGetTransform(
      sceneName: args!['sceneName'] as String,
      sceneItemId: args['sceneItemId'] as int,
    ),
  ),
  ToolDef(
    name: 'obs_scene_items_set_transform',
    description:
        'Set the transform properties of a scene item. Only provide the fields you want to change.',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
      {'name': 'sceneItemId', 'type': 'number', 'required': true},
      {'name': 'positionX', 'type': 'number', 'required': false},
      {'name': 'positionY', 'type': 'number', 'required': false},
      {'name': 'scaleX', 'type': 'number', 'required': false},
      {'name': 'scaleY', 'type': 'number', 'required': false},
      {'name': 'rotation', 'type': 'number', 'required': false},
      {'name': 'cropLeft', 'type': 'number', 'required': false},
      {'name': 'cropTop', 'type': 'number', 'required': false},
      {'name': 'cropRight', 'type': 'number', 'required': false},
      {'name': 'cropBottom', 'type': 'number', 'required': false},
      {'name': 'alignment', 'type': 'number', 'required': false},
      {'name': 'boundsType', 'type': 'string', 'required': false},
      {'name': 'boundsAlignment', 'type': 'number', 'required': false},
      {'name': 'boundsWidth', 'type': 'number', 'required': false},
      {'name': 'boundsHeight', 'type': 'number', 'required': false},
    ],
    dispatch: (args, s) => s.sceneItemsSetTransform(
      sceneName: args!['sceneName'] as String,
      sceneItemId: args['sceneItemId'] as int,
      positionX: args['positionX'] as num?,
      positionY: args['positionY'] as num?,
      scaleX: args['scaleX'] as num?,
      scaleY: args['scaleY'] as num?,
      rotation: args['rotation'] as num?,
      cropLeft: args['cropLeft'] as int?,
      cropTop: args['cropTop'] as int?,
      cropRight: args['cropRight'] as int?,
      cropBottom: args['cropBottom'] as int?,
      alignment: args['alignment'] as int?,
      boundsType: args['boundsType'] as String?,
      boundsAlignment: args['boundsAlignment'] as int?,
      boundsWidth: args['boundsWidth'] as num?,
      boundsHeight: args['boundsHeight'] as num?,
    ),
  ),
  ToolDef(
    name: 'obs_scene_items_create',
    description: 'Add an existing source as a new scene item in a scene.',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
      {'name': 'sourceName', 'type': 'string', 'required': true},
      {'name': 'sceneItemEnabled', 'type': 'boolean', 'required': false},
    ],
    dispatch: (args, s) => s.sceneItemsCreate(
      sceneName: args!['sceneName'] as String,
      sourceName: args['sourceName'] as String,
      sceneItemEnabled: args['sceneItemEnabled'] as bool?,
    ),
  ),
  ToolDef(
    name: 'obs_scene_items_duplicate',
    description:
        'Duplicate a scene item, copying it to the same or a different scene.',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
      {'name': 'sceneItemId', 'type': 'number', 'required': true},
      {'name': 'destinationSceneName', 'type': 'string', 'required': false},
    ],
    dispatch: (args, s) => s.sceneItemsDuplicate(
      sceneName: args!['sceneName'] as String,
      sceneItemId: args['sceneItemId'] as int,
      destinationSceneName: args['destinationSceneName'] as String?,
    ),
  ),
  ToolDef(
    name: 'obs_scene_items_remove',
    description:
        'Remove a scene item from a scene (does not delete the source).',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
      {'name': 'sceneItemId', 'type': 'number', 'required': true},
    ],
    dispatch: (args, s) => s.sceneItemsRemove(
      sceneName: args!['sceneName'] as String,
      sceneItemId: args['sceneItemId'] as int,
    ),
  ),
  ToolDef(
    name: 'obs_scene_items_get_source',
    description: 'Return the source name for a given scene item.',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': false},
      {'name': 'sceneItemId', 'type': 'number', 'required': true},
    ],
    dispatch: (args, s) => s.sceneItemsGetSource(
      sceneName: args!['sceneName'] as String?,
      sceneItemId: args['sceneItemId'] as int,
    ),
  ),
  ToolDef(
    name: 'obs_scene_items_get_private_settings',
    description: 'Return the private settings of a scene item.',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': false},
      {'name': 'sceneItemId', 'type': 'number', 'required': true},
    ],
    dispatch: (args, s) => s.sceneItemsGetPrivateSettings(
      sceneName: args!['sceneName'] as String?,
      sceneItemId: args['sceneItemId'] as int,
    ),
  ),
  ToolDef(
    name: 'obs_scene_items_set_private_settings',
    description: 'Set the private settings of a scene item.',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': false},
      {'name': 'sceneItemId', 'type': 'number', 'required': true},
      {'name': 'sceneItemSettings', 'type': 'object', 'required': true},
    ],
    dispatch: (args, s) => s.sceneItemsSetPrivateSettings(
      sceneName: args!['sceneName'] as String?,
      sceneItemId: args['sceneItemId'] as int,
      sceneItemSettings: args['sceneItemSettings'] as Map<String, dynamic>,
    ),
  ),
  ToolDef(
    name: 'obs_scene_items_get_index',
    description: 'Get the index position of a scene item in a scene.',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
      {'name': 'sceneItemId', 'type': 'number', 'required': true},
    ],
    dispatch: (args, s) => s.sceneItemsGetIndex(
      sceneName: args!['sceneName'] as String,
      sceneItemId: args['sceneItemId'] as int,
    ),
  ),
  ToolDef(
    name: 'obs_scene_items_set_index',
    description: 'Set the index position of a scene item in a scene.',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
      {'name': 'sceneItemId', 'type': 'number', 'required': true},
      {'name': 'sceneItemIndex', 'type': 'number', 'required': true},
    ],
    dispatch: (args, s) => s.sceneItemsSetIndex(
      sceneName: args!['sceneName'] as String,
      sceneItemId: args['sceneItemId'] as int,
      sceneItemIndex: args['sceneItemIndex'] as int,
    ),
  ),
  ToolDef(
    name: 'obs_scene_items_get_blend_mode',
    description:
        'Get the blend mode of a scene item (normal, additive, subtract, screen, multiply, lighten, darken).',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
      {'name': 'sceneItemId', 'type': 'number', 'required': true},
    ],
    dispatch: (args, s) => s.sceneItemsGetBlendMode(
      sceneName: args!['sceneName'] as String,
      sceneItemId: args['sceneItemId'] as int,
    ),
  ),
  ToolDef(
    name: 'obs_scene_items_set_blend_mode',
    description: 'Set the blend mode of a scene item.',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
      {'name': 'sceneItemId', 'type': 'number', 'required': true},
      {'name': 'sceneItemBlendMode', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.sceneItemsSetBlendMode(
      sceneName: args!['sceneName'] as String,
      sceneItemId: args['sceneItemId'] as int,
      sceneItemBlendMode: args['sceneItemBlendMode'] as String,
    ),
  ),
  ToolDef(
    name: 'obs_scene_items_animate_transform',
    description: 'Animate a scene item transform over time with easing.',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': true},
      {'name': 'sceneItemId', 'type': 'number', 'required': true},
      {'name': 'durationMs', 'type': 'number', 'required': true},
      {'name': 'targetPositionX', 'type': 'number', 'required': false},
      {'name': 'targetPositionY', 'type': 'number', 'required': false},
      {'name': 'targetScaleX', 'type': 'number', 'required': false},
      {'name': 'targetScaleY', 'type': 'number', 'required': false},
      {'name': 'targetRotation', 'type': 'number', 'required': false},
      {'name': 'frameRate', 'type': 'number', 'required': false},
      {'name': 'easing', 'type': 'string', 'required': false},
      {'name': 'restoreOnComplete', 'type': 'boolean', 'required': false},
    ],
    dispatch: (args, s) => s.sceneItemsAnimateTransform(
      sceneName: args!['sceneName'] as String,
      sceneItemId: args['sceneItemId'] as int,
      durationMs: args['durationMs'] as int,
      targetPositionX: args['targetPositionX'] as num?,
      targetPositionY: args['targetPositionY'] as num?,
      targetScaleX: args['targetScaleX'] as num?,
      targetScaleY: args['targetScaleY'] as num?,
      targetRotation: args['targetRotation'] as num?,
      frameRate: args['frameRate'] as int?,
      easing: args['easing'] as String?,
      restoreOnComplete: args['restoreOnComplete'] as bool?,
    ),
  ),

  // ========================================================================
  // Inputs
  // ========================================================================
  ToolDef(
    name: 'obs_inputs_list',
    description:
        'List all inputs in OBS. Provide inputKind to filter to a single kind.',
    parameters: [
      {'name': 'inputKind', 'type': 'string', 'required': false},
    ],
    dispatch: (args, s) =>
        s.inputsList(inputKind: args?['inputKind'] as String?),
  ),
  ToolDef(
    name: 'obs_inputs_kind_list',
    description: 'Return the list of available input kinds on this OBS.',
    parameters: [
      {'name': 'unversioned', 'type': 'boolean', 'required': false},
    ],
    dispatch: (args, s) =>
        s.inputsKindList(unversioned: args?['unversioned'] as bool?),
  ),
  ToolDef(
    name: 'obs_inputs_special',
    description: 'Return the names of OBS special inputs (mic/aux/etc.).',
    dispatch: (_, s) => s.inputsSpecial(),
  ),
  ToolDef(
    name: 'obs_inputs_get_mute',
    description: 'Return whether an input is currently muted.',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.inputsGetMute(args!['inputName'] as String),
  ),
  ToolDef(
    name: 'obs_inputs_set_mute',
    description: 'Mute or unmute an input (by name or uuid).',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
      {'name': 'inputMuted', 'type': 'boolean', 'required': true},
    ],
    dispatch: (args, s) => s.inputsSetMute(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
      inputMuted: args['inputMuted'] as bool,
    ),
  ),
  ToolDef(
    name: 'obs_inputs_toggle_mute',
    description: 'Toggle mute on an input and return the new muted state.',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
    ],
    dispatch: (args, s) => s.inputsToggleMute(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
    ),
  ),
  ToolDef(
    name: 'obs_inputs_get_volume',
    description: 'Return the volume of an input as both multiplier and dB.',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
    ],
    dispatch: (args, s) => s.inputsGetVolume(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
    ),
  ),
  ToolDef(
    name: 'obs_inputs_set_volume',
    description: 'Set the volume of an input (0.0-1.0 multiplier).',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
      {'name': 'inputVolume', 'type': 'number', 'required': true},
    ],
    dispatch: (args, s) => s.inputsSetVolume(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
      inputVolume: (args['inputVolume'] as num).toDouble(),
    ),
  ),
  ToolDef(
    name: 'obs_inputs_get_settings',
    description: 'Return the current settings payload for an input.',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
    ],
    dispatch: (args, s) => s.inputsGetSettings(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
    ),
  ),
  ToolDef(
    name: 'obs_inputs_set_settings',
    description: 'Overwrite or merge an input settings payload.',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
      {'name': 'inputSettings', 'type': 'object', 'required': true},
      {'name': 'overlay', 'type': 'boolean', 'required': false},
    ],
    dispatch: (args, s) => s.inputsSetSettings(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
      inputSettings: args['inputSettings'] as Map<String, dynamic>,
      overlay: args['overlay'] as bool?,
    ),
  ),
  ToolDef(
    name: 'obs_inputs_set_name',
    description: 'Rename an input.',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
      {'name': 'newInputName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.inputsSetName(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
      newInputName: args['newInputName'] as String,
    ),
  ),
  ToolDef(
    name: 'obs_inputs_create',
    description: 'Create a new input as a scene item inside a scene.',
    parameters: [
      {'name': 'sceneName', 'type': 'string', 'required': false},
      {'name': 'inputName', 'type': 'string', 'required': true},
      {'name': 'inputKind', 'type': 'string', 'required': true},
      {'name': 'inputSettings', 'type': 'object', 'required': false},
      {'name': 'sceneItemEnabled', 'type': 'boolean', 'required': false},
    ],
    dispatch: (args, s) => s.inputsCreate(
      sceneName: args!['sceneName'] as String?,
      inputName: args['inputName'] as String,
      inputKind: args['inputKind'] as String,
      inputSettings: args['inputSettings'] as Map<String, dynamic>?,
      sceneItemEnabled: args['sceneItemEnabled'] as bool?,
    ),
  ),
  ToolDef(
    name: 'obs_inputs_remove',
    description: 'Delete an input by name or uuid.',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
    ],
    dispatch: (args, s) => s.inputsRemove(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
    ),
  ),
  ToolDef(
    name: 'obs_inputs_get_default_settings',
    description: 'Return the default settings for a given input kind.',
    parameters: [
      {'name': 'inputKind', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) =>
        s.inputsGetDefaultSettings(inputKind: args!['inputKind'] as String),
  ),
  ToolDef(
    name: 'obs_inputs_get_audio_balance',
    description: 'Return the audio balance (left-right) of an input.',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
    ],
    dispatch: (args, s) => s.inputsGetAudioBalance(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
    ),
  ),
  ToolDef(
    name: 'obs_inputs_set_audio_balance',
    description:
        'Set the audio balance of an input (0.0 = left, 1.0 = right, 0.5 = center).',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
      {'name': 'inputAudioBalance', 'type': 'number', 'required': true},
    ],
    dispatch: (args, s) => s.inputsSetAudioBalance(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
      inputAudioBalance: (args['inputAudioBalance'] as num).toDouble(),
    ),
  ),
  ToolDef(
    name: 'obs_inputs_get_audio_sync_offset',
    description: 'Return the audio sync offset of an input in milliseconds.',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
    ],
    dispatch: (args, s) => s.inputsGetAudioSyncOffset(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
    ),
  ),
  ToolDef(
    name: 'obs_inputs_set_audio_sync_offset',
    description: 'Set the audio sync offset of an input in milliseconds.',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
      {'name': 'inputAudioSyncOffset', 'type': 'number', 'required': true},
    ],
    dispatch: (args, s) => s.inputsSetAudioSyncOffset(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
      inputAudioSyncOffset: args['inputAudioSyncOffset'] as int,
    ),
  ),
  ToolDef(
    name: 'obs_inputs_get_audio_monitor_type',
    description:
        'Return the audio monitor type of an input (none, monitor only, monitor and output).',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
    ],
    dispatch: (args, s) => s.inputsGetAudioMonitorType(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
    ),
  ),
  ToolDef(
    name: 'obs_inputs_set_audio_monitor_type',
    description:
        'Set the audio monitor type of an input (0 = none, 1 = monitor only, 2 = monitor and output).',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
      {'name': 'monitorType', 'type': 'number', 'required': true},
    ],
    dispatch: (args, s) => s.inputsSetAudioMonitorType(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
      monitorType: args['monitorType'] as int,
    ),
  ),
  ToolDef(
    name: 'obs_inputs_get_audio_tracks',
    description: 'Return the audio track bitmask of an input.',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
    ],
    dispatch: (args, s) => s.inputsGetAudioTracks(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
    ),
  ),
  ToolDef(
    name: 'obs_inputs_set_audio_tracks',
    description:
        'Set the audio tracks of an input (bitmask: 1=track1, 2=track2, 4=track3, etc.).',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
      {'name': 'inputAudioTracks', 'type': 'number', 'required': true},
    ],
    dispatch: (args, s) => s.inputsSetAudioTracks(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
      inputAudioTracks: args['inputAudioTracks'] as int,
    ),
  ),
  ToolDef(
    name: 'obs_inputs_get_deinterlace_mode',
    description: 'Return the deinterlace mode of an input.',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
    ],
    dispatch: (args, s) => s.inputsGetDeinterlaceMode(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
    ),
  ),
  ToolDef(
    name: 'obs_inputs_set_deinterlace_mode',
    description:
        'Set the deinterlace mode of an input (disable, discard, retro, blend, etc.).',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
      {'name': 'mode', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.inputsSetDeinterlaceMode(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
      deinterlaceMode: args['mode'] as String,
    ),
  ),
  ToolDef(
    name: 'obs_inputs_get_deinterlace_field_order',
    description: 'Return the deinterlace field order of an input.',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
    ],
    dispatch: (args, s) => s.inputsGetDeinterlaceFieldOrder(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
    ),
  ),
  ToolDef(
    name: 'obs_inputs_set_deinterlace_field_order',
    description: 'Set the deinterlace field order of an input (top, bottom).',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
      {'name': 'fieldOrder', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.inputsSetDeinterlaceFieldOrder(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
      deinterlaceFieldOrder: args['fieldOrder'] as String,
    ),
  ),
  ToolDef(
    name: 'obs_inputs_get_properties_list_items',
    description:
        "Return the items of a list property from an input's properties dialog.",
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
      {'name': 'propertyName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.inputsGetPropertiesListItems(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
      propertyName: args['propertyName'] as String,
    ),
  ),
  ToolDef(
    name: 'obs_inputs_press_properties_button',
    description: "Press a button property in an input's properties dialog.",
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
      {'name': 'propertyName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.inputsPressPropertiesButton(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
      propertyName: args['propertyName'] as String,
    ),
  ),

  // ========================================================================
  // Stream
  // ========================================================================
  ToolDef(
    name: 'obs_stream_status',
    description: 'Return the current streaming status.',
    dispatch: (_, s) => s.streamStatus(),
  ),
  ToolDef(
    name: 'obs_stream_start',
    description: 'Start the active streaming output.',
    dispatch: (_, s) => s.streamStart(),
  ),
  ToolDef(
    name: 'obs_stream_stop',
    description: 'Stop the active streaming output.',
    dispatch: (_, s) => s.streamStop(),
  ),
  ToolDef(
    name: 'obs_stream_toggle',
    description: 'Toggle streaming. Returns the resulting active state.',
    dispatch: (_, s) => s.streamToggle(),
  ),
  ToolDef(
    name: 'obs_stream_send_caption',
    description: 'Send a caption line to the active stream.',
    parameters: [
      {'name': 'captionText', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.streamSendCaption(args!['captionText'] as String),
  ),

  // ========================================================================
  // Record
  // ========================================================================
  ToolDef(
    name: 'obs_record_status',
    description: 'Return the current recording status.',
    dispatch: (_, s) => s.recordStatus(),
  ),
  ToolDef(
    name: 'obs_record_start',
    description: 'Start a new recording.',
    dispatch: (_, s) => s.recordStart(),
  ),
  ToolDef(
    name: 'obs_record_stop',
    description:
        'Stop the current recording and return the resulting file path.',
    dispatch: (_, s) => s.recordStop(),
  ),
  ToolDef(
    name: 'obs_record_toggle',
    description: 'Toggle recording on/off.',
    dispatch: (_, s) => s.recordToggle(),
  ),
  ToolDef(
    name: 'obs_record_pause',
    description: 'Pause the active recording.',
    dispatch: (_, s) => s.recordPause(),
  ),
  ToolDef(
    name: 'obs_record_resume',
    description: 'Resume a paused recording.',
    dispatch: (_, s) => s.recordResume(),
  ),
  ToolDef(
    name: 'obs_record_toggle_pause',
    description: 'Toggle pause state of the active recording.',
    dispatch: (_, s) => s.recordTogglePause(),
  ),
  ToolDef(
    name: 'obs_record_split_file',
    description: 'Split the current recording file into a new file.',
    dispatch: (_, s) => s.recordSplitFile(),
  ),
  ToolDef(
    name: 'obs_record_create_chapter',
    description: 'Add a new chapter marker to the current recording file.',
    parameters: [
      {'name': 'chapterName', 'type': 'string', 'required': false},
    ],
    dispatch: (args, s) =>
        s.recordCreateChapter(chapterName: args!['chapterName'] as String?),
  ),

  // ========================================================================
  // Outputs
  // ========================================================================
  ToolDef(
    name: 'obs_outputs_list',
    description: 'Return the list of all available outputs in OBS.',
    dispatch: (_, s) => s.outputsList(),
  ),
  ToolDef(
    name: 'obs_outputs_get_status',
    description: 'Return the status of a named output.',
    parameters: [
      {'name': 'outputName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.outputsGetStatus(args!['outputName'] as String),
  ),
  ToolDef(
    name: 'obs_outputs_get_settings',
    description: 'Return the settings of a named output.',
    parameters: [
      {'name': 'outputName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.outputsGetSettings(args!['outputName'] as String),
  ),
  ToolDef(
    name: 'obs_outputs_set_settings',
    description: 'Set the settings of a named output.',
    parameters: [
      {'name': 'outputName', 'type': 'string', 'required': true},
      {'name': 'outputSettings', 'type': 'object', 'required': true},
    ],
    dispatch: (args, s) => s.outputsSetSettings(
      outputName: args!['outputName'] as String,
      outputSettings: args['outputSettings'] as Map<String, dynamic>,
    ),
  ),
  ToolDef(
    name: 'obs_outputs_virtual_cam_status',
    description: 'Return whether the virtual camera output is active.',
    dispatch: (_, s) => s.outputsVirtualCamStatus(),
  ),
  ToolDef(
    name: 'obs_outputs_virtual_cam_toggle',
    description: 'Toggle the virtual camera output. Returns new state.',
    dispatch: (_, s) => s.outputsVirtualCamToggle(),
  ),
  ToolDef(
    name: 'obs_outputs_virtual_cam_start',
    description: 'Start the virtual camera output.',
    dispatch: (_, s) => s.outputsVirtualCamStart(),
  ),
  ToolDef(
    name: 'obs_outputs_virtual_cam_stop',
    description: 'Stop the virtual camera output.',
    dispatch: (_, s) => s.outputsVirtualCamStop(),
  ),
  ToolDef(
    name: 'obs_outputs_replay_buffer_status',
    description: 'Return whether the replay buffer is currently active.',
    dispatch: (_, s) => s.outputsReplayBufferStatus(),
  ),
  ToolDef(
    name: 'obs_outputs_replay_buffer_toggle',
    description: 'Toggle the replay buffer. Returns the new active state.',
    dispatch: (_, s) => s.outputsReplayBufferToggle(),
  ),
  ToolDef(
    name: 'obs_outputs_replay_buffer_start',
    description: 'Start the replay buffer.',
    parameters: [
      {'name': 'outputName', 'type': 'string', 'required': false},
    ],
    dispatch: (args, s) =>
        s.outputsReplayBufferStart(outputName: args!['outputName'] as String?),
  ),
  ToolDef(
    name: 'obs_outputs_replay_buffer_stop',
    description: 'Stop the replay buffer.',
    parameters: [
      {'name': 'outputName', 'type': 'string', 'required': false},
    ],
    dispatch: (args, s) =>
        s.outputsReplayBufferStop(outputName: args!['outputName'] as String?),
  ),
  ToolDef(
    name: 'obs_outputs_replay_buffer_save',
    description: 'Flush the replay buffer contents to a replay file.',
    parameters: [
      {'name': 'outputName', 'type': 'string', 'required': false},
    ],
    dispatch: (args, s) =>
        s.outputsReplayBufferSave(outputName: args!['outputName'] as String?),
  ),
  ToolDef(
    name: 'obs_outputs_toggle',
    description: 'Toggle a named OBS output. Returns the new active state.',
    parameters: [
      {'name': 'outputName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.outputsToggle(args!['outputName'] as String),
  ),
  ToolDef(
    name: 'obs_outputs_start',
    description: 'Start a named OBS output.',
    parameters: [
      {'name': 'outputName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.outputsStart(args!['outputName'] as String),
  ),
  ToolDef(
    name: 'obs_outputs_stop',
    description: 'Stop a named OBS output.',
    parameters: [
      {'name': 'outputName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.outputsStop(args!['outputName'] as String),
  ),

  // ========================================================================
  // Config
  // ========================================================================
  ToolDef(
    name: 'obs_config_record_directory',
    description: 'Return the current recording directory.',
    dispatch: (_, s) => s.configRecordDirectory(),
  ),
  ToolDef(
    name: 'obs_config_stream_service_settings',
    description: 'Return the active streaming service name + settings.',
    dispatch: (_, s) => s.configStreamServiceSettings(),
  ),
  ToolDef(
    name: 'obs_config_get_persistent_data',
    description: 'Get the value of a data slot from persistent storage.',
    parameters: [
      {'name': 'realm', 'type': 'string', 'required': true},
      {'name': 'slotName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.configGetPersistentData(
      realm: args!['realm'] as String,
      slotName: args['slotName'] as String,
    ),
  ),
  ToolDef(
    name: 'obs_config_set_persistent_data',
    description: 'Set the value of a data slot in persistent storage.',
    parameters: [
      {'name': 'realm', 'type': 'string', 'required': true},
      {'name': 'slotName', 'type': 'string', 'required': true},
      {'name': 'slotValue', 'type': 'object', 'required': true},
    ],
    dispatch: (args, s) => s.configSetPersistentData(
      realm: args!['realm'] as String,
      slotName: args['slotName'] as String,
      slotValue: args['slotValue'],
    ),
  ),
  ToolDef(
    name: 'obs_config_scene_collection_list',
    description: 'Get a list of all scene collections.',
    dispatch: (_, s) => s.configSceneCollectionList(),
  ),
  ToolDef(
    name: 'obs_config_set_current_scene_collection',
    description: 'Switch to a given scene collection by name.',
    parameters: [
      {'name': 'sceneCollectionName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.configSetCurrentSceneCollection(
      args!['sceneCollectionName'] as String,
    ),
  ),
  ToolDef(
    name: 'obs_config_create_scene_collection',
    description: 'Create a new scene collection and switch to it.',
    parameters: [
      {'name': 'sceneCollectionName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) =>
        s.configCreateSceneCollection(args!['sceneCollectionName'] as String),
  ),
  ToolDef(
    name: 'obs_config_profile_list',
    description: 'Get a list of all profiles.',
    dispatch: (_, s) => s.configProfileList(),
  ),
  ToolDef(
    name: 'obs_config_set_current_profile',
    description: 'Switch to a given profile by name.',
    parameters: [
      {'name': 'profileName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) =>
        s.configSetCurrentProfile(args!['profileName'] as String),
  ),
  ToolDef(
    name: 'obs_config_create_profile',
    description: 'Create a new profile and switch to it.',
    parameters: [
      {'name': 'profileName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) =>
        s.configCreateProfile(args!['profileName'] as String),
  ),
  ToolDef(
    name: 'obs_config_remove_profile',
    description: 'Remove a profile from OBS.',
    parameters: [
      {'name': 'profileName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) =>
        s.configRemoveProfile(args!['profileName'] as String),
  ),
  ToolDef(
    name: 'obs_config_get_profile_parameter',
    description:
        'Get a parameter value from the current profile configuration.',
    parameters: [
      {'name': 'parameterCategory', 'type': 'string', 'required': true},
      {'name': 'parameterName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.configGetProfileParameter(
      parameterCategory: args!['parameterCategory'] as String,
      parameterName: args['parameterName'] as String,
    ),
  ),
  ToolDef(
    name: 'obs_config_set_profile_parameter',
    description: 'Set a parameter value in the current profile configuration.',
    parameters: [
      {'name': 'parameterCategory', 'type': 'string', 'required': true},
      {'name': 'parameterName', 'type': 'string', 'required': true},
      {'name': 'parameterValue', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.configSetProfileParameter(
      parameterCategory: args!['parameterCategory'] as String,
      parameterName: args['parameterName'] as String,
      parameterValue: args['parameterValue'] as String,
    ),
  ),
  ToolDef(
    name: 'obs_config_set_video_settings',
    description:
        'Set the current video settings (base resolution, output resolution, FPS).',
    parameters: [
      {'name': 'fpsNumerator', 'type': 'number', 'required': false},
      {'name': 'fpsDenominator', 'type': 'number', 'required': false},
      {'name': 'baseWidth', 'type': 'number', 'required': false},
      {'name': 'baseHeight', 'type': 'number', 'required': false},
      {'name': 'outputWidth', 'type': 'number', 'required': false},
      {'name': 'outputHeight', 'type': 'number', 'required': false},
    ],
    dispatch: (args, s) => s.configSetVideoSettings(
      VideoSettings(
        fpsNumerator: args!['fpsNumerator'] as int?,
        fpsDenominator: args['fpsDenominator'] as int?,
        baseWidth: args['baseWidth'] as int?,
        baseHeight: args['baseHeight'] as int?,
        outputWidth: args['outputWidth'] as int?,
        outputHeight: args['outputHeight'] as int?,
      ),
    ),
  ),
  ToolDef(
    name: 'obs_config_set_stream_service_settings',
    description: 'Set the stream service settings (stream destination).',
    parameters: [
      {'name': 'streamServiceType', 'type': 'string', 'required': true},
      {'name': 'streamServiceSettings', 'type': 'object', 'required': true},
    ],
    dispatch: (args, s) => s.configSetStreamServiceSettings(
      streamServiceType: args!['streamServiceType'] as String,
      streamServiceSettings:
          args['streamServiceSettings'] as Map<String, dynamic>,
    ),
  ),
  ToolDef(
    name: 'obs_config_set_record_directory',
    description: 'Set the directory that the record output writes files to.',
    parameters: [
      {'name': 'recordDirectory', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) =>
        s.configSetRecordDirectory(args!['recordDirectory'] as String),
  ),

  // ========================================================================
  // UI
  // ========================================================================
  ToolDef(
    name: 'obs_ui_studio_mode_enabled',
    description: 'Return whether OBS studio mode is currently enabled.',
    dispatch: (_, s) => s.uiStudioModeEnabled(),
  ),
  ToolDef(
    name: 'obs_ui_set_studio_mode',
    description: 'Enable or disable OBS studio mode.',
    parameters: [
      {'name': 'enabled', 'type': 'boolean', 'required': true},
    ],
    dispatch: (args, s) => s.uiSetStudioMode(args!['enabled'] as bool),
  ),
  ToolDef(
    name: 'obs_ui_open_input_properties',
    description:
        'Open the properties dialog window in the OBS UI for the given input.',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) =>
        s.uiOpenInputProperties(args!['inputName'] as String),
  ),
  ToolDef(
    name: 'obs_ui_open_input_filters',
    description: 'Open the filters dialog in the OBS UI for the given input.',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.uiOpenInputFilters(args!['inputName'] as String),
  ),
  ToolDef(
    name: 'obs_ui_open_input_interact',
    description: 'Open the interact dialog in the OBS UI for the given input.',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.uiOpenInputInteract(args!['inputName'] as String),
  ),
  ToolDef(
    name: 'obs_ui_monitor_list',
    description: 'Return the list of connected monitors.',
    dispatch: (_, s) => s.uiMonitorList(),
  ),
  ToolDef(
    name: 'obs_ui_open_video_mix_projector',
    description:
        'Open a projector for a video mix (Preview, Program, Multiview).',
    parameters: [
      {'name': 'videoMixType', 'type': 'string', 'required': true},
      {'name': 'monitorIndex', 'type': 'number', 'required': false},
      {'name': 'projectorGeometry', 'type': 'string', 'required': false},
    ],
    dispatch: (args, s) => s.uiOpenVideoMixProjector(
      args!['videoMixType'] as String,
      monitorIndex: args['monitorIndex'] as int?,
      projectorGeometry: args['projectorGeometry'] as String?,
    ),
  ),
  ToolDef(
    name: 'obs_ui_open_source_projector',
    description: 'Open a projector for a source.',
    parameters: [
      {'name': 'sourceName', 'type': 'string', 'required': true},
      {'name': 'monitorIndex', 'type': 'number', 'required': false},
      {'name': 'projectorGeometry', 'type': 'string', 'required': false},
    ],
    dispatch: (args, s) => s.uiOpenSourceProjector(
      args!['sourceName'] as String,
      monitorIndex: args['monitorIndex'] as int?,
      projectorGeometry: args['projectorGeometry'] as String?,
    ),
  ),

  // ========================================================================
  // Transitions
  // ========================================================================
  ToolDef(
    name: 'obs_transitions_trigger_studio',
    description:
        'Trigger the studio-mode transition from the preview scene to program.',
    dispatch: (_, s) => s.transitionsTriggerStudio(),
  ),
  ToolDef(
    name: 'obs_transitions_kind_list',
    description: 'Return the list of all available transition kinds.',
    dispatch: (_, s) => s.transitionsKindList(),
  ),
  ToolDef(
    name: 'obs_transitions_scene_list',
    description: 'Return the list of all scene transitions configured in OBS.',
    dispatch: (_, s) => s.transitionsSceneList(),
  ),
  ToolDef(
    name: 'obs_transitions_get_current',
    description: 'Return information about the current scene transition.',
    dispatch: (_, s) => s.transitionsGetCurrent(),
  ),
  ToolDef(
    name: 'obs_transitions_set_current',
    description: 'Set the current scene transition by name.',
    parameters: [
      {'name': 'transitionName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) =>
        s.transitionsSetCurrent(args!['transitionName'] as String),
  ),
  ToolDef(
    name: 'obs_transitions_set_duration',
    description:
        'Set the duration of the current scene transition in milliseconds.',
    parameters: [
      {'name': 'duration', 'type': 'number', 'required': true},
    ],
    dispatch: (args, s) => s.transitionsSetDuration(args!['duration'] as int),
  ),
  ToolDef(
    name: 'obs_transitions_get_cursor',
    description:
        'Return the cursor position (0.0-1.0) of the current scene transition.',
    dispatch: (_, s) => s.transitionsGetCursor(),
  ),
  ToolDef(
    name: 'obs_transitions_set_settings',
    description: 'Set the settings of the current scene transition.',
    parameters: [
      {'name': 'transitionSettings', 'type': 'object', 'required': true},
      {'name': 'overlay', 'type': 'boolean', 'required': false},
    ],
    dispatch: (args, s) => s.transitionsSetSettings(
      transitionSettings: args!['transitionSettings'] as Map<String, dynamic>,
      overlay: args['overlay'] as bool?,
    ),
  ),
  ToolDef(
    name: 'obs_transitions_set_t_bar',
    description: 'Set the T-Bar position (0.0-1.0). Requires Studio Mode.',
    parameters: [
      {'name': 'position', 'type': 'number', 'required': true},
      {'name': 'release', 'type': 'boolean', 'required': false},
    ],
    dispatch: (args, s) => s.transitionsSetTBar(
      position: (args!['position'] as num).toDouble(),
      release: args['release'] as bool?,
    ),
  ),

  // ========================================================================
  // Sources
  // ========================================================================
  ToolDef(
    name: 'obs_sources_get_active',
    description:
        'Return whether a source is active (shown in preview/program) and visible.',
    parameters: [
      {'name': 'sourceName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.sourcesGetActive(args!['sourceName'] as String),
  ),
  ToolDef(
    name: 'obs_sources_get_screenshot',
    description: 'Get a Base64-encoded screenshot of a source.',
    parameters: [
      {'name': 'sourceName', 'type': 'string', 'required': true},
      {'name': 'imageFormat', 'type': 'string', 'required': true},
      {'name': 'imageWidth', 'type': 'number', 'required': false},
      {'name': 'imageHeight', 'type': 'number', 'required': false},
      {'name': 'imageCompressionQuality', 'type': 'number', 'required': false},
    ],
    dispatch: (args, s) => s.sourcesGetScreenshot(
      sourceName: args!['sourceName'] as String,
      imageFormat: args['imageFormat'] as String,
      imageWidth: args['imageWidth'] as int?,
      imageHeight: args['imageHeight'] as int?,
      compressionQuality: args['imageCompressionQuality'] as int?,
    ),
  ),
  ToolDef(
    name: 'obs_sources_save_screenshot',
    description:
        'Save a screenshot of a source to a file path on the filesystem.',
    parameters: [
      {'name': 'sourceName', 'type': 'string', 'required': true},
      {'name': 'filePath', 'type': 'string', 'required': true},
      {'name': 'imageFormat', 'type': 'string', 'required': true},
      {'name': 'imageWidth', 'type': 'number', 'required': false},
      {'name': 'imageHeight', 'type': 'number', 'required': false},
      {'name': 'imageCompressionQuality', 'type': 'number', 'required': false},
    ],
    dispatch: (args, s) => s.sourcesSaveScreenshot(
      sourceName: args!['sourceName'] as String,
      filePath: args['filePath'] as String,
      imageFormat: args['imageFormat'] as String,
      imageWidth: args['imageWidth'] as int?,
      imageHeight: args['imageHeight'] as int?,
      compressionQuality: args['imageCompressionQuality'] as int?,
    ),
  ),
  ToolDef(
    name: 'obs_sources_get_private_settings',
    description: 'Return the private settings of a source.',
    parameters: [
      {'name': 'sourceName', 'type': 'string', 'required': false},
      {'name': 'sourceUuid', 'type': 'string', 'required': false},
    ],
    dispatch: (args, s) => s.sourcesGetPrivateSettings(
      sourceName: args!['sourceName'] as String?,
      sourceUuid: args['sourceUuid'] as String?,
    ),
  ),
  ToolDef(
    name: 'obs_sources_set_private_settings',
    description: 'Set the private settings of a source.',
    parameters: [
      {'name': 'sourceName', 'type': 'string', 'required': false},
      {'name': 'sourceUuid', 'type': 'string', 'required': false},
      {'name': 'sourceSettings', 'type': 'object', 'required': true},
    ],
    dispatch: (args, s) => s.sourcesSetPrivateSettings(
      sourceName: args!['sourceName'] as String?,
      sourceUuid: args['sourceUuid'] as String?,
      sourceSettings: args['sourceSettings'] as Map<String, dynamic>,
    ),
  ),

  // ========================================================================
  // Media Inputs
  // ========================================================================
  ToolDef(
    name: 'obs_media_inputs_get_status',
    description:
        'Return the status of a media input (state, duration, cursor, etc.).',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
    ],
    dispatch: (args, s) => s.mediaInputsGetStatus(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
    ),
  ),
  ToolDef(
    name: 'obs_media_inputs_set_cursor',
    description: 'Set the cursor position (in milliseconds) of a media input.',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
      {'name': 'mediaCursor', 'type': 'number', 'required': true},
    ],
    dispatch: (args, s) => s.mediaInputsSetCursor(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
      mediaCursor: args['mediaCursor'] as int,
    ),
  ),
  ToolDef(
    name: 'obs_media_inputs_offset_cursor',
    description:
        'Offset the current cursor position of a media input by the specified milliseconds.',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
      {'name': 'mediaCursorOffset', 'type': 'number', 'required': true},
    ],
    dispatch: (args, s) => s.mediaInputsOffsetCursor(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
      mediaCursorOffset: args['mediaCursorOffset'] as int,
    ),
  ),
  ToolDef(
    name: 'obs_media_inputs_trigger_action',
    description:
        'Trigger an action on a media input (play, pause, stop, restart, next, previous).',
    parameters: [
      {'name': 'inputName', 'type': 'string', 'required': false},
      {'name': 'inputUuid', 'type': 'string', 'required': false},
      {'name': 'mediaAction', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.mediaInputsTriggerAction(
      inputName: args!['inputName'] as String?,
      inputUuid: args['inputUuid'] as String?,
      mediaAction: args['mediaAction'] as String,
    ),
  ),

  // ========================================================================
  // Filters
  // ========================================================================
  ToolDef(
    name: 'obs_filters_kind_list',
    description: 'Return the list of all available source filter kinds.',
    dispatch: (_, s) => s.filtersKindList(),
  ),
  ToolDef(
    name: 'obs_filters_list',
    description: 'Return the list of filters applied to a source.',
    parameters: [
      {'name': 'sourceName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.filtersList(args!['sourceName'] as String),
  ),
  ToolDef(
    name: 'obs_filters_default_settings',
    description: 'Return the default settings for a given filter kind.',
    parameters: [
      {'name': 'filterKind', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) =>
        s.filtersDefaultSettings(args!['filterKind'] as String),
  ),
  ToolDef(
    name: 'obs_filters_create',
    description: 'Create a new filter and apply it to a source.',
    parameters: [
      {'name': 'sourceName', 'type': 'string', 'required': true},
      {'name': 'filterName', 'type': 'string', 'required': true},
      {'name': 'filterKind', 'type': 'string', 'required': true},
      {'name': 'filterSettings', 'type': 'object', 'required': false},
    ],
    dispatch: (args, s) => s.filtersCreate(
      sourceName: args!['sourceName'] as String,
      filterName: args['filterName'] as String,
      filterKind: args['filterKind'] as String,
      filterSettings: args['filterSettings'] as Map<String, dynamic>?,
    ),
  ),
  ToolDef(
    name: 'obs_filters_get',
    description: 'Return information about a specific filter on a source.',
    parameters: [
      {'name': 'sourceName', 'type': 'string', 'required': true},
      {'name': 'filterName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.filtersGet(
      sourceName: args!['sourceName'] as String,
      filterName: args['filterName'] as String,
    ),
  ),
  ToolDef(
    name: 'obs_filters_remove',
    description: 'Remove a filter from a source.',
    parameters: [
      {'name': 'sourceName', 'type': 'string', 'required': true},
      {'name': 'filterName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.filtersRemove(
      sourceName: args!['sourceName'] as String,
      filterName: args['filterName'] as String,
    ),
  ),
  ToolDef(
    name: 'obs_filters_rename',
    description: 'Rename a filter on a source.',
    parameters: [
      {'name': 'sourceName', 'type': 'string', 'required': true},
      {'name': 'filterName', 'type': 'string', 'required': true},
      {'name': 'newFilterName', 'type': 'string', 'required': true},
    ],
    dispatch: (args, s) => s.filtersRename(
      sourceName: args!['sourceName'] as String,
      filterName: args['filterName'] as String,
      newFilterName: args['newFilterName'] as String,
    ),
  ),
  ToolDef(
    name: 'obs_filters_set_enabled',
    description: 'Enable or disable a filter on a source.',
    parameters: [
      {'name': 'sourceName', 'type': 'string', 'required': true},
      {'name': 'filterName', 'type': 'string', 'required': true},
      {'name': 'filterEnabled', 'type': 'boolean', 'required': true},
    ],
    dispatch: (args, s) => s.filtersSetEnabled(
      sourceName: args!['sourceName'] as String,
      filterName: args['filterName'] as String,
      filterEnabled: args['filterEnabled'] as bool,
    ),
  ),
  ToolDef(
    name: 'obs_filters_set_index',
    description: 'Set the index position (order) of a filter on a source.',
    parameters: [
      {'name': 'sourceName', 'type': 'string', 'required': true},
      {'name': 'filterName', 'type': 'string', 'required': true},
      {'name': 'filterIndex', 'type': 'number', 'required': true},
    ],
    dispatch: (args, s) => s.filtersSetIndex(
      sourceName: args!['sourceName'] as String,
      filterName: args['filterName'] as String,
      filterIndex: args['filterIndex'] as int,
    ),
  ),
  ToolDef(
    name: 'obs_filters_set_settings',
    description: 'Set or merge the settings of a filter on a source.',
    parameters: [
      {'name': 'sourceName', 'type': 'string', 'required': true},
      {'name': 'filterName', 'type': 'string', 'required': true},
      {'name': 'filterSettings', 'type': 'object', 'required': true},
      {'name': 'overlay', 'type': 'boolean', 'required': false},
    ],
    dispatch: (args, s) => s.filtersSetSettings(
      sourceName: args!['sourceName'] as String,
      filterName: args['filterName'] as String,
      filterSettings: args['filterSettings'] as Map<String, dynamic>,
      overlay: args['overlay'] as bool?,
    ),
  ),

  // ========================================================================
  // Canvases
  // ========================================================================
  ToolDef(
    name: 'obs_canvases_list',
    description: 'Return the list of all canvases configured in OBS (v5.7.0+).',
    dispatch: (_, s) => s.canvasesList(),
  ),
  ToolDef(
    name: 'obs_video_settings',
    description:
        'Return base/output canvas dimensions and FPS via the legacy GetVideoSettings request.',
    dispatch: (_, s) => s.videoSettings(),
  ),

  // ========================================================================
  // Events
  // ========================================================================
  ToolDef(
    name: 'obs_events_subscribe',
    description: 'Update the active OBS event subscription mask.',
    parameters: [
      {'name': 'mask', 'type': 'number', 'required': false},
      {'name': 'subscriptions', 'type': 'array', 'required': false},
    ],
    dispatch: (args, s) => s.eventsSubscribe(
      mask: args!['mask'] as int?,
      subscriptions: (args['subscriptions'] as List?)?.cast<String>(),
    ),
  ),
  ToolDef(
    name: 'obs_wait_for_event',
    description: 'Wait for the next OBS event matching the given type.',
    parameters: [
      {'name': 'eventType', 'type': 'string', 'required': true},
      {'name': 'timeoutMs', 'type': 'number', 'required': false},
    ],
    dispatch: (args, s) => s.waitForEvent(
      eventType: args!['eventType'] as String,
      timeoutMs: args['timeoutMs'] as int?,
    ),
  ),

  // ========================================================================
  // Utility
  // ========================================================================
  ToolDef(
    name: 'obs_client_sleep',
    description: 'Pause server-side for milliseconds (1-25000).',
    parameters: [
      {'name': 'ms', 'type': 'number', 'required': true},
    ],
    dispatch: (args, s) => s.clientSleep(ms: args!['ms'] as int),
  ),
];
