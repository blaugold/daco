import 'dart:io';

import 'package:path/path.dart' as p;

/// Finds all Dart source files in the given [directory].
Stream<File> findDartFiles(Directory directory) => directory
    .list(recursive: true)
    .where((entry) => entry is File && isDartFile(entry.path))
    .cast<File>();

/// Filters out files that are ignored by git.
///
/// Uses the current working directory to determine the git repository, unless
/// [workingDirectory] is provided.
Future<List<File>> filterGitIgnoredFiles(
  List<File> files, {
  String? workingDirectory,
}) async {
  if (files.isEmpty) {
    return files;
  }

  final process = await Process.start('git', [
    'check-ignore',
    '--stdin',
  ], workingDirectory: workingDirectory);

  process.stdin.writeln(files.map((f) => f.path).join('\n'));
  await process.stdin.close();

  final stdout = await process.stdout
      .transform(const SystemEncoding().decoder)
      .join();
  final exitCode = await process.exitCode;

  // Exit code 1 means no files are ignored, 0 means some are.
  // Any other code means git is not available or not in a repo.
  if (exitCode != 0 && exitCode != 1) {
    return files;
  }

  final ignoredPaths = stdout
      .split('\n')
      .where((line) => line.isNotEmpty)
      .map<String>(p.canonicalize)
      .toSet();

  return files
      .where((file) => !ignoredPaths.contains(p.canonicalize(file.path)))
      .toList();
}

/// Whether the file at the given [path] is a Dart file.
bool isDartFile(String path) => p.extension(path) == '.dart';

/// Whether the file at the given [path] is a Markdown file.
bool isMarkdownFile(String path) => p.extension(path) == '.md';
