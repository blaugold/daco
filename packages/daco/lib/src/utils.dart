import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

/// Throws an exception for code branches that should never be reached.
Never unreachable() => throw StateError('This code should not be reachable.');

/// The root directory of this package.
final packageRoot = () async {
  final packageFileUri = await Isolate.resolvePackageUri(
    Uri.parse('package:daco/daco.dart'),
  );

  // Get from lib/daco.dart to the package root.
  return File(packageFileUri!.toFilePath()).parent.parent.path;
}();

/// Runs a [command] to completion in a new process.
Future<void> runProcess(
  String command,
  List<String> arguments, {
  String? workingDirectory,
}) async {
  final result = await Process.run(
    command,
    arguments,
    workingDirectory: workingDirectory,
    stderrEncoding: utf8,
    stdoutEncoding: utf8,
    runInShell: true,
  );

  if (result.exitCode != 0) {
    final commandLine = '$command ${arguments.join(' ')}';
    workingDirectory ??= Directory.current.path;
    throw Exception(
      '''
Failed to run '$commandLine' in '$workingDirectory':
Exit code: ${result.exitCode}
Stdout:
${result.stdout}
Stderr:
${result.stderr}
''',
    );
  }
}
