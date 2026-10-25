import 'dart:async';
import 'dart:convert';

import 'package:loggy/loggy.dart';
import 'package:obs_websocket/obs_websocket.dart';
import 'package:obs_websocket/src/connect.dart';
import 'package:obs_websocket/request.dart' as request;
import 'package:universal_io/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Connection lifecycle states emitted by [ObsWebSocket.onConnectionStateChanged].
enum ObsConnectionState {
  /// Initial state before any connection attempt completes.
  disconnected,

  /// Authentication handshake has finished and the socket is usable.
  connected,

  /// The socket dropped and a reconnect attempt is in progress.
  reconnecting,

  /// All reconnect attempts failed; the client is no longer usable.
  failed,
}

class ObsWebSocket with UiLoggy {
  WebSocketChannel websocketChannel;

  Stream<dynamic> broadcastStream;

  final String? password;

  final Function? onDone;

  final List<Function> fallbackHandlers = [];

  final eventHandlers = <String, List<Function>>{};

  final fromJsonSingleton = FromJsonSingleton();

  /// When non-null, [_attemptReconnect] will recreate the underlying
  /// WebSocket using these credentials after the broadcast stream closes.
  /// The password is reused from [password] on this same instance, so the
  /// reconnect path only needs to remember the URL and timeout.
  String? _reconnectUrl;
  Duration _reconnectTimeout = const Duration(seconds: 120);
  bool _autoReconnect = false;
  bool _reconnecting = false;
  bool _userClosed = false;
  int _reconnectAttempt = 0;

  /// Maximum reconnect attempts before emitting [ObsConnectionState.failed].
  static const int maxReconnectAttempts = 5;

  /// Reconnect tuning, overridable via [enableAutoReconnect].
  int _maxReconnectAttempts = maxReconnectAttempts;
  Duration _reconnectBaseDelay = const Duration(milliseconds: 200);
  Duration _reconnectMaxDelay = const Duration(seconds: 5);

  final StreamController<ObsConnectionState> _connectionStateController =
      StreamController<ObsConnectionState>.broadcast();

  ObsConnectionState _connectionState = ObsConnectionState.disconnected;

  /// Latest [ObsConnectionState] observed by the client.
  ObsConnectionState get connectionState => _connectionState;

  /// Broadcast stream of [ObsConnectionState] transitions. Useful for UIs
  /// or MCP servers that want to react when OBS goes offline and recovers.
  Stream<ObsConnectionState> get onConnectionStateChanged =>
      _connectionStateController.stream;

  request.Config? _config;

  request.Canvas? _canvas;

  request.Filters? _filters;

  request.General? _general;

  request.Inputs? _inputs;

  request.MediaInputs? _mediaInputs;

  request.Outputs? _outputs;

  request.Scenes? _scenes;

  request.SceneItems? _sceneItems;

  request.Record? _record;

  request.Sources? _sources;

  request.Stream? _stream;

  request.Transitions? _transitions;

  request.Ui? _ui;

  bool handshakeComplete = false;

  int? _negotiatedRpcVersion;

  int messageId = 0;

  int get negotiatedRpcVersion => handshakeComplete
      ? _negotiatedRpcVersion!
      : throw const ObsAuthenticationException('Authentication not completed');

  request.Config get config => _config!;

  request.Canvas get canvas => _canvas!;

  request.Filters get filters => _filters!;

  request.General get general => _general!;

  request.Inputs get inputs => _inputs!;

  request.MediaInputs get mediaInputs => _mediaInputs!;

  request.Outputs get outputs => _outputs!;

  request.Record get record => _record!;

  request.Scenes get scenes => _scenes!;

  request.SceneItems get sceneItems => _sceneItems!;

  request.Sources get sources => _sources!;

  request.Stream get stream => _stream!;

  request.Transitions get transitions => _transitions!;

  request.Ui get ui => _ui!;

  static Map<int, int> opCodeResponseMap = {
    WebSocketOpCode.identify.code: WebSocketOpCode.identified.code,
    WebSocketOpCode.request.code: WebSocketOpCode.requestResponse.code,
    WebSocketOpCode.requestBatch.code:
        WebSocketOpCode.requestBatchResponse.code,
  };

