import 'dart:isolate';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:analyzer_plugin/starter.dart';
import 'package:analyzer_plugin/utilities/analyzer_converter.dart';
import 'package:synchronized/synchronized.dart';

import '../../file_utils.dart';
import '../analyzer.dart';
import 'plugin_server.dart';

/// Analyzer plugin that integrations daco with the analysis server.
class DacoPlugin extends ServerPlugin {
  /// Creates a new [DacoPlugin].
  DacoPlugin({ResourceProvider? provider})
      : super(resourceProvider: provider ?? PhysicalResourceProvider.INSTANCE);

  /// Runs an instance of [DacoPlugin] within the analysis server process, in an
  /// isolate spawned by the analysis server.
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

  AnalysisContextCollection? _contextCollection;

  final _analyzers = <AnalysisContext, DacoAnalyzer>{};

  final _converter = AnalyzerConverter();

  final _lock = Lock();

  DacoAnalyzer _analyzerForContext(AnalysisContext analysisContext) =>
      _analyzers.putIfAbsent(
        analysisContext,
        () => DacoAnalyzer(analysisContext: analysisContext),
      );

  @override
  Future<void> afterNewContextCollection({
    required AnalysisContextCollection contextCollection,
  }) async {
    assert(_contextCollection == null);
    _contextCollection = contextCollection;
    return super
        .afterNewContextCollection(contextCollection: contextCollection);
  }

  @override
  Future<void> beforeContextCollectionDispose({
    required AnalysisContextCollection contextCollection,
  }) async {
    assert(_contextCollection == contextCollection);
    _contextCollection = null;
  }

  @override
  Future<void> analyzeFile({
    required AnalysisContext analysisContext,
    required String path,
  }) async {
    if (isDartFile(path) && analysisContext.contextRoot.isAnalyzed(path)) {
      await _sendAnalysisErrorsForFile(analysisContext, path);
    }
  }

  Future<void> _sendAnalysisErrorsForFile(
    AnalysisContext analysisContext,
    String path,
  ) async {
    final analyzer = _analyzerForContext(analysisContext);
    final errors = await _lock.synchronized(() => analyzer.getErrors(path));

    channel.sendNotification(
      AnalysisErrorsParams(
        path,
        errors.map(_converter.convertAnalysisError).toList(),
      ).toNotification(),
    );
  }
}
