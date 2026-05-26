/// Core JS bindings that wire up Node.js stdin/stdout as an MCP
/// [StreamChannel<String>] and launch the MCP server.
///
/// This file is the main orchestration layer: it reads environment variables,
/// creates the stdio channel with newline-delimited JSON framing (matching
/// `dart_mcp`'s [stdioChannel]), bootstraps the OBS connection, and starts
/// the generated MCP server.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:stream_channel/stream_channel.dart';

import 'node_interop.dart';
import 'obs_mcp_server_js.dart' as obs_mcp_server;

// ---------------------------------------------------------------------------
// Debug logging helpers
// ---------------------------------------------------------------------------

/// Returns true only when OBS_MCP_DEBUG=1 is set in the environment.
bool get _debugEnabled {
  final val = getEnvVar('OBS_MCP_DEBUG');
  return val == '1';
}

/// Emits a debug message to stderr ONLY when OBS_MCP_DEBUG=1.
void _debugLog(String message) {
  if (_debugEnabled) {
    logError('[obs-mcp-js] $message');
  }
}

/// Entry point called from `lib/obs_mcp_js.dart`.
///
/// Sets up the MCP stdio transport over Node.js stdin/stdout,
/// then bootstraps the OBS connection from environment variables
/// in the background so the server can respond to MCP messages
/// immediately.
Future<void> startServer() async {
  _debugLog('startServer() called');

  // Create the MCP stdio channel FIRST so we can respond to initialize
  _createStdioChannel();
  _debugLog('stdio channel created');

  // Create and run the MCP server
  _debugLog('MCPServerWithToolsJs created');

  // Note: SIGINT/SIGTERM are handled in bin/obs-mcp-server.js (the JS entry
  // point) because they must clear the keepAlive timer. No duplicate handling
  // needed here.

  // Bootstrap OBS connection in the background — the server is already
  // able to respond to MCP protocol messages (initialize, tools/list, etc.)
  // while this runs.  Tools that need OBS will report a clear error if the
  // connection hasn't completed yet.
  unawaited(
    obs_mcp_server.ObsMcpServer.bootstrapFromEnv().catchError((Object e) {
      _debugLog('ERROR: OBS bootstrap failed: $e');
    }),
  );

  // Don't await server.done - it blocks the event loop!
  // The server will stay alive as long as stdin is open.
  // When stdin closes, the server will shut down automatically.
  _debugLog('Server started, waiting for stdin to close...');
}

/// Creates a [StreamChannel<String>] that communicates over Node.js
/// stdin/stdout using newline-delimited JSON (matching `dart_mcp`'s
/// [stdioChannel] which uses [LineSplitter] on input and appends `\n` on
/// output).
///
/// Input parsing:
///   Reads raw bytes from stdin, splits on newlines (`\n` or `\r\n`),
///   each non-empty line is a complete JSON message.
///
/// Output framing:
///   Writes each JSON message followed by `\n` to stdout.
StreamChannel<String> _createStdioChannel() {
  final inputController = StreamController<String>();
  final outputController = StreamController<String>();

  // --- Input: parse newline-delimited messages from stdin ---
  _setupStdinReader(inputController);

  // --- Output: write messages as newline-delimited JSON to stdout ---
  outputController.stream.listen((String message) {
    _debugLog('Writing to stdout: ${message.length} chars');
    process.stdout.write('$message\n'.toJS);
  });

  return StreamChannel<String>(inputController.stream, outputController.sink);
}

/// Sets up a listener on Node.js stdin that splits input on newlines
/// and adds each non-empty line as a complete JSON message to [controller].
///
/// This matches the `dart_mcp` package's [LineSplitter]-based transport.
void _setupStdinReader(StreamController<String> controller) {
  // Buffer for accumulating partial lines
  var buffer = '';

  _debugLog('Attaching stdin data listener');

  process.stdin.on(
    'data',
    ((JSAny chunk) {
      // chunk may be a Buffer or a String depending on encoding settings
      String data;
      if (chunk.isA<JSString>()) {
        data = (chunk as JSString).toDart;
      } else {
        // It's a Buffer - call toString('utf8')
        final buf = chunk as JSObject;
        final toStr = buf.getProperty('toString'.toJS) as JSFunction;
        final result = toStr.callAsFunction(buf, 'utf8'.toJS) as JSString;
        data = result.toDart;
      }

      _debugLog('stdin data received: ${data.length} chars');

      buffer += data;

      // Process as many complete lines as possible
      while (true) {
        // Look for a newline (handles both \r\n and \n)
        final nlIndex = buffer.indexOf('\n');
        if (nlIndex == -1) break;

        // Extract the line (strip trailing \r if present)
        var line = buffer.substring(0, nlIndex);
        if (line.endsWith('\r')) {
          line = line.substring(0, line.length - 1);
        }
        buffer = buffer.substring(nlIndex + 1);

        // Skip empty lines
        if (line.isEmpty) continue;

        _debugLog(
          'Complete MCP message received (${line.length} chars): ${line.length > 200 ? line.substring(0, 200) : line}',
        );
        controller.add(line);
      }
    }).toJS,
  );

  process.stdin.on(
    'end',
    (() {
      _debugLog('stdin ended');
      // Flush any remaining buffered content (message without trailing newline)
      if (buffer.isNotEmpty) {
        final line = buffer.endsWith('\r')
            ? buffer.substring(0, buffer.length - 1)
            : buffer;
        if (line.isNotEmpty) {
          _debugLog('Flushing final message (${line.length} chars)');
          controller.add(line);
        }
      }
      controller.close();
    }).toJS,
  );
}