  ///When the object is created we open the websocket connection and create a
  ///broadcast stream so that we can have multiple listeners providing responses
  ///to commands. [websocketChannel] is an existing [WebSocketChannel].
  ObsWebSocket(
    this.websocketChannel, {
    this.password,
    this.onDone,
    Function? fallbackEventHandler,
  }) : broadcastStream = websocketChannel.stream.asBroadcastStream() {
    _config = request.Config(this);

    _canvas = request.Canvas(this);

    _filters = request.Filters(this);

    _general = request.General(this);

    _inputs = request.Inputs(this);

    _mediaInputs = request.MediaInputs(this);

    _outputs = request.Outputs(this);

    _record = request.Record(this);

    _scenes = request.Scenes(this);

    _sceneItems = request.SceneItems(this);

    _sources = request.Sources(this);

    _stream = request.Stream(this);

    _transitions = request.Transitions(this);

    _ui = request.Ui(this);

    if (fallbackEventHandler != null) {
      addFallbackListener(fallbackEventHandler);
    }
  }

  static Future<ObsWebSocket> connect(
    String connectUrl, {
    String? password,
    Duration timeout = const Duration(seconds: 120),
    void Function()? onDone,
    Function? fallbackEventHandler,
    bool autoReconnect = false,
    LogOptions logOptions = const LogOptions(
      LogLevel.error,
      stackTraceLevel: LogLevel.off,
    ),
    LoggyPrinter printer = const PrettyPrinter(showColors: false),
  }) async {
    Loggy.initLoggy(logPrinter: printer, logOptions: logOptions);

    connectUrl = _normalizeConnectUrl(connectUrl);

    logDebug('connecting to $connectUrl');

    final webSocketChannel = await Connect().connect(
      connectUrl: connectUrl,
      timeout: timeout,
    );

    final obsWebSocket = ObsWebSocket(
      webSocketChannel,
      password: password,
      onDone: onDone,
      fallbackEventHandler: fallbackEventHandler,
    );

    if (autoReconnect) {
      obsWebSocket._autoReconnect = true;
      obsWebSocket._reconnectUrl = connectUrl;
      obsWebSocket._reconnectTimeout = timeout;
    }

    logDebug('connected');

    await obsWebSocket.init();
    obsWebSocket._setConnectionState(ObsConnectionState.connected);

    return obsWebSocket;
  }

  /// Connects to OBS using credentials from environment variables or a `.env`
  /// file.
  ///
  /// **Priority order (highest to lowest):**
  ///   1. System environment variables: `OBS_WEBSOCKET_URL`, `OBS_WEBSOCKET_PASSWORD`,
  ///      `OBS_WEBSOCKET_TIMEOUT`
  ///   2. `.env` file in the current working directory (Dart VM only)
  ///   3. Compile-time values from `ObsEnv` (generated by build_runner)
  ///
  /// **Required `.env` file format:**
  /// ```env
  /// OBS_WEBSOCKET_URL=ws://localhost:4455
  /// OBS_WEBSOCKET_PASSWORD=your_password
  /// OBS_WEBSOCKET_TIMEOUT=120
  /// ```
  ///
  /// **Example usage:**
  /// ```dart
  /// final obs = await ObsWebSocket.connectFromEnv();
  /// ```
  ///
  /// **Platform support:**
  /// - **Dart VM (CLI/Server):** Full `.env` file support
  /// - **Flutter Web:** Use system environment variables at build time (`--dart-define`)
  ///   or provide credentials programmatically via [ObsWebSocket.connect()]
  /// - **Flutter Mobile:** Use app-specific storage (SharedPreferences, etc.) and
  ///   call [ObsWebSocket.connect()] directly
  ///
  /// Returns `null` if no URL is configured.
  static Future<ObsWebSocket?> connectFromEnv({
    Duration timeout = const Duration(seconds: 120),
    void Function()? onDone,
    Function? fallbackEventHandler,
    LogOptions logOptions = const LogOptions(
      LogLevel.error,
      stackTraceLevel: LogLevel.off,
    ),
    LoggyPrinter printer = const PrettyPrinter(showColors: false),
  }) async {
    Loggy.initLoggy(logPrinter: printer, logOptions: logOptions);

    // Load credentials from environment variables or runtime .env file
    final credentials = _loadCredentialsFromEnv();

    final url = credentials['url'] ?? '';
    if (url.isEmpty) {
      logDebug('No OBS_WEBSOCKET_URL found in environment or .env file');
      return null;
    }

    final password = credentials['password'] ?? '';
    final timeoutSeconds =
        int.tryParse(credentials['timeout'] ?? '') ?? timeout.inSeconds;

    return connect(
      url,
      password: password.isEmpty ? null : password,
      timeout: Duration(seconds: timeoutSeconds),
      onDone: onDone,
      fallbackEventHandler: fallbackEventHandler,
      logOptions: logOptions,
      printer: printer,
    );
  }

