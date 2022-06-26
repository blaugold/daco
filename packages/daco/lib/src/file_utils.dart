import 'dart:io';

import 'package:path/path.dart' as p;

/// Finds all Dart source files in the given [directory].
Stream<File> findDartFiles(Directory directory) => directory
    .list(recursive: true)
    .where((entry) => entry is File && isDartFile(entry.path))
    .cast<File>();

/// Whether the file at the given [path] is a Dart file.
bool isDartFile(String path) => p.extension(path) == '.dart';

/// Whether the file at the given [path] is a Markdown file.
bool isMarkdownFile(String path) => p.extension(path) == '.md';
