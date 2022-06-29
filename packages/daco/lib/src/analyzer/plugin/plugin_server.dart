// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer_plugin/channel/channel.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol.dart';

/// A websocket server that hosts [ServerPlugin]s and makes them available over
/// the network.
class PluginServer {
  /// Creates a new [PluginServer].
  PluginServer({
    required this.pluginFactory,
    Object? address,
    this.port = 9999,
    this.logMessages = false,
  }) : address = address ?? InternetAddress.loopbackIPv4;

  /// Factory that creates a new [ServerPlugin] for each connected client.
  final ServerPlugin Function() pluginFactory;

  /// The address to listen at for connection.
  final Object address;

  /// The port to listen at for connection.
  final int port;

  /// Whether all messages between servers and plugins are logged.
  final bool logMessages;

  HttpServer? _server;
  var _clientId = 0;

  /// Starts this server.
  Future<void> start() async {
    assert(_server == null);
    _server = await HttpServer.bind(address, port);
    print('listening on $address at port $port');
    _server!.transform(WebSocketTransformer()).listen(_handleClientAdded);
  }

  /// Stops this server.
  Future<void> stop() async {
    assert(_server != null);
    await _server!.close(force: true);
  }

  void _handleClientAdded(WebSocket client) {
    final id = _clientId++;

    print('client #$id connected');

    final channel = _WebSocketPluginChannel(
      id: id,
      client: client,
      logMessages: logMessages,
    );
    pluginFactory().start(channel);

    client.done.then((_) {
      print('client #$id disconnected');
    });
  }
}

class _WebSocketPluginChannel implements PluginCommunicationChannel {
  _WebSocketPluginChannel({
    required this.id,
    required this.client,
    this.logMessages = false,
  });

  final int id;
  final WebSocket client;
  final bool logMessages;
  bool isClosed = false;

  @override
  void close() {
    isClosed = true;
    client.close();
  }

  @override
  void listen(
    void Function(Request request) onRequest, {
    Function? onError,
    void Function()? onDone,
  }) {
    client.listen((data) {
      if (logMessages) {
        print('#$id I: $data');
      }
      final request = Request.fromJson(
        json.decode(data as String) as Map<String, dynamic>,
      );
      onRequest(request);
    });

    client.done.then((_) => onDone?.call());
  }

  @override
  void sendNotification(Notification notification) {
    if (isClosed) {
      // Ignore notifications after the channel has been closed.
      return;
    }

    if (logMessages) {
      print('#$id N: ${notification.toJson()}');
    }

    client.add(json.encode(notification.toJson()));
  }

  @override
  void sendResponse(Response response) {
    if (isClosed) {
      // Ignore responses after the channel has been closed.
      return;
    }

    if (logMessages) {
      print('#$id O: ${response.toJson()}');
    }

    client.add(json.encode(response.toJson()));
  }
}