  /// Loads OBS credentials from system environment variables or .env file.
  /// System environment variables take precedence over .env values.
  ///
  /// **Note:** `.env` file loading only works on Dart VM where file system
  /// access is available. For web/mobile platforms, use environment variables
  /// or provide credentials via [ObsWebSocket.connect()].
  static Map<String, String> _loadCredentialsFromEnv() {
    // System environment variables have highest priority
    String? url = Platform.environment['OBS_WEBSOCKET_URL'];
    String? password = Platform.environment['OBS_WEBSOCKET_PASSWORD'];
    String? timeout = Platform.environment['OBS_WEBSOCKET_TIMEOUT'];

    // If not in system env, try to load from .env file in current directory
    // (Dart VM only - not available on web/mobile)
    if (url == null || password == null || timeout == null) {
      final envFile = _findEnvFile();
      if (envFile != null) {
        final envVars = ObsUtil.parseDotenvFile(envFile);
        url ??= envVars['OBS_WEBSOCKET_URL'];
        password ??= envVars['OBS_WEBSOCKET_PASSWORD'];
        timeout ??= envVars['OBS_WEBSOCKET_TIMEOUT'];
      }
    }

    // Return what we found (empty string for url means not configured)
    return {
      'url': url ?? '',
      'password': password ?? '',
      'timeout': timeout ?? '120',
    };
  }

  /// Searches for .env file in the current working directory only.
  ///
  /// **Note:** This only works on Dart VM with file system access.
  /// On web/mobile platforms, this will return `null`.
  static File? _findEnvFile() {
    try {
      final envFile = File('.env');
      if (envFile.existsSync()) {
        logDebug('Found .env file at ${envFile.absolute.path}');
        return envFile;
      }
    } catch (e) {
      // File system not available (web/mobile)
      logDebug('.env file loading not supported on this platform');
    }

    return null;
  }

  /// Validates [input] and returns a normalized `ws://` or `wss://` URL.
  ///
  /// - A scheme-less input like `host:4455` is prefixed with `ws://`.
  /// - `ws://` and `wss://` are preserved as-is.
  /// - Any other scheme (http, wss typo, ftp, ...) throws
  ///   [ObsArgumentException] so callers never get a silently rewritten URL.
  static String _normalizeConnectUrl(String input) {
    final parsed = Uri.tryParse(input);
    if (parsed == null) {
      throw ObsArgumentException('Invalid WebSocket URL: $input');
    }
    if (parsed.scheme.isEmpty) {
      return 'ws://$input';
    }
    if (parsed.scheme != 'ws' && parsed.scheme != 'wss') {
      throw ObsArgumentException(
        'Only ws:// and wss:// schemes are supported, got ${parsed.scheme}://',
      );
    }
    return input;
  }

  Future<void> init() async {
    broadcastStream.listen(
      (message) {
        final opcode = Opcode.fromJson(json.decode(message));

        if (opcode.op == WebSocketOpCode.event.code) {
          final event = Event.fromJson(opcode.d);

          loggy.debug('event: $event');

          _handleEvent(event);
        }
      },
      onDone: _handleStreamClosed,
      onError: (Object error, StackTrace st) {
        loggy.warning('broadcastStream error: $error');
        _handleStreamClosed();
      },
      cancelOnError: false,
    );

    await authenticate();

    if (!_userClosed) _setConnectionState(ObsConnectionState.connected);
  }

