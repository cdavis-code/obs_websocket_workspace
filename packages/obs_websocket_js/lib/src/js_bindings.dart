/// JS-interop bindings that expose a minimal `obs_websocket` surface to
/// JavaScript. The TypeScript wrapper layer (src/index.ts) consumes these to
/// provide a typed, Promise/EventEmitter-based API.
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:loggy/loggy.dart';
import 'package:obs_websocket/obs_websocket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

@JS('globalThis')
external JSObject get _globalThis;

/// Installs the interop namespace on `globalThis.ObsWebSocketJs`.
/// Called once from the dart2js `main()`.
void install() {
  final ns = JSObject();
  ns.setProperty('connect'.toJS, _connect.toJS);
  ns.setProperty('version'.toJS, '5.7.4'.toJS);
  _globalThis.setProperty('ObsWebSocketJs'.toJS, ns);
}

/// Connects to OBS and resolves to a `JsObsWebSocket` handle.
///
/// JS signature:
///   `ObsWebSocketJs.connect(url, password?, timeoutSeconds?, logLevel?,
///   autoReconnect?, maxRetries?, baseDelayMs?, maxDelayMs?)`
/// Returns: `Promise<JsObsWebSocket>`.
///
/// Note: We bypass `ObsWebSocket.connect()` because its conditional import
/// (`dart.library.html`) no longer resolves in Dart 3.x dart2js.
/// Instead, we use `WebSocketChannel.connect()` directly (which uses the
/// browser's native WebSocket via `package:web` under the hood in dart2js)
/// and then construct `ObsWebSocket` with the resulting channel. Reconnection
/// itself runs inside the Dart client via `enableAutoReconnect()`.
JSPromise<JSObject> _connect(
  JSString url,
  JSString? password,
  JSNumber? timeoutSeconds,
  JSString? logLevel,
  JSBoolean? autoReconnect,
  JSNumber? maxRetries,
  JSNumber? baseDelayMs,
  JSNumber? maxDelayMs,
) {
  final future = () async {
    final logOpts = _parseLogLevel(logLevel?.toDart);
    final pwd = password?.toDart;
    final timeout = Duration(seconds: timeoutSeconds?.toDartInt ?? 120);

    Loggy.initLoggy(
      logPrinter: const PrettyPrinter(showColors: false),
      logOptions: logOpts,
    );

    final connectUrl = _normalizeUrl(url.toDart);

    final webSocketChannel = WebSocketChannel.connect(Uri.parse(connectUrl));

    await webSocketChannel.ready.timeout(timeout);

    final obs = ObsWebSocket(
      webSocketChannel,
      password: (pwd == null || pwd.isEmpty) ? null : pwd,
    );

    await obs.init();

    if (autoReconnect?.toDart ?? false) {
      obs.enableAutoReconnect(
        connectUrl,
        timeout: timeout,
        maxAttempts: maxRetries?.toDartInt ?? ObsWebSocket.maxReconnectAttempts,
        baseDelay: Duration(milliseconds: baseDelayMs?.toDartInt ?? 200),
        maxDelay: Duration(milliseconds: maxDelayMs?.toDartInt ?? 5000),
      );
    }

    return _wrap(obs);
  }();

  return future.toJS;
}

LogOptions _parseLogLevel(String? level) {
  switch (level) {
    case 'all':
      return const LogOptions(LogLevel.all);
    case 'debug':
      return const LogOptions(LogLevel.debug);
    case 'info':
      return const LogOptions(LogLevel.info);
    case 'warning':
      return const LogOptions(LogLevel.warning);
    case 'error':
      return const LogOptions(LogLevel.error);
    default:
      return const LogOptions(LogLevel.error, stackTraceLevel: LogLevel.off);
  }
}

/// Normalizes a WebSocket URL: adds `ws://` if no scheme is present.
String _normalizeUrl(String input) {
  final parsed = Uri.tryParse(input);
  if (parsed == null) {
    throw ArgumentError('Invalid WebSocket URL: $input');
  }
  if (parsed.scheme.isEmpty) {
    return 'ws://$input';
  }
  if (parsed.scheme != 'ws' && parsed.scheme != 'wss') {
    throw ArgumentError(
      'Only ws:// and wss:// schemes are supported, got ${parsed.scheme}://',
    );
  }
  return input;
}

