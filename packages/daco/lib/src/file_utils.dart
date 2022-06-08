import 'dart:io';

/// Finds all Dart source files in the given [directory].
Stream<File> findDartFiles(Directory directory) => directory
    .list(recursive: true)
    .where((event) => event is File && event.path.endsWith('.dart'))
    .cast<File>();
