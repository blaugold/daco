import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/line_info.dart';
// ignore: implementation_imports
import 'package:analyzer/src/diagnostic/diagnostic.dart';

/// Truncates multiline [DiagnosticMessage]s of the [error] to one line.
AnalysisError truncateMultilineError(AnalysisError error, LineInfo lineInfo) {
  final problemMessage =
      _truncateMultilineDiagnosticMessage(error.problemMessage, lineInfo);
  return AnalysisError.forValues(
    source: error.source,
    offset: problemMessage.offset,
    length: problemMessage.length,
    errorCode: error.errorCode,
    message: problemMessage.messageText(includeUrl: true),
    correctionMessage: error.correctionMessage,
    contextMessages: error.contextMessages
        .map(
          (message) => _truncateMultilineDiagnosticMessage(message, lineInfo),
        )
        .toList(),
  );
}

DiagnosticMessage _truncateMultilineDiagnosticMessage(
  DiagnosticMessage message,
  LineInfo lineInfo,
) {
  final start = lineInfo.getLocation(message.offset);
  final end = lineInfo.getLocation(message.offset + message.length);

  if (start.lineNumber == end.lineNumber) {
    return message;
  }

  final truncatedLength =
      lineInfo.getOffsetOfLineAfter(message.offset) - message.offset;

  return DiagnosticMessageImpl(
    filePath: message.filePath,
    message: message.messageText(includeUrl: false),
    url: message.url,
    offset: message.offset,
    length: truncatedLength,
  );
}