  /// Enables automatic reconnection for a client built directly from a
  /// [WebSocketChannel] — the path web/dart2js builds take, because [connect]
  /// cannot create the channel there. Call after [init] completes the
  /// handshake; retries use exponential backoff from [baseDelay] up to
  /// [maxDelay], giving up after [maxAttempts] consecutive failures.
  void enableAutoReconnect(
    String connectUrl, {
    Duration timeout = const Duration(seconds: 120),
    int maxAttempts = maxReconnectAttempts,
    Duration baseDelay = const Duration(milliseconds: 200),
    Duration maxDelay = const Duration(seconds: 5),
  }) {
    _reconnectUrl = _normalizeConnectUrl(connectUrl);
    _reconnectTimeout = timeout;
    _maxReconnectAttempts = maxAttempts;
    _reconnectBaseDelay = baseDelay;
    _reconnectMaxDelay = maxDelay;
    _autoReconnect = true;
    if (handshakeComplete) _setConnectionState(ObsConnectionState.connected);
  }

  /// Sends `GetVersion` and returns the parsed [VersionResponse]. A cheap
  /// liveness probe that doubles as a feature-flag query.
  Future<VersionResponse> ping() async {
    return general.getVersion();
  }

  /// Awaits the first OBS event whose `eventType` equals [eventType] and
  /// (optionally) satisfies [predicate]. Throws [TimeoutException] if no
  /// matching event arrives before [timeout].
  ///
  /// Returns the raw [Event] object. Callers may downcast or look up the
  /// concrete event class via [FromJsonSingleton].
  Future<Event> waitForEvent({
    required String eventType,
    bool Function(Event event)? predicate,
    Duration? timeout,
  }) {
    final completer = Completer<Event>();

    void handler(Event event) {
      if (event.eventType != eventType) return;
      if (predicate != null && !predicate(event)) return;
      if (!completer.isCompleted) completer.complete(event);
    }

    addFallbackListener(handler);

    Future<Event> resultFuture = completer.future;
    if (timeout != null) {
      resultFuture = resultFuture.timeout(timeout);
    }

    return resultFuture.whenComplete(() => removeFallbackListener(handler));
  }

  /// Typed convenience wrapper around [waitForEvent].
  ///
  /// Awaits the first event whose `eventType` equals [eventType], optionally
  /// passes the decoded class through [predicate], and returns the typed
  /// instance produced by [FromJsonSingleton].
  ///
  /// Example:
  /// ```dart
  /// final ev = await obs.waitForTypedEvent<RecordStateChanged>(
  ///   eventType: 'RecordStateChanged',
  ///   predicate: (e) => e.outputActive == true,
  ///   timeout: const Duration(seconds: 5),
  /// );
  /// ```
  Future<T> waitForTypedEvent<T>({
    required String eventType,
    bool Function(T event)? predicate,
    Duration? timeout,
  }) async {
    final factory = fromJsonSingleton.factories[eventType];
    if (factory == null) {
      throw ObsArgumentException(
        'No FromJsonSingleton factory registered for eventType="$eventType"',
      );
    }

    final raw = await waitForEvent(
      eventType: eventType,
      predicate: predicate == null
          ? null
          : (event) {
              final typed = factory(event.eventData ?? {}) as T;
              return predicate(typed);
            },
      timeout: timeout,
    );

    return factory(raw.eventData ?? {}) as T;
  }

  /// Called whenever the underlying broadcast stream closes (network drop,
  /// OBS restart, or normal `close()`). Triggers a reconnect when
  /// [_autoReconnect] is enabled and the user did not call [close].
  void _handleStreamClosed() {
    handshakeComplete = false;
    if (_userClosed || !_autoReconnect || _reconnecting) {
      _setConnectionState(ObsConnectionState.disconnected);
      return;
    }
    unawaited(_attemptReconnect());
  }

