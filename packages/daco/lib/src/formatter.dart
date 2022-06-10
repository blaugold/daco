// ignore_for_file: parameter_assignments

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:ansi_styles/ansi_styles.dart';
import 'package:collection/collection.dart';
import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as p;

import 'dart_comments.dart';
import 'logging.dart';
import 'prettier.dart';

/// The result of formatting a Dart source file.
enum FormattingResult {
  /// The file was not changed.
  unchanged,

  /// The file was changed.
  changed,

  /// The file could not be formatted.
  failed,
}

/// Formats the Dart source [file], including comments.
Future<FormattingResult> formatFile(
  File file, {
  required DartFormatter dartFormatter,
  required PrettierService prettierService,
  required DacoLogger logger,
}) async {
  final relativePath = p.relative(file.path);
  final source = await file.readAsString();
  String formattedSource;
  try {
    formattedSource =
        dartFormatter.formatSource(SourceCode(source, uri: file.path)).text;

    formattedSource = await formatCommentsInSource(
      formattedSource,
      path: file.path,
      dartFormatter: dartFormatter,
      prettierService: prettierService,
    );
    // ignore: avoid_catches_without_on_clauses
  } catch (exception) {
    FormatterException? formatterException;
    CharacterLocation? fencedCodeBlockLocation;

    if (exception is FormatterException) {
      formatterException = exception;
    } else if (exception is _FencedCodeBlockFormatterException) {
      formatterException = exception.exception;
      final lineInfo = LineInfo.fromContent(source);
      fencedCodeBlockLocation = lineInfo.getLocation(exception.offset);
    }

    if (formatterException == null) {
      rethrow;
    }

    logger.stderr('${AnsiStyles.red('FAILED')}    $relativePath');
    if (fencedCodeBlockLocation != null) {
      logger.stderr(
        'in ${AnsiStyles.bold.underline('fenced code block')} at '
        'line ${fencedCodeBlockLocation.lineNumber}, '
        'column ${fencedCodeBlockLocation.columnNumber}:',
      );
    }
    logger
        .stderr(formatterException.message(color: stdout.supportsAnsiEscapes));

    return FormattingResult.failed;
  }

  if (formattedSource == source) {
    logger.stdout(AnsiStyles.gray('UNCHANGED $relativePath'));
    return FormattingResult.unchanged;
  } else {
    logger.stdout('CHANGED   $relativePath');
    await file.writeAsString(formattedSource);
    return FormattingResult.changed;
  }
}

/// Formats documentation comments in Dart [source] code.
Future<String> formatCommentsInSource(
  String source, {
  required DartFormatter dartFormatter,
  required PrettierService prettierService,
  String? path,
}) =>
    processComments(
      source: source,
      path: path,
      lineLength: dartFormatter.pageWidth,
      processor: (comment, lineLength, lineOffsets) async {
        _validateFencedDartCode(comment, lineOffsets);
        comment = await _formatMarkdown(comment, lineLength, prettierService);
        return _formatFencedDartCode(
          comment,
          lineLength,
          dartFormatter.fixes,
          prettierService,
        );
      },
    );

final _dartDocTagRegExp = RegExp('{@.+}');
final _dartDocTagWithSpacerRegExp = RegExp(r'({@.+})-+$', multiLine: true);

Future<String> _formatMarkdown(
  String source,
  int lineLength,
  PrettierService prettierService,
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

final _fencedDartCodeRegExp =
    RegExp(r'```dart\n(((?!```)(.|\n))*)```', multiLine: true);

void _validateFencedDartCode(String source, List<int> lineOffsets) {
  for (final match in _fencedDartCodeRegExp.allMatches(source)) {
    final dartSource = match.group(1)!;
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
      throw _FencedCodeBlockFormatterException(
        offsetInSource,
        FormatterException(parseResult.errors),
      );
    }
  }
}

Future<String> _formatFencedDartCode(
  String source,
  int lineLength,
  Set<StyleFix> fixes,
  PrettierService prettierService,
) async {
  var fencedDartCodes = _fencedDartCodeRegExp
      .allMatches(source)
      .map((match) => match.group(1)!)
      .toList();

  final dartFormatter = DartFormatter(pageWidth: lineLength, fixes: fixes);

  fencedDartCodes = await Future.wait(
    fencedDartCodes.map((code) async {
      code = dartFormatter.format(code);

      return formatCommentsInSource(
        code,
        dartFormatter: dartFormatter,
        prettierService: prettierService,
      );
    }),
  );

  var i = 0;
  return source.replaceAllMapped(
    _fencedDartCodeRegExp,
    (match) => '```dart\n${fencedDartCodes[i++]}```',
  );
}

class _FencedCodeBlockFormatterException implements Exception {
  _FencedCodeBlockFormatterException(this.offset, this.exception);

  /// The offset in the source file to where the fenced code block starts.
  final int offset;

  /// The exception for the Dart code in the fenced code block.
  final FormatterException exception;
}
