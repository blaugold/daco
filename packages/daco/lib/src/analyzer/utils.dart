// ignore: implementation_imports
import 'package:analyzer/src/string_source.dart';

import 'analysis_session.dart';
import 'block.dart';
import 'parser.dart';
import 'result.dart';
import 'result_impl.dart';

/// Parses a [String] as root [Block] outside of a [DacoAnalysisSession].
///
/// A [uri] must be provided because it is used to determine the content type of
/// [text].
ParseStringResult parseString({
  required String text,
  required String uri,
  bool withErrorsInRootBlock = false,
}) {
  final parser = BlockParser();
  final source = StringSource(text, uri);

  parser.parse(source, withErrorsInRootBlock: withErrorsInRootBlock);

  return ParseStringResultImpl(block: parser.block!, errors: parser.errors!);
}
