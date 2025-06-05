// ignore_for_file: public_member_api_docs

import 'dart:io';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as p;

import '../file_utils.dart';
import '../formatter.dart';
import '../logging.dart';
import '../prettier.dart';
import '../utils.dart';
import 'daco_command.dart';

class FormatCommand extends DacoCommand {
  FormatCommand() {
    argParser
      ..addFlag(
        'set-exit-if-changed',
        help: 'Return exit code 1 if there are any formatting changes.',
        negatable: false,
      )
      ..addOption(
        'line-length',
        abbr: 'l',
        help: 'Wrap lines longer than this.',
        defaultsTo: '80',
      );
  }

  @override
  String get description => 'Formats Dart code, including comments.';

  @override
  String get name => 'format';

  bool get _setExistIfChanged => argResults!['set-exit-if-changed']! as bool;

  int get _lineLength {
    final string = argResults!['line-length']! as String;
    try {
      return int.parse(string);
    } on FormatException catch (e) {
      usageException('Invalid line-length: $string\n$e');
    }
  }

  List<String> get _files => argResults!.rest;

  @override
  Future<void> run() async {
    if (_files.isEmpty) {
      usageException('No files specified.');
    }

    final files =
        await Stream.fromIterable(
              _files.map((e) {
                // ignore: exhaustive_cases
                switch (FileSystemEntity.typeSync(e)) {
                  case FileSystemEntityType.file:
                    return File(e);
                  case FileSystemEntityType.directory:
                    return Directory(e);
                  case FileSystemEntityType.notFound:
                    return usageException('File not found: $e');
                  // ignore: no_default_cases
                  default:
                    unreachable();
                }
              }),
            )
            .asyncExpand(
              (entity) => entity is File
                  ? Stream.value(entity)
                  : findDartFiles(entity as Directory),
            )
            .toList();

    final prettierService = PrettierService(logger: logger);
    await prettierService.start();

    try {
      final dartFormatter = DacoFormatter(
        lineLength: _lineLength,
        prettierService: prettierService,
      );

      for (final file in files) {
        final result = await _formatFile(
          file,
          formatter: dartFormatter,
          logger: logger,
        );
        switch (result) {
          case _FormattingResult.unchanged:
            break;
          case _FormattingResult.changed:
            if (_setExistIfChanged && exitCode == 0) {
              exitCode = 1;
            }
            break;
          case _FormattingResult.failed:
            exitCode = 2;
            break;
        }
      }
    } finally {
      await prettierService.stop();
    }
  }
}

enum _FormattingResult { unchanged, changed, failed }

Future<_FormattingResult> _formatFile(
  File file, {
  required DacoFormatter formatter,
  required DacoLogger logger,
}) async {
  final relativePath = p.relative(file.path);
  final source = await file.readAsString();
  String formattedSource;
  try {
    formattedSource = await formatter.format(source, path: file.path);
  } on FormatterException catch (exception) {
    logger
      ..stderr('${AnsiStyles.red('FAILED')}    $relativePath')
      ..stderr(exception.message(color: stdout.supportsAnsiEscapes));

    return _FormattingResult.failed;
  }

  if (formattedSource == source) {
    logger.stdout(AnsiStyles.gray('UNCHANGED $relativePath'));
    return _FormattingResult.unchanged;
  } else {
    logger.stdout('CHANGED   $relativePath');
    await file.writeAsString(formattedSource);
    return _FormattingResult.changed;
  }
}
