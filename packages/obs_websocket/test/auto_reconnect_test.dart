import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:loggy/loggy.dart';
import 'package:obs_websocket/obs_websocket.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

/// Minimal obs-websocket handshake stand-in: sends `Hello`, answers `Identify`
/// with `Identified`, and can drop the client socket to simulate OBS closing.
class FakeObsServer {
  HttpServer? _server;
  WebSocket? _client;
  int connections = 0;

  Future<int> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.transform(WebSocketTransformer()).listen((socket) {
      connections++;
      _client = socket;
      socket.add(
        jsonEncode({
          'op': 0,
          'd': {'obsWebSocketVersion': '5.0.0', 'rpcVersion': 1},
        }),
      );
      socket.listen((message) {
        final opcode = jsonDecode(message) as Map<String, dynamic>;
        if (opcode['op'] == 1) {
          socket.add(
            jsonEncode({
              'op': 2,
              'd': {'negotiatedRpcVersion': 1},
            }),
          );
        }
      });
    });

    return _server!.port;
  }

  void dropClient() => _client?.close();

  Future<void> stop() async => _server?.close(force: true);
}

Future<void> waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

void main() {
  late FakeObsServer server;
  late String url;

  setUp(() async {
    server = FakeObsServer();
    url = 'ws://127.0.0.1:${await server.start()}';
  });

  tearDown(() async => server.stop());

  test(
    'init marks connected, enableAutoReconnect recovers a dropped socket',
    () async {
      final obs = ObsWebSocket(
        IOWebSocketChannel(await WebSocket.connect(url)),
      );
      await obs.init();

      expect(obs.connectionState, ObsConnectionState.connected);

      obs.enableAutoReconnect(url, baseDelay: const Duration(milliseconds: 20));

      final states = <ObsConnectionState>[];
      obs.onConnectionStateChanged.listen(states.add);

      server.dropClient();
      await waitFor(() => server.connections >= 2);
      await waitFor(() => obs.connectionState == ObsConnectionState.connected);

      expect(states, contains(ObsConnectionState.reconnecting));
      expect(states, contains(ObsConnectionState.connected));
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test('reconnect gives up after the configured max attempts', () async {
    final obs = await ObsWebSocket.connect(
      url,
      autoReconnect: true,
      logOptions: const LogOptions(LogLevel.off),
    );

    expect(obs.connectionState, ObsConnectionState.connected);

    // OBS is gone for good: retries must stop at the configured maximum.
    obs.enableAutoReconnect(
      url,
      maxAttempts: 2,
      baseDelay: const Duration(milliseconds: 10),
      maxDelay: const Duration(milliseconds: 20),
    );
    await server.stop();

    server.dropClient();
    await waitFor(() => obs.connectionState == ObsConnectionState.failed);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('user-initiated close does not reconnect', () async {
    final obs = ObsWebSocket(IOWebSocketChannel(await WebSocket.connect(url)));
    await obs.init();
    obs.enableAutoReconnect(url, baseDelay: const Duration(milliseconds: 20));

    await obs.close();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(server.connections, 1);
    expect(obs.connectionState, ObsConnectionState.disconnected);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
