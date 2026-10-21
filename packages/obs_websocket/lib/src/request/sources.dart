import 'package:obs_websocket/obs_websocket.dart';

/// Sources Requests
class Sources {
  final ObsWebSocket obsWebSocket;

  Sources(this.obsWebSocket);

  /// Gets the active and show state of a source.
  ///
  /// Compatible with inputs and scenes.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<SourceActiveResponse> getSourceActive(
    String? sourceName, {
    String? sourceUuid,
    String? canvasUuid,
  }) async =>
      await active(sourceName, sourceUuid: sourceUuid, canvasUuid: canvasUuid);

  /// Gets the active and show state of a source.
  ///
  /// Compatible with inputs and scenes.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<SourceActiveResponse> active(
    String? sourceName, {
    String? sourceUuid,
    String? canvasUuid,
  }) async {
    if (sourceName == null && sourceUuid == null) {
      throw ArgumentError('sourceName or sourceUuid must be provided');
    }

    final response = await obsWebSocket.sendRequest(
      Request(
        'GetSourceActive',
        requestData: {
          'sourceName': ?sourceName,
          'sourceUuid': ?sourceUuid,
          'canvasUuid': ?canvasUuid,
        },
      ),
    );

    return SourceActiveResponse.fromJson(response!.responseData!);
  }

  /// Gets a Base64-encoded screenshot of a source.
  ///
  /// The imageWidth and imageHeight parameters are treated as "scale to inner", meaning the smallest ratio will be used and the aspect ratio of the original resolution is kept. If imageWidth and imageHeight are not specified, the compressed image will use the full resolution of the source.
  ///
  /// Compatible with inputs and scenes.
  ///
  /// - Complexity Rating: 4/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<SourceScreenshotResponse> getSourceScreenshot(
    SourceScreenshot sourceScreenshot,
  ) async => await screenshot(sourceScreenshot);

  /// Gets a Base64-encoded screenshot of a source.
  ///
  /// The imageWidth and imageHeight parameters are treated as "scale to inner", meaning the smallest ratio will be used and the aspect ratio of the original resolution is kept. If imageWidth and imageHeight are not specified, the compressed image will use the full resolution of the source.
  ///
  /// Compatible with inputs and scenes.
  ///
  /// - Complexity Rating: 4/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<SourceScreenshotResponse> screenshot(
    SourceScreenshot sourceScreenshot,
  ) async {
    final response = await obsWebSocket.sendRequest(
      Request('GetSourceScreenshot', requestData: sourceScreenshot.toJson()),
    );

    return SourceScreenshotResponse.fromJson(response!.responseData!);
  }

  /// Saves a screenshot of a source to the filesystem.
  ///
  /// The imageWidth and imageHeight parameters are treated as "scale to inner", meaning the smallest ratio will be used and the aspect ratio of the original resolution is kept. If imageWidth and imageHeight are not specified, the compressed image will use the full resolution of the source.
  ///
  /// Compatible with inputs and scenes.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<SourceScreenshotResponse> saveSourceScreenshot(
    SourceScreenshot sourceScreenshot,
  ) async => await saveScreenshot(sourceScreenshot);

  /// Saves a screenshot of a source to the filesystem.
  ///
  /// The imageWidth and imageHeight parameters are treated as "scale to inner", meaning the smallest ratio will be used and the aspect ratio of the original resolution is kept. If imageWidth and imageHeight are not specified, the compressed image will use the full resolution of the source.
  ///
  /// Compatible with inputs and scenes.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<SourceScreenshotResponse> saveScreenshot(
    SourceScreenshot sourceScreenshot,
  ) async {
    final response = await obsWebSocket.sendRequest(
      Request('SaveSourceScreenshot', requestData: sourceScreenshot.toJson()),
    );

    return SourceScreenshotResponse.fromJson(response!.responseData!);
  }

  /// Gets the private settings of a source. This request is mainly just used
  /// in interacting with global sources (e.g. Global Audio Devices).
  ///
  /// Note: Source UUIDs are supported via [sourceUuid].
  ///
  /// - Complexity Rating: 4/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.6.0
  Future<Map<String, dynamic>> getSourcePrivateSettings({
    String? sourceName,
    String? sourceUuid,
  }) async {
    final response = await obsWebSocket.sendRequest(
      Request(
        'GetSourcePrivateSettings',
        requestData: {'sourceName': ?sourceName, 'sourceUuid': ?sourceUuid},
      ),
    );

    return response!.responseData!;
  }

  /// Sets the private settings of a source. This request is mainly just used
  /// in interacting with global sources (e.g. Global Audio Devices).
  ///
  /// Note: Source UUIDs are supported via [sourceUuid].
  ///
  /// - Complexity Rating: 4/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.6.0
  Future<void> setSourcePrivateSettings({
    String? sourceName,
    String? sourceUuid,
    required Map<String, dynamic> sourceSettings,
  }) async => await obsWebSocket.sendRequest(
    Request(
      'SetSourcePrivateSettings',
      requestData: {
        'sourceName': ?sourceName,
        'sourceUuid': ?sourceUuid,
        'sourceSettings': sourceSettings,
      },
    ),
  );
}
