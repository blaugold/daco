import 'dart:io';

import 'package:daco/src/file_utils.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('daco_test_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('filterGitIgnoredFiles', () {
    test('filters out gitignored files', () async {
      // Initialize a git repo in the temp directory.
      await Process.run('git', ['init'], workingDirectory: tempDir.path);

      // Create a .gitignore file.
      final gitignore = File('${tempDir.path}/.gitignore');
      await gitignore.writeAsString('ignored/\n');

      // Create files.
      final kept = File('${tempDir.path}/kept.dart');
      await kept.writeAsString('');
      final ignoredDir = Directory('${tempDir.path}/ignored');
      await ignoredDir.create();
      final ignored = File('${tempDir.path}/ignored/file.dart');
      await ignored.writeAsString('');

      final result = await filterGitIgnoredFiles([
        kept,
        ignored,
      ], workingDirectory: tempDir.path);

      expect(result.map((f) => f.path), [kept.path]);
    });

    test('returns all files when not in a git repo', () async {
      final file = File('${tempDir.path}/test.dart');
      await file.writeAsString('');

      final result = await filterGitIgnoredFiles([file]);

      expect(result.map((f) => f.path), [file.path]);
    });

    test('returns empty list for empty input', () async {
      final result = await filterGitIgnoredFiles([]);

      expect(result, isEmpty);
    });
  });
}
