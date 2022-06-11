// ignore_for_file: parameter_assignments

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:collection/collection.dart';
import 'package:dart_style/dart_style.dart';

import 'dart_comments.dart';
import 'prettier.dart';
import 'utils.dart';

final _dartDocTagRegExp = RegExp('{@.+}');
final _dartDocTagWithSpacerRegExp = RegExp(r'({@.+})-+$', multiLine: true);

final _fencedDartCodeRegExp =
    RegExp(r'^(\S*)```dart([^\n]*)\n(((?!```)(.|\n))*)```', multiLine: true);

const _noFormatTag = 'no_format';

/// Exception thrown when an error occurs while formatting a fenced code block.
class FencedCodeBlockFormatterException implements Exception {
  /// Creates an exception thrown when an error occurs while formatting a fenced
  /// code block.
  FencedCodeBlockFormatterException(this.offset, this.exception);

  /// The offset in the source file to where the fenced code block starts.
  final int offset;

  /// The exception for the Dart code in the fenced code block.
  final FormatterException exception;
}

/// Formatter which formats Dart code, including comments.
class DacoFormatter {
  /// Creates a formatter which formats Dart code, including comments.
  DacoFormatter({
    this.lineLength = 80,
    Iterable<StyleFix>? fixes,
    required this.prettierService,
  })  : fixes = {...?fixes},
        _dartFormatter = DartFormatter(pageWidth: lineLength, fixes: fixes);

  /// The maximum length of a line of code.
  final int lineLength;

  /// The fixes to apply to Dart code.
  final Set<StyleFix> fixes;

  /// The [PrettierService] to use to format markdown.
  final PrettierService prettierService;

  final DartFormatter _dartFormatter;

  /// Formats the given [source] string containing an entire Dart compilation
  /// unit.
  Future<String> format(String source, {String? path}) async {
    source = _dartFormatter.formatSource(SourceCode(source, uri: path)).text;

    return _formatCommentsInSource(source, path: path);
  }

  Future<String> _formatCommentsInSource(String source, {String? path}) =>
      processComments(
        source: source,
        path: path,
        lineLength: _dartFormatter.pageWidth,
        processor: (comment, lineLength, lineOffsets) async {
          _validateFencedDartCode(comment, lineOffsets);
          comment = await _formatMarkdown(comment, lineLength);
          return _formatFencedDartCode(comment, lineLength);
        },
      );

  Future<String> _formatMarkdown(
    String source,
    int lineLength,
  ) async {
    final lineInfo = LineInfo.fromContent(source);
    final tagMatches = _dartDocTagRegExp.allMatches(source);
    final tagLines = <int>{};
    for (final match in tagMatches) {
      final startLine = lineInfo.getLocation(match.start).lineNumber;
      final endLine = lineInfo.getLocation(match.end).lineNumber;
      for (var line = startLine; line <= endLine; line++) {
        // LineInfo returns 1-based line numbers, but we want 0-based.
        tagLines.add(line - 1);
      }
    }

    source = source
        .split('\n')
        .mapIndexed(
          (index, line) =>
              tagLines.contains(index) ? line.padRight(lineLength, '-') : line,
        )
        .join('\n');

    source = await prettierService.format(
      source,
      parser: 'markdown',
      printWidth: lineLength,
      proseWrap: ProseWrap.always,
    );

    return source.replaceAllMapped(
      _dartDocTagWithSpacerRegExp,
      (match) => match.group(1)!,
    );
  }

  void _validateFencedDartCode(String source, List<int> lineOffsets) {
    for (final match in _fencedDartCodeRegExp.allMatches(source)) {
      final tags = _parseTags(match.group(2)!);
      if (tags.contains(_noFormatTag)) {
        continue;
      }

      final dartSource = match.group(3)!;
      final parseResult = parseString(
        content: dartSource,
        throwIfDiagnostics: false,
        path: 'fenced code block',
      );
      final syntacticErrors = parseResult.errors
          .where((error) => error.errorCode.type == ErrorType.SYNTACTIC_ERROR)
          .toList();
      if (syntacticErrors.isNotEmpty) {
        final lineInfo = LineInfo.fromContent(source);
        final location = lineInfo.getLocation(match.start);
        final offsetInSource =
            lineOffsets[location.lineNumber - 1] + location.columnNumber - 1;
        throw FencedCodeBlockFormatterException(
          offsetInSource,
          FormatterException(parseResult.errors),
        );
      }
    }
  }

  Future<String> _formatFencedDartCode(String source, int lineLength) async {
    final dartFormatter = DartFormatter(pageWidth: lineLength, fixes: fixes);

    return source.replaceAllMappedAsync(_fencedDartCodeRegExp, (match) async {
      final indentation = match.group(1);
      final rawTags = match.group(2)!;
      final tags = _parseTags(rawTags);

      if (tags.contains(_noFormatTag)) {
        return match.group(0)!;
      }

      var code = match.group(3)!;

      code = dartFormatter.format(code);

      code = await _formatCommentsInSource(code);

      code = code.split('\n').map((line) => '$indentation$line').join('\n');

      return '```dart$rawTags\n$code```';
    });
  }
}

List<String> _parseTags(String tags) => tags
    .split(' ')
    .map((tag) => tag.trim())
    .whereNot((tag) => tag.isEmpty)
    .toList();
