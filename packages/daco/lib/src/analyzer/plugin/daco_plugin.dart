import 'dart:isolate';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/starter.dart';

import 'plugin_server.dart';

/// Analyzer plugin that integrations daco with the analysis server.
class DacoPlugin extends ServerPlugin {
  /// Creates a new [DacoPlugin].
  DacoPlugin({ResourceProvider? provider})
      : super(resourceProvider: provider ?? PhysicalResourceProvider.INSTANCE);

  /// Runs an instance of [DacoPlugin] within the analysis server process, in
  /// an isolate spawned by the analysis server.
  static void runLocally(SendPort sendPort) {
    ServerPluginStarter(DacoPlugin()).start(sendPort);
  }

  /// Starts a [PluginServer] that serves instances of [DacoPlugin] to connected
  /// clients.
  static void runRemotely() {
    PluginServer(
      pluginFactory: DacoPlugin.new,
      logMessages: true,
    ).start();
  }

  @override
  String get name => 'daco';

  @override
  String? get contactInfo =>
      'Create an issue at https://github.com/blaugold/daco/issues';

  @override
  String get version => '1.0.0-alpha.0';

  @override
  List<String> get fileGlobsToAnalyze => ['*.dart'];

  @override
  Future<void> analyzeFile({
    required AnalysisContext analysisContext,
    required String path,
  }) async {}
}
