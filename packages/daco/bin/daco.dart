import 'package:cli_launcher/cli_launcher.dart';
import 'package:daco/src/command_runner.dart';

void main(List<String> arguments) {
  launchExecutable(
    arguments,
    LaunchConfig(
      name: ExecutableName('daco'),
      entrypoint: dacoEntryPoint,
    ),
  );
}
