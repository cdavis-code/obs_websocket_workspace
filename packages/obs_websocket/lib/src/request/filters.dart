import 'package:obs_websocket/obs_websocket.dart';

/// Filters Requests
class Filters {
  final ObsWebSocket obsWebSocket;

  Filters(this.obsWebSocket);

  /// Builds and validates the source identifier fields shared by all filter
  /// requests. One of [sourceName] or [sourceUuid] is required.
  Map<String, dynamic> _sourceData(
    String? sourceName,
    String? sourceUuid,
    String? canvasUuid,
  ) {
    if (sourceName == null && sourceUuid == null) {
      throw ArgumentError('sourceName or sourceUuid must be provided');
    }

    return {
      'sourceName': ?sourceName,
      'sourceUuid': ?sourceUuid,
      'canvasUuid': ?canvasUuid,
    };
  }

  /// Removes a filter from a source.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> removeSource({
    String? sourceName,
    String? sourceUuid,
    String? canvasUuid,
    required String filterName,
  }) async => await removeSourceFilter(
    sourceName: sourceName,
    sourceUuid: sourceUuid,
    canvasUuid: canvasUuid,
    filterName: filterName,
  );

  /// Removes a filter from a source.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> removeSourceFilter({
    String? sourceName,
    String? sourceUuid,
    String? canvasUuid,
    required String filterName,
  }) async => await obsWebSocket.sendRequest(
    Request(
      'RemoveSourceFilter',
      requestData: {
        ..._sourceData(sourceName, sourceUuid, canvasUuid),
        'filterName': filterName,
      },
    ),
  );

  /// Sets the name of a source filter (rename).
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setSourceName({
    String? sourceName,
    String? sourceUuid,
    String? canvasUuid,
    required String filterName,
    required String newFilterName,
  }) async => await setSourceFilterName(
    sourceName: sourceName,
    sourceUuid: sourceUuid,
    canvasUuid: canvasUuid,
    filterName: filterName,
    newFilterName: newFilterName,
  );

  /// Sets the name of a source filter (rename).
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setSourceFilterName({
    String? sourceName,
    String? sourceUuid,
    String? canvasUuid,
    required String filterName,
    required String newFilterName,
  }) async => await obsWebSocket.sendRequest(
    Request(
      'SetSourceFilterName',
      requestData: {
        ..._sourceData(sourceName, sourceUuid, canvasUuid),
        'filterName': filterName,
        'newFilterName': newFilterName,
      },
    ),
  );

  /// Sets the index position of a filter on a source.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setSourceIndex({
    String? sourceName,
    String? sourceUuid,
    String? canvasUuid,
    required String filterName,
    required int filterIndex,
  }) async => await setSourceFilterIndex(
    sourceName: sourceName,
    sourceUuid: sourceUuid,
    canvasUuid: canvasUuid,
    filterName: filterName,
    filterIndex: filterIndex,
  );

  /// Sets the index position of a filter on a source.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setSourceFilterIndex({
    String? sourceName,
    String? sourceUuid,
    String? canvasUuid,
    required String filterName,
    required int filterIndex,
  }) async => await obsWebSocket.sendRequest(
    Request(
      'SetSourceFilterIndex',
      requestData: {
        ..._sourceData(sourceName, sourceUuid, canvasUuid),
        'filterName': filterName,
        'filterIndex': filterIndex,
      },
    ),
  );

  /// Sets the enable state of a source filter.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setSourceEnabled({
    String? sourceName,
    String? sourceUuid,
    String? canvasUuid,
    required String filterName,
    required bool filterEnabled,
  }) async => await setSourceFilterEnabled(
    sourceName: sourceName,
    sourceUuid: sourceUuid,
    canvasUuid: canvasUuid,
    filterName: filterName,
    filterEnabled: filterEnabled,
  );

  /// Sets the enable state of a source filter.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setSourceFilterEnabled({
    String? sourceName,
    String? sourceUuid,
    String? canvasUuid,
    required String filterName,
    required bool filterEnabled,
  }) async => await obsWebSocket.sendRequest(
    Request(
      'SetSourceFilterEnabled',
      requestData: {
        ..._sourceData(sourceName, sourceUuid, canvasUuid),
        'filterName': filterName,
        'filterEnabled': filterEnabled,
      },
    ),
  );

  /// Gets an array of all available source filter kinds.
  ///
  /// Similar to `GetInputKindList`.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.4.0
  Future<List<String>> getSourceFilterKindList() async {
    final response = await obsWebSocket.sendRequest(
      Request('GetSourceFilterKindList'),
    );

    return (response!.responseData!['sourceFilterKinds'] as List)
        .cast<String>();
  }

  /// Gets an array of all of a source's filters.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<List<Map<String, dynamic>>> getSourceFilterList(
    String? sourceName, {
    String? sourceUuid,
    String? canvasUuid,
  }) async {
    final response = await obsWebSocket.sendRequest(
      Request(
        'GetSourceFilterList',
        requestData: _sourceData(sourceName, sourceUuid, canvasUuid),
      ),
    );

    return (response!.responseData!['filters'] as List)
        .cast<Map<String, dynamic>>();
  }

  /// Gets the default settings for a filter kind.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<Map<String, dynamic>> getSourceFilterDefaultSettings(
    String filterKind,
  ) async {
    final response = await obsWebSocket.sendRequest(
      Request(
        'GetSourceFilterDefaultSettings',
        requestData: {'filterKind': filterKind},
      ),
    );

    return response!.responseData!['defaultFilterSettings']
        as Map<String, dynamic>;
  }

  /// Creates a new filter, adding it to the specified source.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> createSourceFilter({
    String? sourceName,
    String? sourceUuid,
    String? canvasUuid,
    required String filterName,
    required String filterKind,
    Map<String, dynamic>? filterSettings,
  }) async => await obsWebSocket.sendRequest(
    Request(
      'CreateSourceFilter',
      requestData: {
        ..._sourceData(sourceName, sourceUuid, canvasUuid),
        'filterName': filterName,
        'filterKind': filterKind,
        'filterSettings': ?filterSettings,
      },
    ),
  );

  /// Gets the info for a specific source filter.
  ///
  /// - Complexity Rating: 2/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<Map<String, dynamic>> getSourceFilter({
    String? sourceName,
    String? sourceUuid,
    String? canvasUuid,
    required String filterName,
  }) async {
    final response = await obsWebSocket.sendRequest(
      Request(
        'GetSourceFilter',
        requestData: {
          ..._sourceData(sourceName, sourceUuid, canvasUuid),
          'filterName': filterName,
        },
      ),
    );

    return response!.responseData!;
  }

  /// Sets the settings of a source filter.
  ///
  /// - Complexity Rating: 3/5
  /// - Latest Supported RPC Version: 1
  /// - Added in v5.0.0
  Future<void> setSourceFilterSettings({
    String? sourceName,
    String? sourceUuid,
    String? canvasUuid,
    required String filterName,
    required Map<String, dynamic> filterSettings,
    bool? overlay,
  }) async => await obsWebSocket.sendRequest(
    Request(
      'SetSourceFilterSettings',
      requestData: {
        ..._sourceData(sourceName, sourceUuid, canvasUuid),
        'filterName': filterName,
        'filterSettings': filterSettings,
        'overlay': ?overlay,
      },
    ),
  );
}
