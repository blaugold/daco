import 'package:analyzer/dart/analysis/context_root.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

import 'analysis_session.dart';

/// The context under which files in a [contextRoot] are analyzed.
abstract class DacoAnalysisContext {
  /// The [ContextRoot] containing the analyzed files.
  ContextRoot get contextRoot;

  /// The parsed contents of the pubspec.yaml file in the [ContextRoot], if the
  /// file exists.
  Pubspec? get pubspec;

  /// The [DacoAnalysisSession] that provides analysis results for files in
  /// the [contextRoot].
  DacoAnalysisSession get session;
}
