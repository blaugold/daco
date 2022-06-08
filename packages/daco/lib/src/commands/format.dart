// ignore_for_file: public_member_api_docs

import 'dart:io';

import 'package:dart_style/dart_style.dart';

import '../file_utils.dart';
import '../formatter.dart';
import '../prettier.dart';
import '../utils.dart';
import 'daco_command.dart';

class FormatCommand extends DacoCommand {
  FormatCommand() {
    argParser
      ..addFlag(
        'fix',
        help: 'Apply all style fixes.',
        negatable: false,
      )
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

  bool get _fix => argResults!['fix']! as bool;

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

    final files = await Stream.fromIterable(
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

    final prettierService = PrettierService();
    await prettierService.start();

    try {
      final dartFormatter = DartFormatter(
        pageWidth: _lineLength,
        fixes: _fix ? StyleFix.all : [],
      );

      for (final file in files) {
        final result = await formatFile(
          file,
          dartFormatter: dartFormatter,
          prettierService: prettierService,
          logger: logger,
        );
        switch (result) {
          case FormattingResult.unchanged:
            break;
          case FormattingResult.changed:
            if (_setExistIfChanged && exitCode == 0) {
              exitCode = 1;
            }
            break;
          case FormattingResult.failed:
            exitCode = 2;
            break;
        }
      }
    } finally {
      await prettierService.stop();
    }
  }
}
