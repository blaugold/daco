import 'package:analyzer/dart/analysis/context_root.dart';

import '../analyzer.dart';

/// The context under which files in a [contextRoot] are analyzed.
abstract class DacoAnalysisContext {
  /// The [ContextRoot] containing the analyzed files.
  ContextRoot get contextRoot;

  /// The [DacoAnalysisSession] that provides analysis results for files in
  /// the [contextRoot].
  DacoAnalysisSession get session;
}