/// Wraps an [ObsWebSocket] in an opaque JS object exposing only the methods
/// the TypeScript layer needs.
JSObject _wrap(ObsWebSocket obs) {
  final handlers = <String, List<JSFunction>>{};
  final fallbackHandlers = <JSFunction>[];

  void dispatch(Event event) {
    final jsEvent = JSObject();
    jsEvent.setProperty('eventType'.toJS, event.eventType.toJS);
    jsEvent.setProperty('eventIntent'.toJS, event.eventIntent.toJS);
    jsEvent.setProperty(
      'eventData'.toJS,
      _dartToJs(event.eventData) ?? JSObject(),
    );

    final list = handlers[event.eventType];
    if (list != null) {
      for (final fn in List<JSFunction>.from(list)) {
        fn.callAsFunction(null, jsEvent);
      }
    }
    for (final fn in List<JSFunction>.from(fallbackHandlers)) {
      fn.callAsFunction(null, jsEvent);
    }
  }

  obs.addFallbackListener(dispatch);

  final stateHandlers = <JSFunction>[];
  obs.onConnectionStateChanged.listen((state) {
    for (final fn in List<JSFunction>.from(stateHandlers)) {
      fn.callAsFunction(null, state.name.toJS);
    }
  });

  final handle = JSObject();

  handle.setProperty(
    'onStateChanged'.toJS,
    ((JSFunction callback) {
      stateHandlers.add(callback);
    }).toJS,
  );

  handle.setProperty(
    'offStateChanged'.toJS,
    ((JSFunction? callback) {
      if (callback == null) {
        stateHandlers.clear();
      } else {
        stateHandlers.removeWhere((fn) => identical(fn, callback));
      }
    }).toJS,
  );

  handle.setProperty(
    'send'.toJS,
    ((JSString command, JSAny? args) {
      final mapArgs = args == null ? null : _jsToDartMap(args);
      final future = () async {
        final response = await obs.send(command.toDart, mapArgs);
        if (response == null) return null;
        final out = JSObject();
        out.setProperty('requestType'.toJS, response.requestType.toJS);
        out.setProperty('requestId'.toJS, response.requestId.toJS);
        out.setProperty(
          'requestStatus'.toJS,
          _dartToJs(response.requestStatus.toJson()) ?? JSObject(),
        );
        out.setProperty(
          'responseData'.toJS,
          _dartToJs(response.responseData) ?? JSObject(),
        );
        return out;
      }();
      return future.toJS;
    }).toJS,
  );

  handle.setProperty(
    'sendBatch'.toJS,
    ((JSArray<JSObject> requests) {
      final dartRequests = <Request>[];
      for (final item in requests.toDart) {
        final type = (item.getProperty<JSString>('requestType'.toJS)).toDart;
        final data = item.getProperty<JSAny?>('requestData'.toJS);
        final dataMap = (data == null || data.isUndefinedOrNull)
            ? null
            : _jsToDartMap(data);
        dartRequests.add(Request(type, requestData: dataMap));
      }

      final future = () async {
        final batch = await obs.sendBatch(dartRequests);
        final results = <JSObject>[];
        for (final r in batch.results) {
          final out = JSObject();
          out.setProperty('requestType'.toJS, r.requestType.toJS);
          out.setProperty('requestId'.toJS, r.requestId.toJS);
          out.setProperty(
            'requestStatus'.toJS,
            _dartToJs(r.requestStatus.toJson()) ?? JSObject(),
          );
          out.setProperty(
            'responseData'.toJS,
            _dartToJs(r.responseData) ?? JSObject(),
          );
          results.add(out);
        }
        final ret = JSObject();
        ret.setProperty('requestId'.toJS, batch.requestId.toJS);
        ret.setProperty('results'.toJS, results.toJS);
        return ret;
      }();
      return future.toJS;
    }).toJS,
  );

  handle.setProperty(
    'subscribe'.toJS,
    ((JSNumber subscriptionMask) {
      final future = () async {
        await obs.subscribe(subscriptionMask.toDartInt);
      }();
      return future.toJS;
    }).toJS,
  );

  handle.setProperty(
    'on'.toJS,
    ((JSString eventType, JSFunction callback) {
      handlers.putIfAbsent(eventType.toDart, () => []).add(callback);
    }).toJS,
  );

  handle.setProperty(
    'off'.toJS,
    ((JSString eventType, JSFunction? callback) {
      final list = handlers[eventType.toDart];
      if (list == null) return;
      if (callback == null) {
        list.clear();
      } else {
        list.removeWhere((fn) => identical(fn, callback));
      }
    }).toJS,
  );

  handle.setProperty(
    'onAny'.toJS,
    ((JSFunction callback) {
      fallbackHandlers.add(callback);
    }).toJS,
  );

  handle.setProperty(
    'offAny'.toJS,
    ((JSFunction? callback) {
      if (callback == null) {
        fallbackHandlers.clear();
      } else {
        fallbackHandlers.removeWhere((fn) => identical(fn, callback));
      }
    }).toJS,
  );

  handle.setProperty(
    'close'.toJS,
    (() {
      final future = () async {
        await obs.close();
      }();
      return future.toJS;
    }).toJS,
  );

  handle.setProperty(
    'negotiatedRpcVersion'.toJS,
    obs.negotiatedRpcVersion.toJS,
  );

  return handle;
}

// -------------------------------------------------------------------------
// JSON <-> JS value conversion (round-trip via JSON for fidelity)
// -------------------------------------------------------------------------

JSObject get _json => _globalThis.getProperty<JSObject>('JSON'.toJS);

/// Converts a plain Dart value (from `dart:convert` JSON) to a JS value.
JSAny? _dartToJs(Object? value) {
  if (value == null) return null;
  final encoded = jsonEncode(value);
  return _json.callMethod<JSAny?>('parse'.toJS, encoded.toJS);
}

/// Converts a JS value into a Dart `Map<String, dynamic>`.
Map<String, dynamic> _jsToDartMap(JSAny value) {
  final stringified = _json.callMethod<JSString>('stringify'.toJS, value);
  final decoded = jsonDecode(stringified.toDart);
  if (decoded is Map<String, dynamic>) return decoded;
  throw ArgumentError('Expected object, got ${decoded.runtimeType}');
}
