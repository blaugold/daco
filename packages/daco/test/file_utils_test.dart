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

    test('filters gitignored files with "." as working directory', () async {
      final previousCurrent = Directory.current;
      Directory.current = tempDir;
      addTearDown(() => Directory.current = previousCurrent);

      await Process.run('git', ['init'], workingDirectory: tempDir.path);

      final gitignore = File('${tempDir.path}/.gitignore');
      await gitignore.writeAsString('ignored/\n');

      final kept = File('${tempDir.path}/kept.dart');
      await kept.writeAsString('');
      final ignoredDir = Directory('${tempDir.path}/ignored');
      await ignoredDir.create();
      final ignored = File('${tempDir.path}/ignored/file.dart');
      await ignored.writeAsString('');

      final result = await filterGitIgnoredFiles([
        kept,
        ignored,
      ], workingDirectory: '.');

      expect(result.map((f) => f.path), [kept.path]);
    });

    test(
      'filters ignored files below symlinked Flutter plugin directories',
      () async {
        await Process.run('git', ['init'], workingDirectory: tempDir.path);

        final gitignore = File('${tempDir.path}/.gitignore');
        await gitignore.writeAsString('linux/flutter/ephemeral/\n');

        final pluginDir = Directory('${tempDir.path}/plugin');
        await pluginDir.create();
        final pluginFile = File('${pluginDir.path}/plugin.dart');
        await pluginFile.writeAsString('');

        final symlink = Link(
          '${tempDir.path}/linux/flutter/ephemeral/.plugin_symlinks/plugin',
        );
        await symlink.parent.create(recursive: true);
        await symlink.create(pluginDir.path);

        final ignored = File('${symlink.path}/plugin.dart');
        final kept = File('${tempDir.path}/lib/main.dart');
        await kept.parent.create(recursive: true);
        await kept.writeAsString('');

        final result = await filterGitIgnoredFiles([
          ignored,
          kept,
        ], workingDirectory: tempDir.path);

        expect(result.map((f) => f.path), [kept.path]);
      },
    );

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
