// ignore_for_file: public_member_api_docs

import 'package:args/command_runner.dart';

import 'commands/format.dart';

class DacoCommandRunner extends CommandRunner<void> {
  DacoCommandRunner() : super('daco', 'A tool for maintaining Dart comments.') {
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      help: 'Enable verbose logging.',
      negatable: false,
    );

    addCommand(FormatCommand());
  }
}
