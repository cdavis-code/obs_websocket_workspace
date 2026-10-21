import 'package:obs_websocket/obs_websocket.dart';

/// Scenes Requests
class Scenes {
  final ObsWebSocket obsWebSocket;

  Scenes(this.obsWebSocket);

  /// Gets an array of all scenes in OBS.
  ///
  /// Compatible with inputs and scenes.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<SceneListResponse> getSceneList({String? canvasUuid}) async =>
      await list(canvasUuid: canvasUuid);

  /// Gets an array of all scenes in OBS.
  ///
  /// Compatible with inputs and scenes.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<SceneListResponse> getList({String? canvasUuid}) async =>
      await list(canvasUuid: canvasUuid);

  /// Gets an array of all scenes in OBS.
  ///
  /// Compatible with inputs and scenes.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<SceneListResponse> list({String? canvasUuid}) async {
    final response = await obsWebSocket.sendRequest(
      Request('GetSceneList', requestData: {'canvasUuid': ?canvasUuid}),
    );

    return SceneListResponse.fromJson(response!.responseData!);
  }

  ///Gets an array of all groups in OBS.
  ///
  ///Groups in OBS are actually scenes, but renamed and modified. In obs-websocket, we treat them as scenes where we can.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<List<String>> getGroupList() async => await groupList();

  ///Gets an array of all groups in OBS.
  ///
  ///Groups in OBS are actually scenes, but renamed and modified. In obs-websocket, we treat them as scenes where we can.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<List<String>> groupList() async {
    final response = await obsWebSocket.sendRequest(Request('GetGroupList'));

    return StringListResponse.fromJson(response!.responseData!).items;
  }

  /// Gets the current program scene.
  ///
  /// - Complexity Rating: 1/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<String> getCurrentProgramScene() async => await getCurrentProgram();

  /// Gets the current program scene.
  ///
  /// - Complexity Rating: 1/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<String> getCurrentProgram() async {
    final response = await obsWebSocket.sendRequest(
      Request('GetCurrentProgramScene'),
    );

    return StringResponse.fromJson(response!.responseData!).value;
  }

  /// Sets the current program scene.
  ///
  /// - Complexity Rating: 1/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setCurrentProgramScene(
    String? sceneName, {
    String? sceneUuid,
  }) async => await setCurrentProgram(sceneName, sceneUuid: sceneUuid);

  /// Sets the current program scene.
  ///
  /// - Complexity Rating: 1/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setCurrentProgram(String? sceneName, {String? sceneUuid}) async {
    if (sceneName == null && sceneUuid == null) {
      throw ArgumentError('sceneName or sceneUuid must be provided');
    }

    await obsWebSocket.sendRequest(
      Request(
        'SetCurrentProgramScene',
        requestData: {'sceneName': ?sceneName, 'sceneUuid': ?sceneUuid},
      ),
    );
  }

  /// Gets the current preview scene.
  ///
  /// - Complexity Rating: 1/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<String> getCurrentPreviewScene() async => await getCurrentPreview();

  /// Gets the current preview scene.
  ///
  /// - Complexity Rating: 1/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<String> getCurrentPreview() async {
    final response = await obsWebSocket.sendRequest(
      Request('GetCurrentPreviewScene'),
    );

    return StringResponse.fromJson(response!.responseData!).value;
  }

  /// Sets the current preview scene.
  ///
  /// - Complexity Rating: 1/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setCurrentPreviewScene(
    String? sceneName, {
    String? sceneUuid,
  }) async => setCurrentPreview(sceneName, sceneUuid: sceneUuid);

  /// Sets the current preview scene.
  ///
  /// - Complexity Rating: 1/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setCurrentPreview(String? sceneName, {String? sceneUuid}) async {
    if (sceneName == null && sceneUuid == null) {
      throw ArgumentError('sceneName or sceneUuid must be provided');
    }

    await obsWebSocket.sendRequest(
      Request(
        'SetCurrentPreviewScene',
        requestData: {'sceneName': ?sceneName, 'sceneUuid': ?sceneUuid},
      ),
    );
  }

  /// Creates a new scene in OBS.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> createScene(String sceneName, {String? canvasUuid}) async =>
      await create(sceneName, canvasUuid: canvasUuid);

  /// Creates a new scene in OBS.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> create(String sceneName, {String? canvasUuid}) async =>
      await obsWebSocket.sendRequest(
        Request(
          'CreateScene',
          requestData: {'sceneName': sceneName, 'canvasUuid': ?canvasUuid},
        ),
      );

  /// Removes a scene from OBS.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> removeScene(
    String? sceneName, {
    String? sceneUuid,
    String? canvasUuid,
  }) async =>
      await remove(sceneName, sceneUuid: sceneUuid, canvasUuid: canvasUuid);

  /// Removes a scene from OBS.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> remove(
    String? sceneName, {
    String? sceneUuid,
    String? canvasUuid,
  }) async {
    if (sceneName == null && sceneUuid == null) {
      throw ArgumentError('sceneName or sceneUuid must be provided');
    }

    await obsWebSocket.sendRequest(
      Request(
        'RemoveScene',
        requestData: {
          'sceneName': ?sceneName,
          'sceneUuid': ?sceneUuid,
          'canvasUuid': ?canvasUuid,
        },
      ),
    );
  }

  /// Sets the name of a scene (rename).
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setSceneName(
    String? sceneName, {
    required String newSceneName,
    String? sceneUuid,
    String? canvasUuid,
  }) async => await set(
    sceneName,
    newSceneName: newSceneName,
    sceneUuid: sceneUuid,
    canvasUuid: canvasUuid,
  );

  /// Sets the name of a scene (rename).
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> set(
    String? sceneName, {
    required String newSceneName,
    String? sceneUuid,
    String? canvasUuid,
  }) async {
    if (sceneName == null && sceneUuid == null) {
      throw ArgumentError('sceneName or sceneUuid must be provided');
    }

    await obsWebSocket.sendRequest(
      Request(
        'SetSceneName',
        requestData: {
          'sceneName': ?sceneName,
          'sceneUuid': ?sceneUuid,
          'newSceneName': newSceneName,
          'canvasUuid': ?canvasUuid,
        },
      ),
    );
  }

  /// Gets the scene transition overridden for a scene.
  ///
  /// Complexity Rating: 2/5
  /// Latest Supported RPC Version: 1
  /// Added in v5.0.0
  Future<SceneSceneTransitionOverrideResponse> getSceneSceneTransitionOverride(
    String? sceneName, {
    String? sceneUuid,
    String? canvasUuid,
  }) async {
    if (sceneName == null && sceneUuid == null) {
      throw ArgumentError('sceneName or sceneUuid must be provided');
    }

    final response = await obsWebSocket.sendRequest(
      Request(
        'GetSceneSceneTransitionOverride',
        requestData: {
          'sceneName': ?sceneName,
          'sceneUuid': ?sceneUuid,
          'canvasUuid': ?canvasUuid,
        },
      ),
    );

    return SceneSceneTransitionOverrideResponse.fromJson(
      response!.responseData!,
    );
  }

  /// Sets the scene transition overridden for a scene.
  ///
  /// Complexity Rating: 2/5
  /// Latest Supported RPC Version: 1
  /// Added in v5.0.0
  Future<void> setSceneSceneTransitionOverride(
    String? sceneName, {
    String? sceneUuid,
    String? canvasUuid,
    String? transitionName,
    int? transitionDuration,
  }) async {
    if (sceneName == null && sceneUuid == null) {
      throw ArgumentError('sceneName or sceneUuid must be provided');
    }

    await obsWebSocket.sendRequest(
      Request(
        'SetSceneSceneTransitionOverride',
        requestData: {
          'sceneName': ?sceneName,
          'sceneUuid': ?sceneUuid,
          'canvasUuid': ?canvasUuid,
          'transitionName': transitionName,
          'transitionDuration': transitionDuration,
        },
      ),
    );
  }
}
