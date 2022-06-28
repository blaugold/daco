import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

// We need to import `analyzer_plugin/plugin/plugin.dart` to prevent the
// analysis server from crashing.
// ignore: unused_import
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:web_socket_channel/io.dart';

/// An analyzer plugin that proxies to another plugin over websocket.
///
/// This allows the other plugin to run in a process separate from the analysis
/// server, making debugging much easier.
class ProxyPlugin {
  /// Creates an analyzer plugin that proxies to another plugin over websocket.
  ProxyPlugin({this.port = 9999});

  /// The port under which the proxied plugin is listening on `localhost`.
  final int port;

  late final SendPort _serverSendPort;
  late final ReceivePort _pluginReceivePort;
  late final IOWebSocketChannel _remotePluginChannel;

  /// Starts to proxy between the analysis server and the plugin.
  ///
  /// [serverSendPort] must be the [SendPort] passed to the plugin isolate by
  /// the analysis server.
  Future<void> start(SendPort serverSendPort) async {
    _serverSendPort = serverSendPort;
    _pluginReceivePort = ReceivePort();

    _serverSendPort.send(_pluginReceivePort.sendPort);

    _remotePluginChannel = IOWebSocketChannel.connect('ws://localhost:$port');

    _pluginReceivePort.listen(cancelOnError: false, (message) {
      final request = json.encode(message);
      _remotePluginChannel.sink.add(request);
    });

    _remotePluginChannel.stream.listen(cancelOnError: false, (message) {
      final response = json.decode(message as String) as Map<String, Object?>;
      if (response.containsKey('event')) {
        response['params'] = {
          ...(response['params']! as Map).cast<String, Object>()
        };
      }
      _serverSendPort.send(response);
    });
  }
}
