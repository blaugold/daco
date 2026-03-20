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

  final repoRoot = await _gitRepoRoot(workingDirectory: workingDirectory);
  if (repoRoot == null) {
    return files;
  }

  final pathBase = workingDirectory ?? Directory.current.path;
  final gitCheckPathsByFile = <File, List<String>>{};
  final gitCheckPaths = <String>{};

  for (final file in files) {
    final filePath = _resolvePath(file.path, from: pathBase);
    final fileGitCheckPaths = _gitCheckPathsForFile(filePath, repoRoot);
    gitCheckPathsByFile[file] = fileGitCheckPaths;
    gitCheckPaths.addAll(fileGitCheckPaths);
  }

  final ignoredPaths = await _gitIgnoredPaths(
    gitCheckPaths,
    workingDirectory: repoRoot,
  );
  if (ignoredPaths == null) {
    return files;
  }

  return files
      .where(
        (file) =>
            !(gitCheckPathsByFile[file] ?? const []).any(ignoredPaths.contains),
      )
      .toList();
}

/// Normalizes a path for cross-platform comparison by resolving `.` and `..`
/// segments and converting all separators to forward slashes.
String _normalizePath(String path) => p.normalize(path).replaceAll(r'\', '/');

Future<String?> _gitRepoRoot({String? workingDirectory}) async {
  final baseDirectory = p.absolute(workingDirectory ?? Directory.current.path);
  final result = await Process.run('git', [
    'rev-parse',
    '--show-cdup',
  ], workingDirectory: workingDirectory);

  if (result.exitCode != 0) {
    return null;
  }

  final stdout = (result.stdout as String).trim();
  return p.normalize(p.join(baseDirectory, stdout.isEmpty ? '.' : stdout));
}

Future<Set<String>?> _gitIgnoredPaths(
  Iterable<String> paths, {
  required String workingDirectory,
}) async {
  final normalizedPaths = paths.map(_normalizePath).toSet();
  if (normalizedPaths.isEmpty) {
    return {};
  }

  final process = await Process.start('git', [
    'check-ignore',
    '--stdin',
  ], workingDirectory: workingDirectory);

  process.stdin.write('${normalizedPaths.join('\n')}\n');
  await process.stdin.close();

  final stdoutFuture = process.stdout
      .transform(const SystemEncoding().decoder)
      .join();
  final stderrFuture = process.stderr.drain<void>();
  final exitCode = await process.exitCode;
  await stderrFuture;

  // Exit code 1 means no files are ignored, 0 means some are.
  // Any other code means git is not available or not in a repo.
  if (exitCode != 0 && exitCode != 1) {
    return null;
  }

  final stdout = await stdoutFuture;
  return stdout
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map(_normalizePath)
      .toSet();
}

List<String> _gitCheckPathsForFile(String filePath, String repoRoot) {
  final relativePath = _relativePathFromRepoRoot(filePath, repoRoot);
  if (relativePath == null) {
    return const [];
  }

  final segments = p.split(relativePath);
  final gitCheckPaths = <String>[];
  var currentPath = repoRoot;
  final currentSegments = <String>[];

  for (final segment in segments) {
    currentPath = p.join(currentPath, segment);
    currentSegments.add(segment);
    gitCheckPaths.add(_normalizePath(p.joinAll(currentSegments)));

    if (FileSystemEntity.typeSync(currentPath, followLinks: false) ==
        FileSystemEntityType.link) {
      break;
    }
  }

  return gitCheckPaths;
}

String _resolvePath(String path, {required String from}) =>
    p.normalize(p.isAbsolute(path) ? path : p.join(from, path));

String? _relativePathFromRepoRoot(String filePath, String repoRoot) {
  if (_isInDirectory(filePath, repoRoot)) {
    return p.relative(filePath, from: repoRoot);
  }

  final repoRootName = p.basename(repoRoot);
  final filePathSegments = p.split(filePath);
  final rootIndex = filePathSegments.lastIndexOf(repoRootName);
  if (rootIndex == -1 || rootIndex == filePathSegments.length - 1) {
    return null;
  }

  return p.joinAll(filePathSegments.skip(rootIndex + 1));
}

bool _isInDirectory(String path, String directory) =>
    path == directory || p.isWithin(directory, path);

/// Whether the file at the given [path] is a Dart file.
bool isDartFile(String path) => p.extension(path) == '.dart';

/// Whether the file at the given [path] is a Markdown file.
bool isMarkdownFile(String path) => p.extension(path) == '.md';