  Future<void> _attemptReconnect() async {
    final url = _reconnectUrl;
    if (url == null) return;

    _reconnecting = true;
    _setConnectionState(ObsConnectionState.reconnecting);

    while (_reconnectAttempt < _maxReconnectAttempts) {
      _reconnectAttempt++;
      final backoffMs =
          (_reconnectBaseDelay.inMilliseconds * (1 << (_reconnectAttempt - 1)))
              .clamp(
                _reconnectBaseDelay.inMilliseconds,
                _reconnectMaxDelay.inMilliseconds,
              );
      loggy.warning(
        'OBS WebSocket disconnected. Reconnect attempt '
        '$_reconnectAttempt/$_maxReconnectAttempts in ${backoffMs}ms',
      );
      await Future<void>.delayed(Duration(milliseconds: backoffMs));

      try {
        final newChannel = await Connect().connect(
          connectUrl: url,
          timeout: _reconnectTimeout,
        );
        websocketChannel = newChannel;
        broadcastStream = newChannel.stream.asBroadcastStream();
        await init();
        _reconnectAttempt = 0;
        _reconnecting = false;
        _setConnectionState(ObsConnectionState.connected);
        return;
      } catch (error, st) {
        loggy.warning('Reconnect attempt failed: $error', error, st);
      }
    }

    _reconnecting = false;
    _setConnectionState(ObsConnectionState.failed);
  }

