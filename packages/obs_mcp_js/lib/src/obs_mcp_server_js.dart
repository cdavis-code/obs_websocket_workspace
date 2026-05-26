/// JS-adapted MCP facade for the OBS WebSocket client.
///
/// Port of `packages/obs_mcp/lib/src/obs_mcp_server.dart` with dart:io replaced
/// by Node.js process.env via dart:js_interop. File system operations removed.
/// All tool handler methods use the same obs_websocket API calls as the original.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:obs_websocket/event.dart';
import 'package:obs_websocket/obs_websocket.dart';

import 'animation_helpers.dart';
import 'node_interop.dart';
import 'tool_registry.dart';

/// Dispatch function signature for tool handlers.
/// Receives the raw arguments map (from the MCP request) and an [ObsMcpServer]
/// instance to call methods on.
typedef ToolDispatchFn =
    FutureOr<dynamic> Function(Map<String, dynamic>? args, ObsMcpServer server);

/// Registry entry that pairs tool metadata with its dispatch handler.
///
/// Every OBS WebSocket tool is defined here. The [MCPServerWithToolsJs] in
/// `obs_mcp_server_js.mcp.dart` pulls specs and dispatch from this registry.
class ToolDef {
  final String name;
  final String description;
  final List<Map<String, dynamic>> parameters;
  final ToolDispatchFn dispatch;

  ToolDef({
    required this.name,
    required this.description,
    this.parameters = const [],
    required this.dispatch,
  });

  Map<String, dynamic> toSpec() => <String, dynamic>{
    'name': name,
    'description': description,
    'parameters': parameters,
  };
}

/// Unified MCP facade exposing the OBS WebSocket v5 protocol as tools.
class ObsMcpServer {
  static const String envUrl = 'OBS_WEBSOCKET_URL';
  static const String envPassword = 'OBS_WEBSOCKET_PASSWORD';
  static const String envTimeout = 'OBS_WEBSOCKET_TIMEOUT';

  static ObsWebSocket? _client;
  static String? _bootstrapError;

  /// Single source of truth for all tool definitions.
  /// Consumed by [MCPServerWithToolsJs] in `obs_mcp_server_js.mcp.dart`.
  static final List<ToolDef> toolDefs = buildRegistry();

  static const Map<String, dynamic> _ok = <String, dynamic>{'ok': true};

  static ObsWebSocket get _obs {
    final client = _client;
    if (client == null) {
      final errorContext = _bootstrapError != null
          ? ' Last attempt failed: $_bootstrapError'
          : '';
      throw StateError(
        'Not connected to OBS. Set $envUrl (and optionally $envPassword) in '
        'the environment, or call obs_connect(url, password).'
        '$errorContext',
      );
    }
    return client;
  }

  // ---------------------------------------------------------------------------
  // Environment bootstrap (JS version — no dotenv file loading)
  // ---------------------------------------------------------------------------

  static bool get _debugEnabled {
    final val = getEnvVar('OBS_MCP_DEBUG');
    return val == '1';
  }

  static void _debugLog(String message) {
    if (_debugEnabled) {
      logError('[obs-mcp-js] $message');
    }
  }

  static Future<void> bootstrapFromEnv() async {
    if (_client != null) return;

    final url = getEnvVar(envUrl);
    _debugLog('bootstrapFromEnv: url=${url != null ? "(set)" : "(null)"}');
    if (url == null || url.isEmpty) return;

    final password = getEnvVar(envPassword);
    final timeoutSeconds = int.tryParse(getEnvVar(envTimeout) ?? '') ?? 120;

    try {
      _client = await ObsWebSocket.connect(
        url,
        password: password,
        timeout: Duration(seconds: timeoutSeconds),
        autoReconnect: true,
      );
      _bootstrapError = null;
      _debugLog('bootstrapFromEnv: Connected to OBS successfully');
    } on ObsAuthenticationException catch (error) {
      _bootstrapError = 'Authentication failed: ${error.message}';
      _debugLog('ERROR: bootstrapFromEnv: $_bootstrapError');
    } on ObsException catch (error) {
      _bootstrapError = 'Connect failed: ${error.message}';
      _debugLog('ERROR: bootstrapFromEnv: $_bootstrapError');
    } on Object catch (error) {
      _bootstrapError = 'Connect failed: $error';
      _debugLog('ERROR: bootstrapFromEnv: $_bootstrapError');
    }
  }

