import 'package:analyzer/dart/analysis/context_root.dart';
import 'package:analyzer/error/error.dart';

import 'result.dart';

/// A consistent view on the analysis of files in a [ContextRoot].
abstract class DacoAnalysisSession {
  Future<List<AnalysisError>> getErrors(String file);

  /// Returns the result of parsing the given [file].
  ParsedBlockResult getParsedBlock(String file);
}
