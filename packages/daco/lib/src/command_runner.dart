// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cli_launcher/cli_launcher.dart';

import 'commands/analyze.dart';
import 'commands/format.dart';
import 'logging.dart';

class DacoCommandRunner extends CommandRunner<void> {
  DacoCommandRunner({
    this.logger,
  }) : super('daco', 'A tool for maintaining Dart comments.') {
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      help: 'Enable verbose logging.',
      negatable: false,
    );

    addCommand(FormatCommand());
    addCommand(AnalyzeCommand());
  }

  /// The logger to use for CLI output.
  ///
  /// If not specified, a logger will be created based on the verbose flag.
  final DacoLogger? logger;
}

class DacoLauncher extends Launcher {
  DacoLauncher() : super(PackageExecutable('daco', 'daco'));

  @override
  Future<void> run(
    List<String> arguments,
    InstallationLocation location,
  ) async {
    try {
      await DacoCommandRunner().run(arguments);
    } on UsageException catch (error) {
      exitCode = 1;
      stderr.write(error);
      // ignore: avoid_catches_without_on_clauses
    } catch (error, stackTrace) {
      exitCode = 1;
      stderr
        ..writeln('Unexpected error: $error')
        ..writeln(stackTrace);
    }
  }
}
