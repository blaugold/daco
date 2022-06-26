import 'package:analyzer/dart/analysis/context_root.dart';
import 'package:analyzer/error/error.dart';

import 'result.dart';

/// A consistent view on the analysis of files in a [ContextRoot].
abstract class DacoAnalysisSession {
  /// Returns all errors that were discovered in the file at the given [path].
  Future<List<AnalysisError>> getErrors(String path);

  /// Returns the result of parsing the file at the given [path].
  ParsedBlockResult getParsedBlock(String path);
}
