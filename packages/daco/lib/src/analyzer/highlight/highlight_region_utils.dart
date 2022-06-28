import 'package:analyzer/source/line_info.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';

/// Splits multiline [HighlightRegion]s into multiple regions.
///
/// Multiline regions will be split at the end of the line and line endings
/// and indenting will be included in the tokens.
Iterable<HighlightRegion> splitMultilineRegion(
  HighlightRegion region,
  LineInfo lineInfo,
) sync* {
  final start = lineInfo.getLocation(region.offset);
  final end = lineInfo.getLocation(region.offset + region.length);

  // Create a region for each line in the original region.
  for (var lineNumber = start.lineNumber;
      lineNumber <= end.lineNumber;
      lineNumber++) {
    final isFirstLine = lineNumber == start.lineNumber;
    final isLastLine = lineNumber == end.lineNumber;
    final lineOffset = lineInfo.getOffsetOfLine(lineNumber - 1);

    final startOffset = isFirstLine ? start.columnNumber - 1 : 0;
    final endOffset = isLastLine
        ? end.columnNumber - 1
        : lineInfo.getOffsetOfLine(lineNumber) - lineOffset;
    final length = endOffset - startOffset;

    yield HighlightRegion(
      region.type,
      lineOffset + startOffset,
      length,
    );
  }
}
