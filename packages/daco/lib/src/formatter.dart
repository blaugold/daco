// ignore_for_file: parameter_assignments

import 'package:analyzer/error/error.dart';
import 'package:collection/collection.dart';
import 'package:dart_style/dart_style.dart';

import 'prettier.dart';
import 'source.dart';

final _dartDocTagRegExp = RegExp('{@.+}');
final _dartDocTagWithSpacerRegExp = RegExp(r'({@.+})-+$', multiLine: true);

const _noFormatTag = 'no_format';

/// Formatter which formats Dart code, including comments.
class DacoFormatter {
  /// Creates a formatter which formats Dart code, including comments.
  DacoFormatter({
    this.lineLength = 80,
    Iterable<StyleFix>? fixes,
    required this.prettierService,
  }) : fixes = {...?fixes};

  /// The maximum length of a line of code.
  final int lineLength;

  /// The fixes to apply to Dart code.
  final Set<StyleFix> fixes;

  /// The [PrettierService] to use to format markdown.
  final PrettierService prettierService;

  /// Formats the given [source] string containing an entire Dart compilation
  /// unit.
  Future<String> format(String source, {String? path}) async {
    final rootSource = DartSource(text: source, uri: path);
    _checkForDartParseErrors(rootSource);
    return _formatDartSource(rootSource, lineLength: lineLength);
  }

  void _checkForDartParseErrors(DartSource source) {
    final errors = <AnalysisError>[];
    final sources = <DartSource>[source];

    while (sources.isNotEmpty) {
      final source = sources.removeAt(0);

      final syntacticErrors = source
          .analysisErrors()
          .where((error) => error.errorCode.type == ErrorType.SYNTACTIC_ERROR);
      errors.addAll(syntacticErrors);

      final enclosedDartSources = source
          .documentationComments()
          .expand((comment) => comment.dartCodeBlocks());
      sources.addAll(enclosedDartSources);
    }

    if (errors.isNotEmpty) {
      throw FormatterException(errors);
    }
  }

  Future<String> _formatDartSource(
    DartSource source, {
    required int lineLength,
  }) async {
    final formatter = DartFormatter(pageWidth: lineLength, fixes: fixes);
    final formattedText = formatter.format(source.text);
    final formattedSource = DartSource(text: formattedText);
    final formattedComments = <MarkdownSource, String>{};

    await Future.wait(
      formattedSource.documentationComments().map((comment) async {
        formattedComments[comment] = await _formatMarkdownSource(
          comment,
          lineLength: formattedSource.availableLineLength(
            of: comment,
            lineLength: lineLength,
          ),
        );
      }),
    );

    return formattedSource.replaceEnclosedSources(formattedComments);
  }

  Future<String> _formatMarkdownSource(
    MarkdownSource source, {
    required int lineLength,
  }) async {
    final formattedText = await _formatMarkdown(source, lineLength);
    final formattedSource = MarkdownSource(text: formattedText);
    final formattedCodeBlocks = <DartSource, String>{};

    await Future.wait(
      formattedSource.dartCodeBlocks().map((codeBlock) async {
        if (formattedSource
            .codeBlockTags(of: codeBlock)
            .contains(_noFormatTag)) {
          return;
        }

        formattedCodeBlocks[codeBlock] = await _formatDartSource(
          codeBlock,
          lineLength: formattedSource.availableLineLength(
            of: codeBlock,
            lineLength: lineLength,
          ),
        );
      }),
    );

    return formattedSource.replaceEnclosedSources(formattedCodeBlocks);
  }

  Future<String> _formatMarkdown(Source source, int lineLength) async {
    var text = source.text;
    final tagMatches = _dartDocTagRegExp.allMatches(text);
    final tagLines = <int>{};
    for (final match in tagMatches) {
      final startLine = source.lineInfo.getLocation(match.start).lineNumber;
      final endLine = source.lineInfo.getLocation(match.end).lineNumber;
      for (var line = startLine; line <= endLine; line++) {
        // LineInfo returns 1-based line numbers, but we want 0-based.
        tagLines.add(line - 1);
      }
    }

    text = text
        .split('\n')
        .mapIndexed(
          (index, line) =>
              tagLines.contains(index) ? line.padRight(lineLength, '-') : line,
        )
        .join('\n');

    text = await prettierService.format(
      text,
      parser: 'markdown',
      printWidth: lineLength,
      proseWrap: ProseWrap.always,
    );

    return text.replaceAllMapped(
      _dartDocTagWithSpacerRegExp,
      (match) => match.group(1)!,
    );
  }
}
