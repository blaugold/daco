import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';

/// Throws an exception for code branches that should never be reached.
Never unreachable() => throw StateError('This code should not be reachable.');

/// The root directory of this package.
///
/// daco needs the directory of its package to install and run the prettier
/// server, which is not part of the compiled executable.
final packageRoot = () async {
  final packageFileUri = await Isolate.resolvePackageUri(
    Uri.parse('package:daco/daco.dart'),
  );
  if (packageFileUri != null) {
    // Get from lib/daco.dart to the package root.
    return File(packageFileUri.toFilePath()).parent.parent.path;
  }

  // AOT compiled executables, such as the ones created by `dart install`, have
  // no package config, so package URIs cannot be resolved.
  return _packageRootInPubCache();
}();

/// Locates the hosted package of the version of this executable in the pub
/// cache, adding it to the pub cache if necessary.
///
/// This supports executables installed with `dart install`, which are placed
/// in an app bundle with the layout
/// `<package>/<source>/<version>/bundle/bin/<executable>`, next to a copy of
/// the package's `pubspec.yaml`.
Future<String> _packageRootInPubCache() async {
  final executable = Platform.resolvedExecutable;
  final bundlePubspecFile = File(
    p.join(p.dirname(executable), '..', '..', 'pubspec.yaml'),
  );
  if (!bundlePubspecFile.existsSync()) {
    throw StateError(
      'Could not locate the daco package for executable $executable. '
      'Run daco with `dart run daco` or install it with `dart install daco`.',
    );
  }

  final version = Pubspec.parse(
    bundlePubspecFile.readAsStringSync(),
    sourceUrl: bundlePubspecFile.uri,
  ).version;
  if (version == null) {
    throw StateError('${bundlePubspecFile.path} does not specify a version.');
  }

  final packageDir = p.join(_pubCacheDir, 'hosted', 'pub.dev', 'daco-$version');
  if (!Directory(packageDir).existsSync()) {
    await runProcess('dart', [
      'pub',
      'cache',
      'add',
      'daco',
      '--version',
      '$version',
    ]);
  }

  return packageDir;
}

String get _pubCacheDir {
  final pubCache = Platform.environment['PUB_CACHE'];
  if (pubCache != null && pubCache.isNotEmpty) {
    return pubCache;
  }

  if (Platform.isWindows) {
    return p.join(Platform.environment['LOCALAPPDATA']!, 'Pub', 'Cache');
  }

  return p.join(Platform.environment['HOME']!, '.pub-cache');
}

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
    throw Exception('''
Failed to run '$commandLine' in '$workingDirectory':
Exit code: ${result.exitCode}
Stdout:
${result.stdout}
Stderr:
${result.stderr}
''');
  }
}
