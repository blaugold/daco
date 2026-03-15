import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/source/line_info.dart';
// ignore: implementation_imports
import 'package:analyzer/src/diagnostic/diagnostic_message.dart';

/// Truncates multiline [DiagnosticMessage]s of the [error] to one line.
Diagnostic truncateMultilineError(Diagnostic error, LineInfo lineInfo) {
  final problemMessage = _truncateMultilineDiagnosticMessage(
    error.problemMessage,
    lineInfo,
  );
  return Diagnostic.forValues(
    source: error.source,
    offset: problemMessage.offset,
    length: problemMessage.length,
    diagnosticCode: error.diagnosticCode,
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
