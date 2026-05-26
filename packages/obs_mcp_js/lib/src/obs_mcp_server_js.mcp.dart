/// JS-adapted MCP server with tool registration and dispatch.
///
/// This is a port of `packages/obs_mcp/lib/src/obs_mcp_server.mcp.dart` that
/// removes dart:io dependencies. Code execution uses `eval` in the current
/// Node.js process context (NOT sandboxed).
///
/// All tool registrations and dispatch logic are preserved from the original.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:dart_mcp/server.dart';
import 'package:obs_websocket/obs_websocket.dart';
import 'package:stream_channel/stream_channel.dart';

import 'node_interop.dart';
import 'obs_mcp_server_js.dart' as obs_mcp_server;

@JS('globalThis')
external JSObject get _jsGlobalThis;

/// Helper to create a JS function from a string body.
JSFunction _newJsFunction(String body) {
  final code = 'new Function(${jsonEncode(body)})';
  return _jsEval(code.toJS) as JSFunction;
}

@JS('eval')
external JSAny _jsEval(JSString code);

base class MCPServerWithToolsJs extends MCPServer with ToolsSupport {
  static bool get _logErrors => getEnvVar('OBS_MCP_DEBUG') == '1';

  MCPServerWithToolsJs(StreamChannel<String> channel)
    : super.fromStreamChannel(
        channel,
        implementation: Implementation(
          name: 'obs-mcp-server',
          version: '5.7.1',
        ),
        instructions:
            'OBS Studio MCP server — control OBS via obs-websocket v5.x. '
            'Use the search tool to discover available tools, then call them directly '
            'or use the execute tool to run JavaScript code with access to all tools.',
      ) {
    registerTool(
      Tool(
        name: 'search',
        description:
            'Search for available tools by name or description. Returns matching tools with their parameter information. Use this to discover available tools before calling execute.',
        inputSchema: Schema.object(
          properties: {
            'query': Schema.string(
              description:
                  'Search terms. Space-separated terms are AND-matched against tool names and descriptions (case-insensitive).',
            ),
            'detail_level': UntitledSingleSelectEnumSchema(
              description:
                  'Level of detail: "brief" (name + description), "detailed" (+ parameter names/types/required), "full" (+ complete parameter schemas).',
              values: ['brief', 'detailed', 'full'],
            ),
          },
          required: ['query'],
        ),
      ),
      _search,
    );
    registerTool(
      Tool(
        name: 'execute',
        description:
            'Execute JavaScript code with access to MCP tool functions. Use call_tool(name, params) to call any tool by name, or use external_<toolName>(args) convenience wrappers. Use the search tool first to discover available tools and their signatures. All calls are async - use await for sequential calls and Promise.all() for parallel calls. Return a value to include it in the result.',
        inputSchema: Schema.object(
          properties: {
            'code': Schema.string(description: 'JavaScript code to execute.'),
          },
          required: ['code'],
        ),
      ),
      _execute,
    );
    if (getEnvVar('OBS_MCP_DEBUG') == '1') {
      logError(
        '[obs-mcp-js] MCPServerWithToolsJs constructor: tools registered',
      );
    }
  }

  CallToolResult _handleError(String name, Object e, StackTrace st) {
    if (_logErrors) {
      logError('[easy_api] $name: $e');
      logError('$st');
    }
    return CallToolResult(
      content: [
        TextContent(text: 'An error occurred while processing the request.'),
      ],
      isError: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Search tool
  // ---------------------------------------------------------------------------

  static List<Map<String, dynamic>> get _codeModeToolSpecs =>
      obs_mcp_server.ObsMcpServer.toolDefs.map((d) => d.toSpec()).toList();

  FutureOr<CallToolResult> _search(CallToolRequest request) async {
    try {
      final query = (request.arguments?['query'] as String?) ?? '';
      final detailLevel =
          (request.arguments?['detail_level'] as String?) ?? 'brief';
      final terms = query
          .toLowerCase()
          .split(' ')
          .where((t) => t.isNotEmpty)
          .toList();

      if (terms.isEmpty) {
        final results = _codeModeToolSpecs
            .map((tool) => _formatSearchResult(tool, detailLevel))
            .toList();
        return CallToolResult(
          content: [TextContent(text: jsonEncode(results))],
        );
      }

      final andMatches = _codeModeToolSpecs.where((tool) {
        final name = (tool['name'] as String).toLowerCase();
        final desc = (tool['description'] as String).toLowerCase();
        return terms.every(
          (term) => name.contains(term) || desc.contains(term),
        );
      }).toList();

      List<Map<String, dynamic>> matches;
      if (andMatches.isNotEmpty) {
        matches = andMatches;
      } else {
        final scored = _codeModeToolSpecs
            .map((tool) {
              final name = (tool['name'] as String).toLowerCase();
              final desc = (tool['description'] as String).toLowerCase();
              int score = 0;
              for (final term in terms) {
                if (name.contains(term) || desc.contains(term)) score++;
              }
              return MapEntry(tool, score);
            })
            .where((e) => e.value > 0)
            .toList();
        scored.sort((a, b) => b.value.compareTo(a.value));
        matches = scored.map((e) => e.key).toList();
      }

      final results = matches
          .map((tool) => _formatSearchResult(tool, detailLevel))
          .toList();
      return CallToolResult(content: [TextContent(text: jsonEncode(results))]);
    } catch (e, st) {
      return _handleError('_search', e, st);
    }
  }

  Map<String, dynamic> _formatSearchResult(
    Map<String, dynamic> tool,
    String detailLevel,
  ) {
    final name = tool['name'] as String;
    final desc = tool['description'] as String;
    final params = tool['parameters'] as List;
    if (detailLevel == 'brief') {
      return {'name': name, 'description': desc};
    }
    final paramInfo = params
        .map(
          (p) => {
            'name': p['name'],
            'type': p['type'],
            'required': p['required'],
          },
        )
        .toList();
    return {'name': name, 'description': desc, 'parameters': paramInfo};
  }

  // ---------------------------------------------------------------------------
  // Execute tool (code execution via eval in Node.js process)
  // ---------------------------------------------------------------------------

  FutureOr<CallToolResult> _execute(CallToolRequest request) async {
    try {
      final code = request.arguments!['code'] as String;
      final result = await _runCode(code, 30);
      return CallToolResult(content: [TextContent(text: result ?? 'null')]);
    } catch (e, st) {
      return _handleError('_execute', e, st);
    }
  }

  /// Runs JavaScript code in the current Node.js process context.
  /// Code has full access to the Node.js environment.
  /// This is NOT sandboxed execution — it uses `eval` via `new Function`.
  Future<String?> _runCode(String userCode, int timeoutSeconds) async {
    // Build the wrapper that provides call_tool() and external_* functions
    final wrapper = _buildJsWrapper(userCode);

    // Use eval via JS interop to run the code in the current context
    // The wrapper code communicates results back via a global callback
    final completer = Completer<String?>();

    // Set up a global callback for receiving the result
    final callbackName =
        '__mcp_sandbox_result_${DateTime.now().millisecondsSinceEpoch}';

    // Store a Dart callback that the JS code will invoke
    final doneCallback = ((JSString type, JSString data) {
      final typeStr = type.toDart;
      final dataStr = data.toDart;
      if (typeStr == 'done') {
        if (!completer.isCompleted)
          completer.complete(dataStr.isEmpty ? null : dataStr);
      } else if (typeStr == 'error') {
        if (!completer.isCompleted)
          completer.completeError(StateError('Code execution error: $dataStr'));
      }
    }).toJS;

    // Set the callback on globalThis
    final globalThis = _jsGlobalThis;
    globalThis.setProperty(callbackName.toJS, doneCallback);

    // Create the full script that wraps user code with IPC
    final fullScript =
        '''
(async () => {
  const __callback = globalThis['$callbackName'];
  let __callId = 0;

  async function call_tool(name, params) {
    // Direct dispatch through the Dart server
    const callId = String(++__callId);
    return new Promise((resolve, reject) => {
      globalThis['__mcp_pending_' + callId] = { resolve, reject };
      globalThis['__mcp_dispatch_tool']?.(name, JSON.stringify(params || {}), callId);
    });
  }

  // User code
  try {
    const __result = await (async () => {
      ${_wrapUserCode(userCode)}
    })();
    __callback('done', __result == null ? '' : (typeof __result === 'string' ? __result : JSON.stringify(__result)));
  } catch (e) {
    __callback('error', e.message || String(e));
  }
})();
''';

    // Set up tool dispatch callback
    final dispatchCallback =
        ((JSString toolName, JSString argsJson, JSString callId) {
          final name = toolName.toDart;
          final args = jsonDecode(argsJson.toDart) as Map<String, dynamic>;
          final id = callId.toDart;

          _dispatchCodeModeToolCall(name, args)
              .then((result) {
                final resultJson = result == null
                    ? 'null'
                    : (result is String ? result : jsonEncode(result));
                // Resolve the pending promise in JS
                final escapedResult = jsonEncode(resultJson);
                _evalJs(
                  "globalThis['__mcp_pending_$id']?.resolve($escapedResult)",
                );
              })
              .catchError((e) {
                final escaped = jsonEncode(e.toString());
                _evalJs(
                  "globalThis['__mcp_pending_$id']?.reject(new Error($escaped))",
                );
              });
        }).toJS;

    globalThis.setProperty('__mcp_dispatch_tool'.toJS, dispatchCallback);

    // Execute the script
    _evalJs(fullScript);

    // Wait for result with timeout
    try {
      final result = await completer.future.timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () => throw StateError(
          'Code execution timed out after $timeoutSeconds seconds',
        ),
      );
      return result;
    } finally {
      // Cleanup
      globalThis.setProperty(callbackName.toJS, null);
      globalThis.setProperty('__mcp_dispatch_tool'.toJS, null);
    }
  }

  String _wrapUserCode(String userCode) {
    final trimmed = userCode.trim();
    final isExpressionLike =
        trimmed.startsWith('(') || trimmed.startsWith('await ');
    final alreadyHasReturn = trimmed.startsWith('return ');
    if (isExpressionLike && !alreadyHasReturn) return 'return $userCode';
    return userCode;
  }

  String _buildJsWrapper(String userCode) =>
      userCode; // Unused in JS-native approach

  // ---------------------------------------------------------------------------
  // Tool dispatch (for code mode)
  // ---------------------------------------------------------------------------

  dynamic _dispatchCodeModeToolCall(
    String toolName,
    Map<String, dynamic> args,
  ) async {
    // search is handled internally (not in the tool registry)
    if (toolName == 'search') {
      final request = CallToolRequest(name: toolName, arguments: args);
      final result = await _search(request);
      final textContent = result.content.whereType<TextContent>().firstOrNull;
      if (textContent != null) {
        final text = textContent.text;
        try {
          return jsonDecode(text);
        } catch (_) {
          return text;
        }
      }
      return result.content.map((c) => c.toString()).join('\n');
    }

    // All other tools dispatch via the registry
    final toolDef = obs_mcp_server.ObsMcpServer.toolDefs.firstWhere(
      (d) => d.name == toolName,
    );
    // Call the dispatch function with null for server (all methods are static)
    return toolDef.dispatch(args, obs_mcp_server.ObsMcpServer());
  }

  // ---------------------------------------------------------------------------
  // JS evaluation helpers
  // ---------------------------------------------------------------------------

  static void _evalJs(String code) {
    final fn = _createFunction(code);
    fn.callAsFunction(null);
  }

  static JSFunction _createFunction(String body) {
    // new Function(body) — creates an anonymous function from code
    return _newJsFunction(body);
  }
}
