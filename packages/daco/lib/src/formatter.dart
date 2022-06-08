// ignore_for_file: parameter_assignments

import 'dart:io';

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
  } catch (e) {
    logger.stderr('${AnsiStyles.red('FAILED')}    $relativePath');
    if (e is FormatterException) {
      logger.stderr(e.message(color: stdout.supportsAnsiEscapes));
    } else {
      logger.stderr(e.toString());
    }
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
      processor: (comment, lineLength) async {
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