  void _setConnectionState(ObsConnectionState state) {
    if (_connectionState == state) return;
    _connectionState = state;
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(state);
    }
  }

  Future<void> authenticate() async {
    loggy.debug('starting handshake');

    final helloOpcode = await getStreamOpcode(WebSocketOpCode.hello.code);

    if (helloOpcode == null) {
      throw const ObsConnectionException(
        'Handshake error: no Hello opcode received from server',
      );
    }

    final hello = Hello.fromJson(helloOpcode.d);

    final Authentication? authentication = hello.authentication;

    String? authToken;

    if (authentication != null) {
      logDebug('authenticating with supplied password');

      final secret = ObsUtil.base64Hash('$password${authentication.salt}');

      authToken = ObsUtil.base64Hash('$secret${authentication.challenge}');
    } else {
      logDebug('authenticating anonymously');
    }

    final identifyOpcode = Identify(
      rpcVersion: hello.rpcVersion,
      authentication: authToken,
      eventSubscriptions: EventSubscription.none.code,
    ).toOpcode();

    final identifiedOpcode = await sendOpcode(identifyOpcode);

    if (identifiedOpcode == null) {
      throw const ObsAuthenticationException(
        'Authentication error: no Identified opcode received from server',
      );
    }

    final identified = Identified.fromJson(identifiedOpcode.d);

    _negotiatedRpcVersion = identified.negotiatedRpcVersion;

    handshakeComplete = true;

    loggy.debug('negotiatedRpcVersion: $negotiatedRpcVersion');

    loggy.debug('handshake complete');
  }

  Future<Opcode?> getStreamOpcode(int? webSocketOpCode) async {
    Opcode? opcode;

    if (webSocketOpCode == null) {
      return null;
    }

    await for (String message in broadcastStream) {
      loggy.debug('rcv raw opcode: $message');

      opcode = Opcode.fromJson(json.decode(message));

      if (opcode.op == webSocketOpCode) {
        return opcode;
      }
    }

    return opcode;
  }

  Future<Opcode?> sendOpcode(Opcode opcode) async {
    loggy.debug('send opcode: $opcode');

    websocketChannel.sink.add(opcode.toString());

    return await getStreamOpcode(opCodeResponseMap[opcode.op]);
  }

  /// Listen to a specific event subscription, the original code
  Future<void> listenForMask(int eventSubscriptions) async => await sendOpcode(
    ReIdentifyOpcode(ReIdentify(eventSubscriptions: eventSubscriptions)),
  );

  /// Listen to a specific event subscription.
  @Deprecated('Use subscribe instead')
  Future<void> listen(dynamic eventSubscription) async =>
      await listenForMask(switch (eventSubscription.runtimeType) {
        const (EventSubscription) => eventSubscription.code,
        const (int) => eventSubscription,
        _ => 0,
      });

  /// subscribe to all events based on the [eventSubscription] mask.
  /// Can accept either an EventSubscription enum value or an int from combining subscriptions.
  Future<void> subscribe(dynamic eventSubscription) async {
    if (eventSubscription is EventSubscription) {
      await listenForMask(eventSubscription.code);
    } else if (eventSubscription is int) {
      await listenForMask(eventSubscription);
    } else {
      throw ObsArgumentException(
        'eventSubscription must be either EventSubscription or int, got ${eventSubscription.runtimeType}',
      );
    }
  }

  /// Look at the raw [event] data and run the appropriate event handler
  void _handleEvent(Event event) {
    final listeners = eventHandlers[event.eventType] ?? [];

    if (listeners.isNotEmpty) {
      for (var handler in listeners) {
        if (fromJsonSingleton.factories.containsKey(event.eventType)) {
          handler(
            fromJsonSingleton.factories[event.eventType]!(
              event.eventData ?? {},
            ),
          );
        }
      }
    } else {
      _fallback(event);
    }
  }

  ///Before execution finished the websocket needs to be closed
  Future<void> close() async {
    _userClosed = true;
    if (onDone != null) onDone!();

    await websocketChannel.sink.close(status.normalClosure);
    _setConnectionState(ObsConnectionState.disconnected);
    if (!_connectionStateController.isClosed) {
      await _connectionStateController.close();
    }
  }

  ///Add an event handler for the event type [T]
  void addHandler<T>(Function listener) {
    eventHandlers['$T'] ??= <Function>[];

    eventHandlers['$T']?.add(listener);
  }

  ///Remove an event handler for the event type [T]
  void removeHandler<T>(Function listener) {
    eventHandlers['$T'] ??= <Function>[];

    eventHandlers['$T']?.remove(listener);
  }

  ///Add an event handler for an event that don't have a specific class
  void addFallbackListener(Function listener) {
    fallbackHandlers.add(listener);
  }

  ///Remove an event handler for an event that don't have a specific class
  void removeFallbackListener(Function listener) {
    fallbackHandlers.remove(listener);
  }

  ///Handler when none of the others match the event class
  void _fallback(Event event) {
    for (var handler in fallbackHandlers) {
      handler(event);
    }
  }

  Future<RequestResponse?> send(
    String command, [
    Map<String, dynamic>? args,
  ]) async => await sendRequest(Request(command, requestData: args));

  Future<RequestBatchResponse> sendBatch(List<Request> requests) async {
    RequestBatchResponse? requestBatchResponse;

    final requestBatch = RequestBatch(requests: requests);

    final requestBatchOpcode = requestBatch.toOpcode();

    loggy.debug('send batch: $requestBatchOpcode');

    websocketChannel.sink.add(requestBatchOpcode.toString());

    await for (String message in broadcastStream) {
      final response = Opcode.fromJson(json.decode(message));

      loggy.debug('response raw: $message');

      if (response.op == WebSocketOpCode.requestBatchResponse.code) {
        requestBatchResponse = RequestBatchResponse.fromJson(response.d);

        loggy.debug(
          'batch response size: ${requestBatchResponse.results.length}',
        );

        if (requestBatchResponse.requestId == requestBatch.requestId) break;
      }
    }

    if (requestBatchResponse == null) {
      throw const ObsConnectionException(
        'Batch response not received before stream closed',
      );
    }

    return requestBatchResponse;
  }

  Future<RequestResponse?> sendRequest(Request request) async {
    RequestResponse? requestResponse;

    loggy.debug('send ${request.requestType}: ${request.toOpcode()}');

    websocketChannel.sink.add(request.toOpcode().toString());

    await for (String message in broadcastStream) {
      final response = Opcode.fromJson(json.decode(message));

      loggy.debug('response raw: $message');

      if (response.op == WebSocketOpCode.requestResponse.code) {
        requestResponse = RequestResponse.fromJson(response.d);

        loggy.debug(
          'response status: ${requestResponse.requestType} ${requestResponse.requestStatus}',
        );

        if (request.requestId == requestResponse.requestId) {
          _checkResponse(request, requestResponse);

          break;
        }
      }
    }

    return requestResponse;
  }

  void _checkResponse(Request request, RequestResponse response) {
    if (request.hasResponseData && !response.requestStatus.result) {
      throw ObsRequestException(
        requestType: request.requestType,
        code: response.requestStatus.code,
        comment: response.requestStatus.comment,
        stackTrace: StackTrace.current,
      );
    }
  }
}
