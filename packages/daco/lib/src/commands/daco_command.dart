import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';

import '../logging.dart';

/// Base class for all daco commands.
abstract class DacoCommand extends Command<void> {
  /// Whether verbose logging is enabled.
  bool get verbose => globalResults!['verbose']! as bool;

  /// The logger to use for CLI output.
  late final logger =
      DacoLogger(verbose ? Logger.verbose() : Logger.standard());
}