  // ---------------------------------------------------------------------------
  // Connection lifecycle
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> connect({
    required String url,
    String? password,
    int? timeoutSeconds,
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

  Future<Map<String, dynamic>> disconnect() async {
    await _client?.close();
    _client = null;
    return _ok;
  }

  Map<String, dynamic> isConnected() {
    return <String, dynamic>{'connected': _client != null};
  }

  // ---------------------------------------------------------------------------
  // Connection status & ping
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Raw request
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> sendRaw({
    required String requestType,
    dynamic requestData,
  }) async {
    final response = await _obs.send(requestType, requestData);
    if (response != null) return response.toJson();
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // General
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> generalVersion() async {
    final version = await _obs.general.getVersion();
    return version.toJson();
  }

  Future<Map<String, dynamic>> generalStats() async {
    final stats = await _obs.general.getStats();
    return stats.toJson();
  }

  Future<List<String>> generalHotkeys() async {
    return _obs.general.getHotkeyList();
  }

  Future<Map<String, dynamic>> generalTriggerHotkey(String hotkeyName) async {
    await _obs.general.triggerHotkeyByName(hotkeyName);
    return _ok;
  }

  Future<Map<String, dynamic>> generalSleep({
    int? sleepMillis,
    int? sleepFrames,
  }) async {
    await _obs.general.sleep(
      sleepMillis: sleepMillis,
      sleepFrames: sleepFrames,
    );
    return _ok;
  }

  Future<Map<String, dynamic>> generalBroadcastCustomEvent(
    dynamic eventData,
  ) async {
    await _obs.general.broadcastCustomEvent(
      eventData is Map<String, dynamic>
          ? eventData
          : jsonDecode(jsonEncode(eventData)) as Map<String, dynamic>,
    );
    return _ok;
  }

  Future<Map<String, dynamic>> generalCallVendorRequest({
    required String vendorName,
    required String requestType,
    Map<String, dynamic>? requestData,
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

  Future<Map<String, dynamic>> generalTriggerHotkeyByKey({
    required String keyId,
    bool? keyModifiersShift,
    bool? keyModifiersCtrl,
    bool? keyModifiersAlt,
    bool? keyModifiersCmd,
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
  // Scenes
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> scenesList() async {
    final response = await _obs.scenes.getSceneList();
    return response.toJson();
  }

  Future<List<String>> scenesGroupList() async {
    return _obs.scenes.getGroupList();
  }

  Future<Map<String, dynamic>> scenesGetCurrentProgram() async {
    final name = await _obs.scenes.getCurrentProgramScene();
    return <String, dynamic>{'currentProgramSceneName': name};
  }

  Future<Map<String, dynamic>> scenesSetCurrentProgram(String sceneName) async {
    await _obs.scenes.setCurrentProgramScene(sceneName);
    return _ok;
  }

  Future<Map<String, dynamic>> scenesGetCurrentPreview() async {
    final name = await _obs.scenes.getCurrentPreviewScene();
    return <String, dynamic>{'currentPreviewSceneName': name};
  }

  Future<Map<String, dynamic>> scenesSetCurrentPreview(String sceneName) async {
    await _obs.scenes.setCurrentPreviewScene(sceneName);
    return _ok;
  }

  Future<Map<String, dynamic>> scenesCreate(String sceneName) async {
    await _obs.scenes.createScene(sceneName);
    return _ok;
  }

  Future<Map<String, dynamic>> scenesRemove(String sceneName) async {
    await _obs.scenes.removeScene(sceneName);
    return _ok;
  }

  Future<Map<String, dynamic>> scenesSetName(String sceneName) async {
    await _obs.scenes.setSceneName(sceneName);
    return _ok;
  }

  Future<Map<String, dynamic>> scenesGetSceneTransitionOverride(
    String sceneName,
  ) async {
    final response = await _obs.scenes.getSceneSceneTransitionOverride(
      sceneName,
    );
    return response.toJson();
  }

  Future<Map<String, dynamic>> scenesSetSceneTransitionOverride(
    String sceneName, {
    String? transitionName,
    int? transitionDuration,
  }) async {
    await _obs.scenes.setSceneSceneTransitionOverride(
      sceneName,
      transitionName: transitionName,
      transitionDuration: transitionDuration,
    );
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // Scene Items
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> sceneItemsList(String sceneName) async {
    final items = await _obs.sceneItems.getSceneItemList(sceneName);
    return items.map((i) => i.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> sceneItemsGroupList(
    String sceneName,
  ) async {
    final items = await _obs.sceneItems.getGroupSceneItemList(sceneName);
    return items.map((i) => i.toJson()).toList();
  }

  Future<Map<String, dynamic>> sceneItemsGetId({
    required String sceneName,
    required String sourceName,
  }) async {
    final id = await _obs.sceneItems.getSceneItemId(
      sceneName: sceneName,
      sourceName: sourceName,
    );
    return <String, dynamic>{'sceneItemId': id};
  }

  Future<bool> sceneItemsGetEnabled({
    required String sceneName,
    required int sceneItemId,
  }) => _obs.sceneItems.getSceneItemEnabled(
    sceneName: sceneName,
    sceneItemId: sceneItemId,
  );

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

  Future<bool> sceneItemsGetLocked({
    required String sceneName,
    required int sceneItemId,
  }) => _obs.sceneItems.getSceneItemLocked(
    sceneName: sceneName,
    sceneItemId: sceneItemId,
  );

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

  Future<Map<String, dynamic>> sceneItemsSetTransform({
    required String sceneName,
    required int sceneItemId,
    num? positionX,
    num? positionY,
    num? scaleX,
    num? scaleY,
    num? rotation,
    int? cropLeft,
    int? cropTop,
    int? cropRight,
    int? cropBottom,
    int? alignment,
    String? boundsType,
    int? boundsAlignment,
    num? boundsWidth,
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
      boundsType: boundsType,
      boundsAlignment: boundsAlignment,
      boundsWidth: boundsWidth?.toDouble(),
      boundsHeight: boundsHeight?.toDouble(),
    );
    await _obs.sceneItems.setSceneItemTransformTyped(
      sceneName: sceneName,
      sceneItemId: sceneItemId,
      transform: transform,
    );
    final updated = await _obs.sceneItems.getSceneItemTransformTyped(
      sceneName: sceneName,
      sceneItemId: sceneItemId,
    );
    return updated.toJson();
  }

  Future<Map<String, dynamic>> sceneItemsGetTransform({
    required String sceneName,
    required int sceneItemId,
  }) async {
    final transform = await _obs.sceneItems.getSceneItemTransformTyped(
      sceneName: sceneName,
      sceneItemId: sceneItemId,
    );
    return transform.toJson();
  }

  Future<Map<String, dynamic>> sceneItemsCreate({
    required String sceneName,
    required String sourceName,
    bool? sceneItemEnabled,
  }) async {
    final response = await _obs.sceneItems.createSceneItem(
      sceneName: sceneName,
      sourceName: sourceName,
      sceneItemEnabled: sceneItemEnabled,
    );
    return <String, dynamic>{'sceneItemId': response};
  }

  Future<Map<String, dynamic>> sceneItemsDuplicate({
    required String sceneName,
    required int sceneItemId,
    String? destinationSceneName,
  }) async {
    final response = await _obs.sceneItems.duplicateSceneItem(
      sceneName: sceneName,
      sceneItemId: sceneItemId,
      destinationSceneName: destinationSceneName,
    );
    return <String, dynamic>{'sceneItemId': response};
  }

  Future<Map<String, dynamic>> sceneItemsRemove({
    required String sceneName,
    required int sceneItemId,
  }) async {
    await _obs.sceneItems.removeSceneItem(
      sceneName: sceneName,
      sceneItemId: sceneItemId,
    );
    return _ok;
  }

  Future<Map<String, dynamic>> sceneItemsGetSource({
    String? sceneName,
    String? sceneUuid,
    required int sceneItemId,
  }) async {
    final response = await _obs.sceneItems.getSceneItemSource(
      sceneName: sceneName,
      sceneUuid: sceneUuid,
      sceneItemId: sceneItemId,
    );
    return response;
  }

  Future<Map<String, dynamic>> sceneItemsGetPrivateSettings({
    String? sceneName,
    String? sceneUuid,
    required int sceneItemId,
  }) async {
    return _obs.sceneItems.getSceneItemPrivateSettings(
      sceneName: sceneName,
      sceneUuid: sceneUuid,
      sceneItemId: sceneItemId,
    );
  }

  Future<Map<String, dynamic>> sceneItemsSetPrivateSettings({
    String? sceneName,
    String? sceneUuid,
    required int sceneItemId,
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

  Future<Map<String, dynamic>> sceneItemsGetIndex({
    required String sceneName,
    required int sceneItemId,
  }) async {
    final index = await _obs.sceneItems.getSceneItemIndex(
      sceneName: sceneName,
      sceneItemId: sceneItemId,
    );
    return <String, dynamic>{'sceneItemIndex': index};
  }

  Future<Map<String, dynamic>> sceneItemsSetIndex({
    required String sceneName,
    required int sceneItemId,
    required int sceneItemIndex,
  }) async {
    await _obs.sceneItems.setSceneItemIndex(
      sceneName: sceneName,
      sceneItemId: sceneItemId,
      sceneItemIndex: sceneItemIndex,
    );
    return _ok;
  }

  Future<Map<String, dynamic>> sceneItemsGetBlendMode({
    required String sceneName,
    required int sceneItemId,
  }) async {
    final mode = await _obs.sceneItems.getSceneItemBlendMode(
      sceneName: sceneName,
      sceneItemId: sceneItemId,
    );
    return <String, dynamic>{'sceneItemBlendMode': mode};
  }

  Future<Map<String, dynamic>> sceneItemsSetBlendMode({
    required String sceneName,
    required int sceneItemId,
    required String sceneItemBlendMode,
  }) async {
    await _obs.sceneItems.setSceneItemBlendMode(
      sceneName: sceneName,
      sceneItemId: sceneItemId,
      sceneItemBlendMode: sceneItemBlendMode,
    );
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // Inputs
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> inputsList({String? inputKind}) async {
    final inputs = await _obs.inputs.getInputList(inputKind);
    return inputs.map((e) => e.toJson()).toList();
  }

  Future<List<String>> inputsKindList({bool? unversioned}) =>
      _obs.inputs.getInputKindList(unversioned ?? false);

  Future<Map<String, dynamic>> inputsSpecial() async =>
      (await _obs.inputs.getSpecialInputs()).toJson();

  Future<bool> inputsGetMute(String inputName) =>
      _obs.inputs.getInputMute(inputName);

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

  Future<bool> inputsToggleMute({String? inputName, String? inputUuid}) =>
      _obs.inputs.toggleInputMute(inputName: inputName, inputUuid: inputUuid);

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

  Future<Map<String, dynamic>> inputsRemove({
    String? inputName,
    String? inputUuid,
  }) async {
    await _obs.inputs.removeInput(inputName: inputName, inputUuid: inputUuid);
    return _ok;
  }

  Future<Map<String, dynamic>> inputsSetVolume({
    String? inputName,
    String? inputUuid,
    required double inputVolume,
  }) async {
    await _obs.inputs.setInputVolume(
      inputName: inputName,
      inputUuid: inputUuid,
      inputVolume: inputVolume,
    );
    return _ok;
  }

  Future<Map<String, dynamic>> inputsGetDefaultSettings({
    required String inputKind,
  }) async {
    final response = await _obs.inputs.getInputDefaultSettings(
      inputKind: inputKind,
    );
    return response.toJson();
  }

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

  Future<Map<String, dynamic>> inputsSetDeinterlaceMode({
    String? inputName,
    String? inputUuid,
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

  Future<Map<String, dynamic>> inputsSetDeinterlaceFieldOrder({
    String? inputName,
    String? inputUuid,
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

  Future<Map<String, dynamic>> inputsSetAudioBalance({
    String? inputName,
    String? inputUuid,
    required double inputAudioBalance,
  }) async {
    await _obs.inputs.setInputAudioBalance(
      inputName: inputName,
      inputUuid: inputUuid,
      inputAudioBalance: inputAudioBalance,
    );
    return _ok;
  }

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

  Future<Map<String, dynamic>> inputsSetAudioSyncOffset({
    String? inputName,
    String? inputUuid,
    required int inputAudioSyncOffset,
  }) async {
    await _obs.inputs.setInputAudioSyncOffset(
      inputName: inputName,
      inputUuid: inputUuid,
      inputAudioSyncOffset: inputAudioSyncOffset,
    );
    return _ok;
  }

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

  Future<Map<String, dynamic>> inputsSetAudioMonitorType({
    String? inputName,
    String? inputUuid,
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

  Future<Map<String, dynamic>> inputsSetAudioTracks({
    String? inputName,
    String? inputUuid,
    required int inputAudioTracks,
  }) async {
    await _obs.inputs.setInputAudioTracks(
      inputName: inputName,
      inputUuid: inputUuid,
      inputAudioTracks: inputAudioTracks,
    );
    return _ok;
  }

  Future<Map<String, dynamic>> inputsGetPropertiesListItems({
    String? inputName,
    String? inputUuid,
    required String propertyName,
  }) async {
    final response = await _obs.inputs.getInputPropertiesListPropertyItems(
      inputName: inputName,
      inputUuid: inputUuid,
      propertyName: propertyName,
    );
    return response.toJson();
  }

  Future<Map<String, dynamic>> inputsPressPropertiesButton({
    String? inputName,
    String? inputUuid,
    required String propertyName,
  }) async {
    await _obs.inputs.pressInputPropertiesButton(
      inputName: inputName,
      inputUuid: inputUuid,
      propertyName: propertyName,
    );
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // Stream
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> streamStatus() async =>
      (await _obs.stream.getStreamStatus()).toJson();

  Future<Map<String, dynamic>> streamStart() async {
    await _obs.stream.start();
    return _ok;
  }

  Future<Map<String, dynamic>> streamStop() async {
    await _obs.stream.stop();
    return _ok;
  }

  Future<bool> streamToggle() => _obs.stream.toggle();

  Future<Map<String, dynamic>> streamSendCaption(String captionText) async {
    await _obs.stream.sendStreamCaption(captionText);
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // Record
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> recordStatus() async =>
      (await _obs.record.getRecordStatus()).toJson();

  Future<Map<String, dynamic>> recordStart() async {
    await _obs.record.start();
    return _ok;
  }

  Future<String> recordStop() => _obs.record.stop();

  Future<Map<String, dynamic>> recordToggle() async {
    await _obs.record.toggle();
    return _ok;
  }

  Future<Map<String, dynamic>> recordPause() async {
    await _obs.record.pause();
    return _ok;
  }

  Future<Map<String, dynamic>> recordResume() async {
    await _obs.record.resume();
    return _ok;
  }

  Future<Map<String, dynamic>> recordTogglePause() async {
    await _obs.record.togglePause();
    return _ok;
  }

  Future<Map<String, dynamic>> recordSplitFile() async {
    await _obs.record.splitRecordFile();
    return _ok;
  }

  Future<Map<String, dynamic>> recordCreateChapter({
    String? chapterName,
  }) async {
    await _obs.record.createRecordChapter(chapterName: chapterName);
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // Outputs
  // ---------------------------------------------------------------------------

  Future<bool> outputsVirtualCamStatus() => _obs.outputs.getVirtualCamStatus();
  Future<bool> outputsVirtualCamToggle() => _obs.outputs.toggleVirtualCam();

  Future<Map<String, dynamic>> outputsVirtualCamStart() async {
    await _obs.outputs.startVirtualCam();
    return _ok;
  }

  Future<Map<String, dynamic>> outputsVirtualCamStop() async {
    await _obs.outputs.stopVirtualCam();
    return _ok;
  }

  Future<bool> outputsReplayBufferStatus() =>
      _obs.outputs.getReplayBufferStatus();
  Future<bool> outputsReplayBufferToggle() => _obs.outputs.toggleReplayBuffer();

  Future<Map<String, dynamic>> outputsReplayBufferStart({
    String? outputName,
  }) async {
    await _obs.outputs.startReplayBuffer(outputName ?? '');
    return _ok;
  }

  Future<Map<String, dynamic>> outputsReplayBufferStop({
    String? outputName,
  }) async {
    await _obs.outputs.stopReplayBuffer(outputName ?? '');
    return _ok;
  }

  Future<Map<String, dynamic>> outputsReplayBufferSave({
    String? outputName,
  }) async {
    await _obs.outputs.saveReplayBuffer(outputName ?? '');
    return _ok;
  }

  Future<bool> outputsToggle(String outputName) =>
      _obs.outputs.toggleOutput(outputName);

  Future<Map<String, dynamic>> outputsStart(String outputName) async {
    await _obs.outputs.start(outputName);
    return _ok;
  }

  Future<Map<String, dynamic>> outputsStop(String outputName) async {
    await _obs.outputs.stop(outputName);
    return _ok;
  }

  Future<List<Map<String, dynamic>>> outputsList() async =>
      await _obs.outputs.getOutputList();

  Future<Map<String, dynamic>> outputsGetStatus(String outputName) async =>
      await _obs.outputs.getOutputStatus(outputName);

  Future<Map<String, dynamic>> outputsGetSettings(String outputName) async =>
      await _obs.outputs.getOutputSettings(outputName);

  Future<Map<String, dynamic>> outputsSetSettings({
    required String outputName,
    required Map<String, dynamic> outputSettings,
  }) async {
    await _obs.outputs.setOutputSettings(
      outputName: outputName,
      outputSettings: outputSettings,
    );
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // Config
  // ---------------------------------------------------------------------------

  Future<String> configRecordDirectory() async =>
      (await _obs.config.getRecordDirectory()).recordDirectory;

  Future<Map<String, dynamic>> configStreamServiceSettings() async =>
      (await _obs.config.getStreamServiceSettings()).toJson();

  Future<Map<String, dynamic>> configGetPersistentData({
    required String realm,
    required String slotName,
  }) async =>
      await _obs.config.getPersistentData(realm: realm, slotName: slotName);

  Future<Map<String, dynamic>> configSetPersistentData({
    required String realm,
    required String slotName,
    required dynamic slotValue,
  }) async {
    await _obs.config.setPersistentData(
      realm: realm,
      slotName: slotName,
      slotValue: slotValue,
    );
    return _ok;
  }

  Future<Map<String, dynamic>> configSceneCollectionList() async =>
      (await _obs.config.getSceneCollectionList()).toJson();

  Future<Map<String, dynamic>> configSetCurrentSceneCollection(
    String sceneCollectionName,
  ) async {
    await _obs.config.setCurrentSceneCollection(sceneCollectionName);
    return _ok;
  }

  Future<Map<String, dynamic>> configCreateSceneCollection(
    String sceneCollectionName,
  ) async {
    await _obs.config.createSceneCollection(sceneCollectionName);
    return _ok;
  }

  Future<Map<String, dynamic>> configProfileList() async =>
      (await _obs.config.getProfileList()).toJson();

  Future<Map<String, dynamic>> configSetCurrentProfile(
    String profileName,
  ) async {
    await _obs.config.setCurrentProfile(profileName);
    return _ok;
  }

  Future<Map<String, dynamic>> configCreateProfile(String profileName) async {
    await _obs.config.createProfile(profileName);
    return _ok;
  }

  Future<Map<String, dynamic>> configRemoveProfile(String profileName) async {
    await _obs.config.removeProfile(profileName);
    return _ok;
  }

  Future<Map<String, dynamic>> configGetProfileParameter({
    required String parameterCategory,
    required String parameterName,
  }) async {
    final response = await _obs.config.getProfileParameter(
      parameterCategory: parameterCategory,
      parameterName: parameterName,
    );
    return response.toJson();
  }

  Future<Map<String, dynamic>> configSetProfileParameter({
    required String parameterCategory,
    required String parameterName,
    required String parameterValue,
  }) async {
    await _obs.config.setProfileParameter(
      parameterCategory: parameterCategory,
      parameterName: parameterName,
      parameterValue: parameterValue,
    );
    return _ok;
  }

  Future<Map<String, dynamic>> configSetVideoSettings(
    VideoSettings videoSettings,
  ) async {
    await _obs.config.setVideoSettings(videoSettings);
    return _ok;
  }

  Future<Map<String, dynamic>> configSetStreamServiceSettings({
    required String streamServiceType,
    required Map<String, dynamic> streamServiceSettings,
  }) async {
    await _obs.config.setStreamServiceSettings(
      streamServiceType: streamServiceType,
      streamServiceSettings: streamServiceSettings,
    );
    return _ok;
  }

  Future<Map<String, dynamic>> configSetRecordDirectory(
    String recordDirectory,
  ) async {
    await _obs.config.setRecordDirectory(recordDirectory);
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  Future<bool> uiStudioModeEnabled() => _obs.ui.getStudioModeEnabled();

  Future<Map<String, dynamic>> uiSetStudioMode(bool enabled) async {
    await _obs.ui.setStudioModeEnabled(enabled);
    return _ok;
  }

  Future<Map<String, dynamic>> uiOpenInputProperties(String inputName) async {
    await _obs.ui.openInputPropertiesDialog(inputName);
    return _ok;
  }

  Future<Map<String, dynamic>> uiOpenInputFilters(String inputName) async {
    await _obs.ui.openInputFiltersDialog(inputName);
    return _ok;
  }

  Future<Map<String, dynamic>> uiOpenInputInteract(String inputName) async {
    await _obs.ui.openInputInteractDialog(inputName);
    return _ok;
  }

  Future<List<Map<String, dynamic>>> uiMonitorList() async {
    final monitors = await _obs.ui.getMonitorList();
    return monitors.map((e) => e.toJson()).toList();
  }

  Future<Map<String, dynamic>> uiOpenVideoMixProjector(
    String videoMixType, {
    int? monitorIndex,
    String? projectorGeometry,
  }) async {
    await _obs.ui.openVideoMixProjector(
      videoMixType,
      monitorIndex: monitorIndex,
      projectorGeometry: projectorGeometry,
    );
    return _ok;
  }

  Future<Map<String, dynamic>> uiOpenSourceProjector(
    String sourceName, {
    int? monitorIndex,
    String? projectorGeometry,
  }) async {
    await _obs.ui.openSourceProjector(
      sourceName,
      monitorIndex: monitorIndex,
      projectorGeometry: projectorGeometry,
    );
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // Transitions
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> transitionsTriggerStudio() async {
    await _obs.transitions.triggerStudioModeTransition();
    return _ok;
  }

  Future<List<String>> transitionsKindList() =>
      _obs.transitions.getTransitionKindList();

  Future<Map<String, dynamic>> transitionsSceneList() async =>
      await _obs.transitions.getSceneTransitionList();

  Future<Map<String, dynamic>> transitionsGetCurrent() async =>
      await _obs.transitions.getCurrentSceneTransition();

  Future<Map<String, dynamic>> transitionsSetCurrent(
    String transitionName,
  ) async {
    await _obs.transitions.setCurrentSceneTransition(transitionName);
    return _ok;
  }

  Future<Map<String, dynamic>> transitionsSetDuration(int duration) async {
    await _obs.transitions.setCurrentSceneTransitionDuration(duration);
    return _ok;
  }

  Future<Map<String, dynamic>> transitionsSetSettings({
    required Map<String, dynamic> transitionSettings,
    bool? overlay,
  }) async {
    await _obs.transitions.setCurrentSceneTransitionSettings(
      transitionSettings: transitionSettings,
      overlay: overlay,
    );
    return _ok;
  }

  Future<double> transitionsGetCursor() async =>
      await _obs.transitions.getCurrentSceneTransitionCursor();

  Future<Map<String, dynamic>> transitionsSetTBar({
    required double position,
    bool? release,
  }) async {
    await _obs.transitions.setTBarPosition(
      position: position,
      release: release,
    );
    return _ok;
  }

  // ---------------------------------------------------------------------------
  // Sources
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> sourcesGetActive(String sourceName) async {
    final response = await _obs.sources.active(sourceName);
    return response.toJson();
  }

  Future<Map<String, dynamic>> sourcesGetScreenshot({
    required String sourceName,
    required String imageFormat,
    int? imageWidth,
    int? imageHeight,
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

  Future<Map<String, dynamic>> sourcesSaveScreenshot({
    required String sourceName,
    required String filePath,
    required String imageFormat,
    int? imageWidth,
    int? imageHeight,
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

  Future<Map<String, dynamic>> sourcesGetPrivateSettings({
    String? sourceName,
    String? sourceUuid,
  }) async {
    return _obs.sources.getSourcePrivateSettings(
      sourceName: sourceName,
      sourceUuid: sourceUuid,
    );
  }

  Future<Map<String, dynamic>> sourcesSetPrivateSettings({
    String? sourceName,
    String? sourceUuid,
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
  // Media Inputs
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> mediaInputsGetStatus({
    String? inputName,
    String? inputUuid,
  }) async {
    final response = await _obs.mediaInputs.getMediaInputStatus(
      inputName: inputName,
      inputUuid: inputUuid,
    );
    return response.toJson();
  }

  Future<Map<String, dynamic>> mediaInputsSetCursor({
    String? inputName,
    String? inputUuid,
    required int mediaCursor,
  }) async {
    await _obs.mediaInputs.setMediaInputCursor(
      inputName: inputName,
      inputUuid: inputUuid,
      mediaCursor: mediaCursor,
    );
    return _ok;
  }

  Future<Map<String, dynamic>> mediaInputsOffsetCursor({
    String? inputName,
    String? inputUuid,
    required int mediaCursorOffset,
  }) async {
    await _obs.mediaInputs.offsetMediaInputCursor(
      inputName: inputName,
      inputUuid: inputUuid,
      mediaCursorOffset: mediaCursorOffset,
    );
    return _ok;
  }

  Future<Map<String, dynamic>> mediaInputsTriggerAction({
    String? inputName,
    String? inputUuid,
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

  // ---------------------------------------------------------------------------
  // Canvases
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> canvasesList() async =>
      (await _obs.canvas.getCanvasList()).toJson();

  Future<Map<String, dynamic>> videoSettings() async =>
      (await _obs.config.getVideoSettings()).toJson();

  // ---------------------------------------------------------------------------
  // Filters
  // ---------------------------------------------------------------------------

  Future<List<String>> filtersKindList() =>
      _obs.filters.getSourceFilterKindList();

  Future<List<Map<String, dynamic>>> filtersList(String sourceName) async =>
      await _obs.filters.getSourceFilterList(sourceName);

  Future<Map<String, dynamic>> filtersDefaultSettings(
    String filterKind,
  ) async => await _obs.filters.getSourceFilterDefaultSettings(filterKind);

  Future<Map<String, dynamic>> filtersCreate({
    required String sourceName,
    required String filterName,
    required String filterKind,
    Map<String, dynamic>? filterSettings,
  }) async {
    await _obs.filters.createSourceFilter(
      sourceName: sourceName,
      filterName: filterName,
      filterKind: filterKind,
      filterSettings: filterSettings,
    );
    return _ok;
  }

  Future<Map<String, dynamic>> filtersRemove({
    required String sourceName,
    required String filterName,
  }) async {
    await _obs.filters.removeSourceFilter(
      sourceName: sourceName,
      filterName: filterName,
    );
    return _ok;
  }

  Future<Map<String, dynamic>> filtersRename({
    required String sourceName,
    required String filterName,
    required String newFilterName,
  }) async {
    await _obs.filters.setSourceFilterName(
      sourceName: sourceName,
      filterName: filterName,
      newFilterName: newFilterName,
    );
    return _ok;
  }

  Future<Map<String, dynamic>> filtersGet({
    required String sourceName,
    required String filterName,
  }) async => await _obs.filters.getSourceFilter(
    sourceName: sourceName,
    filterName: filterName,
  );

  Future<Map<String, dynamic>> filtersSetIndex({
    required String sourceName,
    required String filterName,
    required int filterIndex,
  }) async {
    await _obs.filters.setSourceFilterIndex(
      sourceName: sourceName,
      filterName: filterName,
      filterIndex: filterIndex,
    );
    return _ok;
  }

  Future<Map<String, dynamic>> filtersSetSettings({
    required String sourceName,
    required String filterName,
    required Map<String, dynamic> filterSettings,
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

  Future<Map<String, dynamic>> filtersSetEnabled({
    required String sourceName,
    required String filterName,
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
  // Events
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> eventsSubscribe({
    int? mask,
    List<String>? subscriptions,
  }) async {
    final resolved = parseEventSubscription(mask, subscriptions);
    await _obs.listenForMask(resolved);
    return <String, dynamic>{'ok': true, 'mask': resolved};
  }

  Future<Map<String, dynamic>> waitForEvent({
    required String eventType,
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

  // ---------------------------------------------------------------------------
  // Client-side sleep
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> clientSleep({required int ms}) async {
    if (ms < 1 || ms > 25000) {
      throw ArgumentError(
        'client_sleep ms must be between 1 and 25000 (got $ms).',
      );
    }
    final start = DateTime.now();
    await Future<void>.delayed(Duration(milliseconds: ms));
    return <String, dynamic>{
      'ok': true,
      'requestedMs': ms,
      'actualMs': DateTime.now().difference(start).inMilliseconds,
    };
  }

  // ---------------------------------------------------------------------------
  // Scene Items Animate Transform
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> sceneItemsAnimateTransform({
    required String sceneName,
    required int sceneItemId,
    required int durationMs,
    num? targetPositionX,
    num? targetPositionY,
    num? targetScaleX,
    num? targetScaleY,
    num? targetRotation,
    int? targetCropLeft,
    int? targetCropTop,
    int? targetCropRight,
    int? targetCropBottom,
    int? frameRate,
    String? easing,
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
      if (!isLast) await Future<void>.delayed(frameInterval);
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
  // Internal helpers
  // ---------------------------------------------------------------------------

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
      _ => throw ArgumentError('Invalid deinterlace mode: $value.'),
    };
  }

  static ObsDeinterlaceFieldOrder _parseDeinterlaceFieldOrder(String value) {
    return switch (value.toLowerCase()) {
      'top' => ObsDeinterlaceFieldOrder.top,
      'bottom' => ObsDeinterlaceFieldOrder.bottom,
      _ => throw ArgumentError(
        'Invalid field order: $value. Must be: top, bottom.',
      ),
    };
  }

  static ObsMonitoringType _parseMonitorType(int value) {
    return switch (value) {
      0 => ObsMonitoringType.none,
      1 => ObsMonitoringType.monitorOnly,
      2 => ObsMonitoringType.monitorAndOutput,
      _ => throw ArgumentError('Invalid monitor type: $value.'),
    };
  }
}
