import 'package:obs_websocket/obs_websocket.dart';

/// Inputs Requests
class Inputs {
  final ObsWebSocket obsWebSocket;

  Inputs(this.obsWebSocket);

  /// Gets an array of all inputs in OBS.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<List<Input>> getInputList(String? inputKind) async {
    final response = await obsWebSocket.sendRequest(
      Request('GetInputList', requestData: {'inputKind': inputKind}),
    );

    if (response == null || response.responseData == null) return <Input>[];

    return InputKindResponse.fromJson(response.responseData!).inputs;
  }

  /// Gets an array of all available input kinds in OBS.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<List<String>> getInputKindList([bool unversioned = false]) async {
    final response = await obsWebSocket.sendRequest(
      Request('GetInputKindList', requestData: {'unversioned': unversioned}),
    );

    if (response == null || response.responseData == null) return [];

    return StringListResponse.fromJson(response.responseData!).inputKinds ?? [];
  }

  /// Gets the names of all special inputs.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<SpecialInputsResponse> specialInputs() async => getSpecialInputs();

  /// Gets the names of all special inputs.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<SpecialInputsResponse> getSpecialInputs() async {
    final response = await obsWebSocket.sendRequest(
      Request('GetSpecialInputs'),
    );

    return SpecialInputsResponse.fromJson(response!.responseData!);
  }

  /// Creates a new input, adding it as a scene item to the specified scene.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<CreateInputResponse> create({
    String? sceneName,
    String? sceneUuid,
    String? canvasUuid,
    required String inputName,
    required String inputKind,
    dynamic inputSettings,
    bool? sceneItemEnabled,
  }) async => createInput(
    sceneName: sceneName,
    sceneUuid: sceneUuid,
    canvasUuid: canvasUuid,
    inputName: inputName,
    inputKind: inputKind,
    inputSettings: inputSettings,
    sceneItemEnabled: sceneItemEnabled,
  );

  /// Creates a new input, adding it as a scene item to the specified scene.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<CreateInputResponse> createInput({
    String? sceneName,
    String? sceneUuid,
    String? canvasUuid,
    required String inputName,
    required String inputKind,
    Map<String, dynamic>? inputSettings,
    bool? sceneItemEnabled,
  }) async {
    final response = await obsWebSocket.sendRequest(
      Request(
        'CreateInput',
        requestData: {
          'sceneName': ?sceneName,
          'sceneUuid': ?sceneUuid,
          'canvasUuid': ?canvasUuid,
          'inputName': inputName,
          'inputKind': inputKind,
          'inputSettings': inputSettings,
          'sceneItemEnabled': sceneItemEnabled,
        },
      ),
    );

    return CreateInputResponse.fromJson(response!.responseData!);
  }

  /// Removes an existing input.
  ///
  /// Note: Will immediately remove all associated scene items.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> removeInput({String? inputName, String? inputUuid}) async =>
      await remove(inputName: inputName, inputUuid: inputUuid);

  /// Removes an existing input.
  ///
  /// Note: Will immediately remove all associated scene items.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> remove({String? inputName, String? inputUuid}) async {
    if (inputName == null && inputUuid == null) {
      throw ArgumentError('inputName or inputUuid must be provided');
    }

    await obsWebSocket.sendRequest(
      Request(
        'RemoveInput',
        requestData: {'inputName': inputName, 'inputUuid': inputUuid},
      ),
    );
  }

  /// Sets the name of an input (rename).
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setInputName({
    String? inputName,
    String? inputUuid,
    required String newInputName,
  }) async => await setName(
    inputName: inputName,
    inputUuid: inputUuid,
    newInputName: newInputName,
  );

  /// Sets the name of an input (rename).
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setName({
    String? inputName,
    String? inputUuid,
    required String newInputName,
  }) async {
    await obsWebSocket.sendRequest(
      Request(
        'SetInputName',
        requestData: {
          'inputName': inputName,
          'inputUuid': inputUuid,
          'newInputName': newInputName,
        },
      ),
    );
  }

  /// Gets the default settings for an input kind.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<InputDefaultSettingsResponse> getInputDefaultSettings({
    required String inputKind,
  }) async {
    final response = await obsWebSocket.sendRequest(
      Request('GetInputDefaultSettings', requestData: {'inputKind': inputKind}),
    );

    return InputDefaultSettingsResponse.fromJson(response!.responseData!);
  }

  /// Gets the default settings for an input kind.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<InputDefaultSettingsResponse> defaultSettings({
    required String inputKind,
  }) async => getInputDefaultSettings(inputKind: inputKind);

  /// Gets the settings of an input.
  ///
  /// Note: Does not include defaults. To create the entire settings object, overlay inputSettings over the defaultInputSettings provided by GetInputDefaultSettings.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<InputSettingsResponse> getInputSettings({
    String? inputName,
    String? inputUuid,
  }) async {
    if (inputName == null && inputUuid == null) {
      throw ArgumentError('inputName or inputUuid must be provided');
    }

    final response = await obsWebSocket.sendRequest(
      Request(
        'GetInputSettings',
        requestData: {'inputName': inputName, 'inputUuid': inputUuid},
      ),
    );

    return InputSettingsResponse.fromJson(response!.responseData!);
  }

  /// Gets the settings of an input.
  ///
  /// Note: Does not include defaults. To create the entire settings object, overlay inputSettings over the defaultInputSettings provided by GetInputDefaultSettings.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<InputSettingsResponse> settings({
    String? inputName,
    String? inputUuid,
  }) async => getInputSettings(inputName: inputName, inputUuid: inputUuid);

  /// Sets the settings of an input.
  ///
  /// Note: Does not include defaults. To create the entire settings object, overlay inputSettings over the defaultInputSettings provided by GetInputDefaultSettings.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setInputSettings({
    String? inputName,
    String? inputUuid,
    required Map<String, dynamic> inputSettings,
    bool? overlay,
  }) async => await obsWebSocket.sendRequest(
    Request(
      'SetInputSettings',
      requestData: {
        'inputName': inputName,
        'inputUuid': inputUuid,
        'inputSettings': inputSettings,
        'overlay': overlay,
      },
    ),
  );

  /// Sets the settings of an input.
  ///
  /// Note: Does not include defaults. To create the entire settings object, overlay inputSettings over the defaultInputSettings provided by GetInputDefaultSettings.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setSettings({
    String? inputName,
    String? inputUuid,
    required Map<String, dynamic> inputSettings,
    bool? overlay,
  }) async => setInputSettings(
    inputName: inputName,
    inputUuid: inputUuid,
    inputSettings: inputSettings,
    overlay: overlay,
  );

  /// Gets the audio mute state of an input.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<bool> getMute(String inputName) async => getInputMute(inputName);

  /// Gets the audio mute state of an input.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<bool> getInputMute(String inputName) async {
    final response = await obsWebSocket.sendRequest(
      Request('GetInputMute', requestData: {'inputName': inputName}),
    );

    return BooleanResponse.fromJson(response!.responseData!).enabled;
  }

  /// Sets the audio mute state of an input.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setInputMute({
    String? inputName,
    String? inputUuid,
    required bool inputMuted,
  }) async {
    if (inputName == null && inputUuid == null) {
      throw ArgumentError('inputName or inputUuid must be provided');
    }

    await obsWebSocket.sendRequest(
      Request(
        'SetInputMute',
        requestData: {
          'inputName': inputName,
          'inputUuid': inputUuid,
          'inputMuted': inputMuted,
        },
      ),
    );
  }

  /// Sets the audio mute state of an input.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setMute({
    String? inputName,
    String? inputUuid,
    required bool inputMuted,
  }) async => setInputMute(
    inputMuted: inputMuted,
    inputName: inputName,
    inputUuid: inputUuid,
  );

  /// Toggles the audio mute state of an input.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<bool> toggleMute({String? inputName, String? inputUuid}) async =>
      toggleInputMute(inputName: inputName, inputUuid: inputUuid);

  /// Toggles the audio mute state of an input.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<bool> toggleInputMute({String? inputName, String? inputUuid}) async {
    final response = await obsWebSocket.sendRequest(
      Request(
        'ToggleInputMute',
        requestData: {'inputName': inputName, 'inputUuid': inputUuid},
      ),
    );

    return BooleanResponse.fromJson(response!.responseData!).enabled;
  }

  /// Gets the current volume setting of an input.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<InputVolumeResponse> getInputVolume({
    String? inputName,
    String? inputUuid,
  }) async {
    if (inputName == null && inputUuid == null) {
      throw ArgumentError('inputName or inputUuid must be provided');
    }

    final response = await obsWebSocket.sendRequest(
      Request(
        'GetInputVolume',
        requestData: {'inputName': inputName, 'inputUuid': inputUuid},
      ),
    );

    return InputVolumeResponse.fromJson(response!.responseData!);
  }

  /// Gets the deinterlace mode of an input.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<InputDeinterlaceModeResponse> getInputDeinterlaceMode({
    String? inputName,
    String? inputUuid,
  }) async {
    if (inputName == null && inputUuid == null) {
      throw ArgumentError('inputName or inputUuid must be provided');
    }

    final response = await obsWebSocket.sendRequest(
      Request(
        'GetInputDeinterlaceMode',
        requestData: {'inputName': inputName, 'inputUuid': inputUuid},
      ),
    );

    return InputDeinterlaceModeResponse.fromJson(response!.responseData!);
  }

  /// Sets the deinterlace mode of an input.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setInputDeinterlaceMode({
    String? inputName,
    String? inputUuid,
    required ObsDeinterlaceMode deinterlaceMode,
  }) async {
    if (inputName == null && inputUuid == null) {
      throw ArgumentError('inputName or inputUuid must be provided');
    }

    await obsWebSocket.sendRequest(
      Request(
        'SetInputDeinterlaceMode',
        requestData: {
          'inputName': inputName,
          'inputUuid': inputUuid,
          'deinterlaceMode': deinterlaceMode.code,
        },
      ),
    );
  }

  /// Gets the deinterlace field order of an input.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<InputDeinterlaceFieldOrderResponse> getInputDeinterlaceFieldOrder({
    String? inputName,
    String? inputUuid,
  }) async {
    if (inputName == null && inputUuid == null) {
      throw ArgumentError('inputName or inputUuid must be provided');
    }

    final response = await obsWebSocket.sendRequest(
      Request(
        'GetInputDeinterlaceFieldOrder',
        requestData: {'inputName': inputName, 'inputUuid': inputUuid},
      ),
    );

    return InputDeinterlaceFieldOrderResponse.fromJson(response!.responseData!);
  }

  /// Sets the deinterlace field order of an input.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setInputDeinterlaceFieldOrder({
    String? inputName,
    String? inputUuid,
    required ObsDeinterlaceFieldOrder deinterlaceFieldOrder,
  }) async {
    if (inputName == null && inputUuid == null) {
      throw ArgumentError('inputName or inputUuid must be provided');
    }

    await obsWebSocket.sendRequest(
      Request(
        'SetInputDeinterlaceFieldOrder',
        requestData: {
          'inputName': inputName,
          'inputUuid': inputUuid,
          'deinterlaceFieldOrder': deinterlaceFieldOrder.code,
        },
      ),
    );
  }

  /// Sets the volume of an input.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setInputVolume({
    String? inputName,
    String? inputUuid,
    required double inputVolume,
  }) async {
    if (inputName == null && inputUuid == null) {
      throw ArgumentError('inputName or inputUuid must be provided');
    }

    await obsWebSocket.sendRequest(
      Request(
        'SetInputVolume',
        requestData: {
          'inputName': inputName,
          'inputUuid': inputUuid,
          'inputVolume': inputVolume,
        },
      ),
    );
  }

  /// Gets the audio balance of an input.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<InputAudioBalanceResponse> getInputAudioBalance({
    String? inputName,
    String? inputUuid,
  }) async {
    if (inputName == null && inputUuid == null) {
      throw ArgumentError('inputName or inputUuid must be provided');
    }

    final response = await obsWebSocket.sendRequest(
      Request(
        'GetInputAudioBalance',
        requestData: {'inputName': inputName, 'inputUuid': inputUuid},
      ),
    );

    return InputAudioBalanceResponse.fromJson(response!.responseData!);
  }

  /// Sets the audio balance of an input.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setInputAudioBalance({
    String? inputName,
    String? inputUuid,
    required double inputAudioBalance,
  }) async {
    if (inputName == null && inputUuid == null) {
      throw ArgumentError('inputName or inputUuid must be provided');
    }

    await obsWebSocket.sendRequest(
      Request(
        'SetInputAudioBalance',
        requestData: {
          'inputName': inputName,
          'inputUuid': inputUuid,
          'inputAudioBalance': inputAudioBalance,
        },
      ),
    );
  }

  /// Gets the audio sync offset of an input.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<InputAudioSyncOffsetResponse> getInputAudioSyncOffset({
    String? inputName,
    String? inputUuid,
  }) async {
    if (inputName == null && inputUuid == null) {
      throw ArgumentError('inputName or inputUuid must be provided');
    }

    final response = await obsWebSocket.sendRequest(
      Request(
        'GetInputAudioSyncOffset',
        requestData: {'inputName': inputName, 'inputUuid': inputUuid},
      ),
    );

    return InputAudioSyncOffsetResponse.fromJson(response!.responseData!);
  }

  /// Sets the audio sync offset of an input.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setInputAudioSyncOffset({
    String? inputName,
    String? inputUuid,
    required int inputAudioSyncOffset,
  }) async {
    if (inputName == null && inputUuid == null) {
      throw ArgumentError('inputName or inputUuid must be provided');
    }

    await obsWebSocket.sendRequest(
      Request(
        'SetInputAudioSyncOffset',
        requestData: {
          'inputName': inputName,
          'inputUuid': inputUuid,
          'inputAudioSyncOffset': inputAudioSyncOffset,
        },
      ),
    );
  }

  /// Gets the audio monitor type of an input.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<InputAudioMonitorTypeResponse> getInputAudioMonitorType({
    String? inputName,
    String? inputUuid,
  }) async {
    if (inputName == null && inputUuid == null) {
      throw ArgumentError('inputName or inputUuid must be provided');
    }

    final response = await obsWebSocket.sendRequest(
      Request(
        'GetInputAudioMonitorType',
        requestData: {'inputName': inputName, 'inputUuid': inputUuid},
      ),
    );

    return InputAudioMonitorTypeResponse.fromJson(response!.responseData!);
  }

  /// Sets the audio monitor type of an input.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setInputAudioMonitorType({
    String? inputName,
    String? inputUuid,
    required ObsMonitoringType monitorType,
  }) async {
    if (inputName == null && inputUuid == null) {
      throw ArgumentError('inputName or inputUuid must be provided');
    }

    await obsWebSocket.sendRequest(
      Request(
        'SetInputAudioMonitorType',
        requestData: {
          'inputName': inputName,
          'inputUuid': inputUuid,
          'monitorType': monitorType.code,
        },
      ),
    );
  }

  /// Gets the audio tracks of an input.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<InputAudioTracksResponse> getInputAudioTracks({
    String? inputName,
    String? inputUuid,
  }) async {
    if (inputName == null && inputUuid == null) {
      throw ArgumentError('inputName or inputUuid must be provided');
    }

    final response = await obsWebSocket.sendRequest(
      Request(
        'GetInputAudioTracks',
        requestData: {'inputName': inputName, 'inputUuid': inputUuid},
      ),
    );

    return InputAudioTracksResponse.fromJson(response!.responseData!);
  }

  /// Sets the audio tracks of an input.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setInputAudioTracks({
    String? inputName,
    String? inputUuid,
    required int inputAudioTracks,
  }) async {
    if (inputName == null && inputUuid == null) {
      throw ArgumentError('inputName or inputUuid must be provided');
    }

    await obsWebSocket.sendRequest(
      Request(
        'SetInputAudioTracks',
        requestData: {
          'inputName': inputName,
          'inputUuid': inputUuid,
          'inputAudioTracks': inputAudioTracks,
        },
      ),
    );
  }

  /// Gets the items of a list property from an input's properties.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<InputPropertiesListPropertyItemsResponse>
  getInputPropertiesListPropertyItems({
    String? inputName,
    String? inputUuid,
    required String propertyName,
  }) async {
    if (inputName == null && inputUuid == null) {
      throw ArgumentError('inputName or inputUuid must be provided');
    }

    final response = await obsWebSocket.sendRequest(
      Request(
        'GetInputPropertiesListPropertyItems',
        requestData: {
          'inputName': inputName,
          'inputUuid': inputUuid,
          'propertyName': propertyName,
        },
      ),
    );

    return InputPropertiesListPropertyItemsResponse.fromJson(
      response!.responseData!,
    );
  }

  /// Presses a button in the input's properties.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> pressInputPropertiesButton({
    String? inputName,
    String? inputUuid,
    required String propertyName,
  }) async {
    if (inputName == null && inputUuid == null) {
      throw ArgumentError('inputName or inputUuid must be provided');
    }

    await obsWebSocket.sendRequest(
      Request(
        'PressInputPropertiesButton',
        requestData: {
          'inputName': inputName,
          'inputUuid': inputUuid,
          'propertyName': propertyName,
        },
      ),
    );
  }
}
