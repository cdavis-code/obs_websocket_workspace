import 'package:web_socket_channel/web_socket_channel.dart';

import 'connect_api.dart'
    if (dart.library.io) 'connect_io.dart'
    if (dart.library.js_interop) 'connect_html.dart';

abstract class Connect {
  Future<WebSocketChannel> connect({
    required String connectUrl,
    required Duration timeout,
  });

  factory Connect() => getConnect();
}
