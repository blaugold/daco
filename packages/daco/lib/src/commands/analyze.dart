// ignore_for_file: public_member_api_docs

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:ansi_styles/ansi_styles.dart';
import 'package:path/path.dart' as p;

import '../analyzer/analyzer.dart';
import '../analyzer/exceptions.dart';
import '../char_codes.dart';
import '../file_utils.dart';
import '../utils.dart';
import 'daco_command.dart';

class AnalyzeCommand extends DacoCommand {
  AnalyzeCommand() {
    argParser
      ..addFlag(
        'fatal-infos',
        help: 'Treat info level issues as fatal.',
        negatable: false,
      )
      ..addFlag(
        'fatal-warnings',
        help: 'Treat warning level issues as fatal.',
        defaultsTo: true,
      )
      ..addOption(
        'package',
        help:
            'Import the public API of this package into analyzed code '
            'examples by default.',
      );
  }

  @override
  String get name => 'analyze';

  @override
  String get description =>
      'Analyzes embedded Dart examples in Dart, Markdown, and MDX files.';

  bool get _fatalInfos => argResults!['fatal-infos']! as bool;

  bool get _fatalWarnings => argResults!['fatal-warnings']! as bool;

  String? get _package => argResults!['package'] as String?;

  List<String> get _includedPaths {
    final rest = argResults!.rest;
    if (rest.isNotEmpty) {
      return rest.map(p.absolute).map(p.normalize).toList();
    }

    return [Directory.current.path];
  }

  @override
  Future<void> run() async {
    final files = await _collectFiles();
    if (files.isEmpty) {
      return;
    }

    final analysisContexts = createAnalysisContextCollection(
      includedPaths: _includedPaths,
    );

    final filesByContext = <AnalysisContext, List<File>>{};
    for (final file in files) {
      final analysisContext = analysisContexts.contextFor(file.path);
      filesByContext.putIfAbsent(analysisContext, () => []).add(file);
    }

    for (final MapEntry(key: analysisContext, value: contextFiles)
        in filesByContext.entries) {
      final progress = logger.progress(
        'Analyzing ${_contextRootDisplayName(analysisContext)}',
      );

      Iterable<Diagnostic> allErrors;
      try {
        final analyzer = DacoAnalyzer(
          analysisContext: analysisContext,
          publicApiPackageName: _package,
        );
        allErrors = (await Future.wait(
          contextFiles.map((file) => analyzer.session.getErrors(file.path)),
        )).expand((errors) => errors);
      } on PublicApiFileNotFound catch (error) {
        progress.finish(message: 'Failed.');
        logger.stderr(error.toString());
        exitCode = 2;
        continue;
      }

      if (allErrors.isEmpty) {
        progress.finish(message: 'Found no issues.');
      } else {
        progress.finish(message: 'Found issues:');
        for (final error in allErrors) {
          _setExitCode(error);
          logger.stdout(_formatError(error));
        }
      }
    }
  }

  Future<List<File>> _collectFiles() async {
    final files = await filterGitIgnoredFiles(
      await Stream<FileSystemEntity>.fromIterable(
            _includedPaths.map((path) {
              switch (FileSystemEntity.typeSync(path)) {
                case FileSystemEntityType.file:
                  final file = File(path);
                  if (!isSupportedSourceFile(file.path)) {
                    throw usageException('Unsupported file type: $path');
                  }
                  return file;
                case FileSystemEntityType.directory:
                  return Directory(path);
                case FileSystemEntityType.link:
                case FileSystemEntityType.pipe:
                case FileSystemEntityType.unixDomainSock:
                  throw usageException('Unsupported path type: $path');
                case FileSystemEntityType.notFound:
                  return usageException('File not found: $path');
              }

              unreachable();
            }),
          )
          .asyncExpand(
            (entity) => entity is File
                ? Stream.value(entity)
                : findSupportedSourceFiles(entity as Directory),
          )
          .toList(),
    );
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  String _contextRootDisplayName(AnalysisContext analysisContext) =>
      p.relative(analysisContext.contextRoot.root.path);

  void _setExitCode(Diagnostic error) {
    if (exitCode != 0) {
      return;
    }

    switch (error.severity) {
      case Severity.error:
        exitCode = 1;
      case Severity.warning:
        if (_fatalWarnings) {
          exitCode = 1;
        }
      case Severity.info:
        if (_fatalInfos) {
          exitCode = 1;
        }
    }
  }

  String _formatError(Diagnostic error) {
    final buffer = StringBuffer();

    final lineInfo = LineInfo.fromContent(error.source.contents.data);
    final location = lineInfo.getLocation(error.offset);

    final String Function(String) errorCodeStyle;
    switch (error.severity) {
      case Severity.error:
        errorCodeStyle = AnsiStyles.red.call;
      case Severity.warning:
        errorCodeStyle = AnsiStyles.yellow.call;
      case Severity.info:
        errorCodeStyle = AnsiStyles.blue.call;
    }

    buffer
      ..write(
        AnsiStyles.gray(
          '${p.relative(error.source.fullName)}'
          ':${location.lineNumber}:${location.columnNumber}',
        ),
      )
      ..write(' $bullet ')
      ..write(error.message)
      ..write(' $bullet ')
      ..write(errorCodeStyle(error.diagnosticCode.lowerCaseName));

    return buffer.toString();
  }
}
