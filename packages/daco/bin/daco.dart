import 'package:cli_launcher/cli_launcher.dart';
import 'package:daco/src/command_runner.dart';

Future<void> main(List<String> arguments) async =>
    runGlobalInstallation(arguments, DacoLauncher());
