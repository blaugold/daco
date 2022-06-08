import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:daco/src/command_runner.dart';

Future<void> main(List<String> args) async {
  try {
    await DacoCommandRunner().run(args);
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
