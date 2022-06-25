import 'package:analyzer/error/error.dart';

import 'analysis_session.dart';
import 'block.dart';

/// An analysis result for a file including errors discovered in the file.
abstract class AnalysisResultWithErrors {
  /// The session which provided this result.
  DacoAnalysisSession get session;

  /// Errors that where discovered in the analyzed file.
  List<AnalysisError> get errors;
}

/// An analysis result containing the parsed root [Block] for a file.
///
/// [errors] contains only errors that were discovered during scanning and
/// parsing.
abstract class ParsedBlockResult extends AnalysisResultWithErrors {
  /// The root [Block] for the parsed file.
  Block get block;
}

/// The result of parsing a [String] as a root [Block], outside of a
/// [DacoAnalysisSession].
abstract class ParseStringResult {
  /// The root [Block] for the parsed [String].
  Block get block;

  /// Errors that where discovered during scanning and parsing.
  List<AnalysisError> get errors;
}
