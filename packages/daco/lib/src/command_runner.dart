// ignore_for_file: public_member_api_docs

import 'package:args/command_runner.dart';

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
  }

  /// The logger to use for CLI output.
  ///
  /// If not specified, a logger will be created based on the verbose flag.
  final DacoLogger? logger;
}
