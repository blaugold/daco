import 'package:analyzer/dart/analysis/analysis_options.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/error_processor.dart';
import 'package:analyzer/source/line_info.dart';
// ignore: implementation_imports
import 'package:analyzer/src/diagnostic/diagnostic_message.dart';

/// Applies analyzer error processors from [analysisOptions] to [diagnostics].
///
/// Diagnostics with a `null` processor severity are filtered out. Diagnostics
/// with a remapped severity keep all other metadata unchanged.
Iterable<Diagnostic> applyErrorProcessors(
  Iterable<Diagnostic> diagnostics,
  AnalysisOptions analysisOptions,
) sync* {
  for (final diagnostic in diagnostics) {
    final processor = ErrorProcessor.getProcessor(analysisOptions, diagnostic);
    if (processor case ErrorProcessor(severity: final severity?)) {
      yield _withSeverity(diagnostic, severity);
    } else if (processor == null) {
      yield diagnostic;
    }
  }
}

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

Diagnostic _withSeverity(Diagnostic diagnostic, DiagnosticSeverity severity) =>
    Diagnostic.forValues(
      source: diagnostic.source,
      offset: diagnostic.offset,
      length: diagnostic.length,
      diagnosticCode: _SeverityOverriddenDiagnosticCode(
        diagnostic.diagnosticCode,
        severity,
      ),
      message: diagnostic.message,
      correctionMessage: diagnostic.correctionMessage,
      contextMessages: diagnostic.contextMessages,
    );

final class _SeverityOverriddenDiagnosticCode extends DiagnosticCode {
  _SeverityOverriddenDiagnosticCode(this._base, this._severity)
    : super(
        correctionMessage: _base.correctionMessage,
        hasPublishedDocs: _base.hasPublishedDocs,
        isUnresolvedIdentifier: _base.isUnresolvedIdentifier,
        name: _base.lowerCaseName,
        problemMessage: _base.problemMessage,
        uniqueName: _base.lowerCaseUniqueName,
      );

  final DiagnosticCode _base;
  final DiagnosticSeverity _severity;

  @override
  DiagnosticSeverity get severity => _severity;

  @override
  DiagnosticType get type => _base.type;
}
