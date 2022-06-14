// ignore_for_file: parameter_assignments

import 'dart:math';

import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:collection/collection.dart';
import 'package:dart_style/dart_style.dart';

import 'char_codes.dart';
import 'code_block_attribute.dart';
import 'prettier.dart';
import 'source.dart';

final _dartDocTagRegExp = RegExp('{@.+}');
final _dartDocTagWithSpacerRegExp = RegExp(r'({@.+})-+$', multiLine: true);

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
    _checkForDartSyntacticErrors(rootSource);
    return _formatDart(rootSource, lineLength: lineLength);
  }

  void _checkForDartSyntacticErrors(DartSource source) {
    final errors = <AnalysisError>[];
    final sources = <DartSource>[source];

    while (sources.isNotEmpty) {
      final source = sources.removeAt(0);

      final syntacticErrors = source
          .analysisErrors()
          .where((error) => error.errorCode.type == ErrorType.SYNTACTIC_ERROR);
      errors.addAll(syntacticErrors);

      final enclosedDartSources = source.documentationComments().expand(
            (comment) => comment
                .dartCodeBlocks()
                .whereNot((codeBlock) => codeBlock.isIgnored)
                .map((codeBlock) {
              if (codeBlock.isInMainFunction) {
                return DartSource.composed([
                  'Future<void> main() async {',
                  codeBlock,
                  '}',
                ]);
              } else {
                return codeBlock;
              }
            }),
          );
      sources.addAll(enclosedDartSources);
    }

    if (errors.isNotEmpty) {
      throw FormatterException(errors);
    }
  }

  Future<String> _formatDart(
    DartSource source, {
    required int lineLength,
  }) async {
    final formatter = DartFormatter(
      pageWidth: lineLength +
          // We add 2 to the line length to account for the indentation within
          // the main function.
          (source.isInMainFunction ? 2 : 0),
      fixes: fixes,
    );

    var text = source.text;
    if (source.isInMainFunction) {
      // Wrap the code in a function so that it can be parsed and formatted.
      text = 'Future<void> main() async {\n$text}\n';
    }

    var formattedText = formatter.format(text);
    if (source.isInMainFunction) {
      // We need to remove the main function wrapper we added earlier.
      final buffer = StringBuffer();
      final lines = formattedText.split('\n').toList();
      // We skip the lines we added to wrap the code in the main function.
      lines.skip(1).take(max(0, lines.length - 3)).forEach((line) {
        // Remove indentation.
        var lineIndentation = 0;
        while (lineIndentation < 2 &&
            line.length > lineIndentation &&
            line.codeUnitAt(lineIndentation) == $SPACE) {
          lineIndentation++;
        }
        buffer.writeln(line.substring(lineIndentation));
      });
      formattedText = buffer.toString();
    }

    final formattedSource = DartSource(text: formattedText);
    final formattedComments = <MarkdownSource, String>{};

    await Future.wait(
      formattedSource.documentationComments().map((comment) async {
        formattedComments[comment] = await _formatDocumentationComment(
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

  Future<String> _formatDocumentationComment(
    MarkdownSource source, {
    required int lineLength,
  }) async {
    final formattedText = await _formatDocumentationCommentMarkdown(
      source.text,
      source.lineInfo,
      lineLength,
    );
    final formattedSource = MarkdownSource(text: formattedText);
    final formattedCodeBlocks = <DartSource, String>{};

    await Future.wait(
      formattedSource.dartCodeBlocks().map((codeBlock) async {
        if (codeBlock.isIgnored) {
          return;
        }

        formattedCodeBlocks[codeBlock] = await _formatDart(
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

  Future<String> _formatDocumentationCommentMarkdown(
    String text,
    LineInfo lineInfo,
    int lineLength,
  ) async {
    final tagMatches = _dartDocTagRegExp.allMatches(text);
    final tagLines = <int>{};
    for (final match in tagMatches) {
      final startLine = lineInfo.getLocation(match.start).lineNumber;
      final endLine = lineInfo.getLocation(match.end).lineNumber;
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
