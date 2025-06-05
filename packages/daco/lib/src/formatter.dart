// ignore_for_file: parameter_assignments

import 'dart:math';

import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:collection/collection.dart';
import 'package:dart_style/dart_style.dart';

import 'analyzer/block.dart';
import 'analyzer/utils.dart';
import 'char_codes.dart';
import 'prettier.dart';
import 'utils.dart';

final _dartDocTagRegExp = RegExp('{@.+}');
final _dartDocTagWithSpacerRegExp = RegExp(r'({@.+})-+$', multiLine: true);

/// Formatter which formats Dart code, including comments.
class DacoFormatter {
  /// Creates a formatter which formats Dart code, including comments.
  DacoFormatter({this.lineLength = 80, required this.prettierService});

  /// The maximum length of a line of code.
  final int lineLength;

  /// The [PrettierService] to use to format markdown.
  final PrettierService prettierService;

  /// Formats the given [source] string containing an entire Dart compilation
  /// unit.
  Future<String> format(String source, {String? path}) async {
    final parseResult = parseString(
      text: source,
      uri: path ?? 'file.dart',
      withErrorsInRootBlock: true,
    );
    _checkForSyntacticErrors(parseResult.errors);
    return _formatBlock(parseResult.block, lineLength: lineLength);
  }

  void _checkForSyntacticErrors(List<AnalysisError> errors) {
    final syntacticErrors = errors
        .where((error) => error.errorCode.type == ErrorType.SYNTACTIC_ERROR)
        .toList();

    if (syntacticErrors.isNotEmpty) {
      throw FormatterException(syntacticErrors);
    }
  }

  Future<String> _formatBlock(Block block, {required int lineLength}) async {
    if (block is DartBlock) {
      return _formatDartBlock(block, lineLength: lineLength);
    } else if (block is MarkdownBlock) {
      return _formatMarkdownBlock(block, lineLength: lineLength);
    } else {
      unreachable();
    }
  }

  Future<String> _formatDartBlock(
    DartBlock block, {
    required int lineLength,
  }) async {
    final formatter = DartFormatter(
      pageWidth:
          lineLength +
          // We add 2 to the line length to account for the indentation within
          // the main function.
          (block.isInMainBody ? 2 : 0),
      languageVersion: DartFormatter.latestLanguageVersion,
    );

    var text = block.text;
    if (block.isInMainBody) {
      // Wrap the code in a function so that it can be parsed and formatted.
      text = 'Future<void> main() async {\n$text}\n';
    }

    var formattedText = formatter.format(text);
    if (block.isInMainBody) {
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

    final formattedBlock =
        parseString(text: formattedText, uri: 'block.dart').block as DartBlock;
    final formattedComments = <MarkdownBlock, String>{};

    await Future.wait(
      formattedBlock.documentationComments.map((comment) async {
        formattedComments[comment] = await _formatMarkdownBlock(
          comment,
          lineLength: formattedBlock.availableLineLength(
            of: comment,
            lineLength: lineLength,
          ),
        );
      }),
    );

    return formattedBlock.replaceEnclosedBlocks(formattedComments);
  }

  Future<String> _formatMarkdownBlock(
    MarkdownBlock block, {
    required int lineLength,
  }) async {
    final formattedText = await _formatDocumentationCommentMarkdown(
      block.text,
      block.lineInfo,
      lineLength,
    );
    final formattedBlock =
        parseString(text: formattedText, uri: 'block.md').block
            as MarkdownBlock;
    final formattedCodeBlocks = <DartBlock, String>{};

    await Future.wait(
      formattedBlock.dartCodeBlocks.map((codeBlock) async {
        if (!codeBlock.shouldBeFormatted) {
          return;
        }

        formattedCodeBlocks[codeBlock] = await _formatDartBlock(
          codeBlock,
          lineLength: formattedBlock.availableLineLength(
            of: codeBlock,
            lineLength: lineLength,
          ),
        );
      }),
    );

    return formattedBlock.replaceEnclosedBlocks(formattedCodeBlocks);
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
