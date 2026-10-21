import 'package:obs_websocket/obs_websocket.dart';

/// Stream Requests
class Ui {
  final ObsWebSocket obsWebSocket;

  Ui(this.obsWebSocket);

  /// Enables or disables studio mode
  ///
  ///  - Complexity Rating: 1/5
  ///  - Latest Supported RPC Version: 1
  ///  - Added in v5.0.0
  Future<bool> getStudioModeEnabled() async {
    final response = await obsWebSocket.sendRequest(
      Request('GetStudioModeEnabled'),
    );

    return BooleanResponse.fromJson(response!.responseData!).enabled;
  }

  /// Enables or disables studio mode
  ///
  ///  - Complexity Rating: 1/5
  ///  - Latest Supported RPC Version: 1
  ///  - Added in v5.0.0
  Future<void> setStudioModeEnabled(bool studioModeEnabled) async =>
      await obsWebSocket.sendRequest(
        Request(
          'SetStudioModeEnabled',
          requestData: {'studioModeEnabled': studioModeEnabled},
        ),
      );

  /// Opens the properties dialog of an input.
  ///
  ///  - Complexity Rating: 1/5
  ///  - Latest Supported RPC Version: 1
  ///  - Added in v5.0.0
  Future<void> openInputPropertiesDialog(String inputName) async =>
      await obsWebSocket.sendRequest(
        Request(
          'OpenInputPropertiesDialog',
          requestData: {'inputName': inputName},
        ),
      );

  /// Opens the filters dialog of an input.
  ///
  ///  - Complexity Rating: 1/5
  ///  - Latest Supported RPC Version: 1
  ///  - Added in v5.0.0
  Future<void> openInputFiltersDialog(String inputName) async =>
      await obsWebSocket.sendRequest(
        Request(
          'OpenInputFiltersDialog',
          requestData: {'inputName': inputName},
        ),
      );

  /// Opens the interact dialog of an input.
  ///
  ///  - Complexity Rating: 1/5
  ///  - Latest Supported RPC Version: 1
  ///  - Added in v5.0.0
  Future<void> openInputInteractDialog(String inputName) async =>
      await obsWebSocket.sendRequest(
        Request(
          'OpenInputInteractDialog',
          requestData: {'inputName': inputName},
        ),
      );

  /// Gets a list of connected monitors and information about them.
  ///
  /// Complexity Rating: 2/5
  /// Latest Supported RPC Version: 1
  /// Added in v5.0.0
  Future<List<Monitor>> getMonitorList() async {
    final response = await obsWebSocket.sendRequest(Request('GetMonitorList'));

    final monitorListResponse = MonitorListResponse.fromJson(
      response!.responseData!,
    );

    return monitorListResponse.monitors;
  }

  /// Opens a projector for a specific output video mix.
  ///
  /// Mix types:
  /// - OBS_WEBSOCKET_VIDEO_MIX_TYPE_PREVIEW
  /// - OBS_WEBSOCKET_VIDEO_MIX_TYPE_PROGRAM
  /// - OBS_WEBSOCKET_VIDEO_MIX_TYPE_MULTIVIEW
  ///
  /// Note: This request serves to provide feature parity with 4.x. It is very likely to be changed/deprecated in a future release.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> openVideoMixProjector(
    String videoMixType, {
    int? monitorIndex = -1,
    String? projectorGeometry,
  }) async => await obsWebSocket.sendRequest(
    Request(
      'OpenVideoMixProjector',
      requestData: {
        'videoMixType': videoMixType,
        'monitorIndex': monitorIndex,
        'projectorGeometry': projectorGeometry,
      },
    ),
  );

  /// Opens a projector for a source.
  ///
  /// Note: This request serves to provide feature parity with 4.x. It is very likely to be changed/deprecated in a future release.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> openSourceProjector(
    String? sourceName, {
    String? sourceUuid,
    String? canvasUuid,
    int? monitorIndex = -1,
    String? projectorGeometry,
  }) async {
    if (sourceName == null && sourceUuid == null) {
      throw ArgumentError('sourceName or sourceUuid must be provided');
    }

    await obsWebSocket.sendRequest(
      Request(
        'OpenSourceProjector',
        requestData: {
          'sourceName': ?sourceName,
          'sourceUuid': ?sourceUuid,
          'canvasUuid': ?canvasUuid,
          'monitorIndex': monitorIndex,
          'projectorGeometry': projectorGeometry,
        },
      ),
    );
  }
}
