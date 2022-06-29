import 'dart:isolate';

// ignore: implementation_imports
import 'package:daco/src/analyzer/plugin/daco_plugin.dart';
import 'package:daco_analyzer_plugin/src/proxy_plugin.dart';

const useRemotePlugin = false;

void main(List<String> args, SendPort sendPort) {
  if (useRemotePlugin) {
    ProxyPlugin().start(sendPort);
  } else {
    DacoPlugin.runLocally(sendPort);
  }
}
