import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/source/line_info.dart';

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

  return _TruncatedDiagnosticMessage(message, truncatedLength);
}

/// A [DiagnosticMessage] that wraps another message but reports a shorter
/// [length].
///
/// The analyzer's own implementation lives in a private library whose location
/// changes between analyzer versions, so daco provides its own.
class _TruncatedDiagnosticMessage implements DiagnosticMessage {
  _TruncatedDiagnosticMessage(this._message, this.length);

  final DiagnosticMessage _message;

  @override
  final int length;

  @override
  String get filePath => _message.filePath;

  @override
  int get offset => _message.offset;

  @override
  String? get url => _message.url;

  @override
  String messageText({required bool includeUrl}) =>
      _message.messageText(includeUrl: includeUrl);
}
