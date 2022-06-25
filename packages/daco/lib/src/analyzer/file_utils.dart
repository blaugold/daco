import 'package:path/path.dart' as p;

/// Whether the file at the given [path] is a Dart file.
bool isDartFile(String path) => p.extension(path) == '.dart';

/// Whether the file at the given [path] is a Markdown file.
bool isMarkdownFile(String path) => p.extension(path) == '.md';
