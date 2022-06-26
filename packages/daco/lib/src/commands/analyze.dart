// ignore_for_file: public_member_api_docs

import 'dart:io';

import 'package:analyzer/dart/analysis/context_locator.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:ansi_styles/ansi_styles.dart';
import 'package:path/path.dart' as p;

import '../analyzer/analysis_context.dart';
import '../analyzer/analyzer.dart';
import '../char_codes.dart';
import '../file_utils.dart';
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
      );
  }

  @override
  String get name => 'analyze';

  @override
  String get description => 'Analyzes example code in documentation comments.';

  bool get _fatalInfos => argResults!['fatal-infos']! as bool;

  bool get _fatalWarnings => argResults!['fatal-warnings']! as bool;

  List<String> get _includedPaths {
    final rest = argResults!.rest;
    if (rest.isNotEmpty) {
      return rest.map(p.absolute).map(p.normalize).toList();
    }

    return [Directory.current.path];
  }

  @override
  Future<void> run() async {
    final contextLocator = ContextLocator();
    final contextRoots =
        contextLocator.locateRoots(includedPaths: _includedPaths);

    for (final contextRoot in contextRoots) {
      final analyzer = DacoAnalyzer(contextRoot: contextRoot);

      final progress =
          logger.progress('Analyzing ${_contextRootDisplayName(analyzer)}');

      final allErrors = (await Future.wait(
        contextRoot
            .analyzedFiles()
            .where(isDartFile)
            .map((file) => analyzer.session.getErrors(file)),
      ))
          .expand((errors) => errors);

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

  String _contextRootDisplayName(DacoAnalysisContext analysisContext) =>
      analysisContext.pubspec?.name ??
      p.relative(analysisContext.contextRoot.root.path);

  void _setExitCode(AnalysisError error) {
    if (exitCode != 0) {
      return;
    }

    switch (error.severity) {
      case Severity.error:
        exitCode = 1;
        break;
      case Severity.warning:
        if (_fatalWarnings) {
          exitCode = 1;
        }
        break;
      case Severity.info:
        if (_fatalInfos) {
          exitCode = 1;
        }
        break;
    }
  }

  String _formatError(AnalysisError error) {
    final buffer = StringBuffer();

    final lineInfo = LineInfo.fromContent(error.source.contents.data);
    final location = lineInfo.getLocation(error.offset);

    final String Function(String) errorCodeStyle;
    switch (error.severity) {
      case Severity.error:
        errorCodeStyle = AnsiStyles.red;
        break;
      case Severity.warning:
        errorCodeStyle = AnsiStyles.yellow;
        break;
      case Severity.info:
        errorCodeStyle = AnsiStyles.blue;
        break;
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
      ..write(errorCodeStyle(error.errorCode.name));

    return buffer.toString();
  }
}
