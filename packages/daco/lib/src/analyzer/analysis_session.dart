import 'package:analyzer/dart/analysis/context_root.dart';
import 'package:analyzer/error/error.dart';

import 'result.dart';

/// A consistent view on the analysis of files in a [ContextRoot].
abstract class DacoAnalysisSession {
  /// Returns all errors that were discovered in the given [file].
  Future<List<AnalysisError>> getErrors(String file);

  /// Returns the result of parsing the given [file].
  ParsedBlockResult getParsedBlock(String file);
}
