import 'dart:io';

import 'package:path/path.dart' as p;

/// Finds all Dart source files in the given [directory].
Stream<File> findDartFiles(Directory directory) => directory
    .list(recursive: true)
    .where((entry) => entry is File && isDartFile(entry.path))
    .cast<File>();

/// Finds all supported source files in the given [directory].
Stream<File> findSupportedSourceFiles(Directory directory) => directory
    .list(recursive: true)
    .where((entry) => entry is File && isSupportedSourceFile(entry.path))
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

  // Use forward slashes for git compatibility on Windows.
  process.stdin.writeln(
    files.map((f) => f.path.replaceAll(r'\', '/')).join('\n'),
  );
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
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map(_normalizePath)
      .toSet();

  return files
      .where((file) => !ignoredPaths.contains(_normalizePath(file.path)))
      .toList();
}

/// Normalizes a path for cross-platform comparison by resolving `.` and `..`
/// segments and converting all separators to forward slashes.
String _normalizePath(String path) => p.normalize(path).replaceAll(r'\', '/');

/// Whether the file at the given [path] is a Dart file.
bool isDartFile(String path) => p.extension(path) == '.dart';

/// Whether the file at the given [path] is a Markdown file.
bool isMarkdownFile(String path) => p.extension(path) == '.md';

/// Whether the file at the given [path] is an MDX file.
bool isMdxFile(String path) => p.extension(path) == '.mdx';

/// Whether the file at the given [path] is a Markdown or MDX file.
bool isMarkdownLikeFile(String path) => isMarkdownFile(path) || isMdxFile(path);

/// Whether the file at the given [path] is supported by daco.
bool isSupportedSourceFile(String path) =>
    isDartFile(path) || isMarkdownLikeFile(path);
