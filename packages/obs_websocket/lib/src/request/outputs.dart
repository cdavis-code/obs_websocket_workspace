import 'package:obs_websocket/obs_websocket.dart';

/// Outputs Requests
class Outputs {
  final ObsWebSocket obsWebSocket;

  Outputs(this.obsWebSocket);

  /// Gets the status of the virtualcam output.
  ///
  /// - Complexity Rating: 1/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<bool> getVirtualCamStatus() async {
    final response = await obsWebSocket.sendRequest(
      Request('GetVirtualCamStatus'),
    );

    return BooleanResponse.fromJson(response!.responseData!).enabled;
  }

  /// Toggles the state of the virtualcam output.
  ///
  /// - Complexity Rating: 1/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<bool> toggleVirtualCam() async {
    final response = await obsWebSocket.sendRequest(
      Request('ToggleVirtualCam'),
    );

    return BooleanResponse.fromJson(response!.responseData!).enabled;
  }

  /// Starts the virtualcam output.
  ///
  /// - Complexity Rating: 1/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> startVirtualCam() async =>
      await obsWebSocket.sendRequest(Request('StartVirtualCam'));

  /// Stops the virtualcam output.
  ///
  /// - Complexity Rating: 1/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> stopVirtualCam() async =>
      await obsWebSocket.sendRequest(Request('StopVirtualCam'));

  /// Gets the status of the replay buffer output.
  ///
  /// - Complexity Rating: 1/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<bool> getReplayBufferStatus() async {
    final response = await obsWebSocket.sendRequest(
      Request('GetReplayBufferStatus'),
    );

    return BooleanResponse.fromJson(response!.responseData!).enabled;
  }

  /// Toggles the state of the replay buffer output.
  ///
  /// - Complexity Rating: 1/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<bool> toggleReplayBuffer() async {
    final response = await obsWebSocket.sendRequest(
      Request('ToggleReplayBuffer'),
    );

    if (response?.requestStatus.code != 100) {
      throw Exception('${response?.requestStatus.comment}');
    }

    return BooleanResponse.fromJson(response!.responseData!).enabled;
  }

  /// Starts the replay buffer output.
  ///
  /// - Complexity Rating: 1/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> startReplayBuffer(String outputName) async =>
      await obsWebSocket.sendRequest(Request('StartReplayBuffer'));

  /// Stops the replay buffer output.
  ///
  /// - Complexity Rating: 1/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> stopReplayBuffer(String outputName) async =>
      await obsWebSocket.sendRequest(Request('StopReplayBuffer'));

  /// Saves the contents of the replay buffer output.
  ///
  /// - Complexity Rating: 1/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> saveReplayBuffer(String outputName) async =>
      await obsWebSocket.sendRequest(Request('SaveReplayBuffer'));

  /// Gets the filename of the last replay buffer save file.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<LastReplayBufferReplayResponse> getLastReplayBufferReplay() async {
    final response = await obsWebSocket.sendRequest(
      Request('GetLastReplayBufferReplay'),
    );

    return LastReplayBufferReplayResponse.fromJson(response!.responseData!);
  }

  /// Toggles the status of an output.
  ///
  /// - Complexity Rating: 4/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<bool> toggle(String outputName) async =>
      await toggleOutput(outputName);

  /// Toggles the status of an output.
  ///
  /// - Complexity Rating: 4/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<bool> toggleOutput(String outputName) async {
    final response = await obsWebSocket.sendRequest(
      Request('ToggleOutput', requestData: {'outputName': outputName}),
    );

    return BooleanResponse.fromJson(response!.responseData!).enabled;
  }

  /// Starts an output.
  ///
  /// - Complexity Rating: 4/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> startOutput(String outputName) async => await start(outputName);

  /// Starts an output.
  ///
  /// - Complexity Rating: 4/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> start(String outputName) async => await obsWebSocket.sendRequest(
    Request('StartOutput', requestData: {'outputName': outputName}),
  );

  /// Stops an output.
  ///
  /// - Complexity Rating: 1/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> stopOutput(String outputName) async => await stop(outputName);

  /// Stops an output.
  ///
  /// - Complexity Rating: 1/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> stop(String outputName) async => await obsWebSocket.sendRequest(
    Request('StopOutput', requestData: {'outputName': outputName}),
  );

  /// Gets the list of available outputs.
  ///
  /// - Complexity Rating: 4/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<List<Map<String, dynamic>>> getOutputList() async {
    final response = await obsWebSocket.sendRequest(Request('GetOutputList'));

    return (response!.responseData!['outputs'] as List)
        .cast<Map<String, dynamic>>();
  }

  /// Gets the status of an output.
  ///
  /// - Complexity Rating: 4/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<Map<String, dynamic>> getOutputStatus(String outputName) async {
    final response = await obsWebSocket.sendRequest(
      Request('GetOutputStatus', requestData: {'outputName': outputName}),
    );

    return response!.responseData!;
  }

  /// Gets the settings of an output.
  ///
  /// - Complexity Rating: 4/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<Map<String, dynamic>> getOutputSettings(String outputName) async {
    final response = await obsWebSocket.sendRequest(
      Request('GetOutputSettings', requestData: {'outputName': outputName}),
    );

    return response!.responseData!['outputSettings'] as Map<String, dynamic>;
  }

  /// Sets the settings of an output.
  ///
  /// - Complexity Rating: 4/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setOutputSettings({
    required String outputName,
    required Map<String, dynamic> outputSettings,
  }) async => await obsWebSocket.sendRequest(
    Request(
      'SetOutputSettings',
      requestData: {'outputName': outputName, 'outputSettings': outputSettings},
    ),
  );
}
