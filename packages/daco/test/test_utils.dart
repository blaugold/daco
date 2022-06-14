import 'dart:io';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:daco/src/logging.dart';
import 'package:daco/src/prettier.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Directory? sandboxDir;

Future<Directory> createSandboxDir() async {
  sandboxDir = await Directory.systemTemp.createTemp('daco_test_');
  addTearDown(() async {
    await sandboxDir!.delete(recursive: true);
    sandboxDir = null;
  });
  return sandboxDir!;
}

File sandboxFile(String name) => File(p.join(sandboxDir!.path, name));

Future<File> createFile(String path, [String? content]) async {
  final file = await sandboxFile(path).create(recursive: true);
  await file.writeAsString(content ?? '');
  return file;
}

class TestLogger implements Logger {
  TestLogger({this.useAnsi = false, this.isVerbose = false});

  final bool useAnsi;

  final _buffer = StringBuffer();

  String get output =>
      useAnsi ? _buffer.toString() : AnsiStyles.strip(_buffer.toString());

  @override
  late final ansi = Ansi(useAnsi);

  @override
  final bool isVerbose;

  @override
  Progress progress(String message) => throw UnimplementedError();

  @override
  void stdout(String message) => _buffer.writeln(message);

  @override
  void stderr(String message) => _buffer.writeln(message);

  @override
  void trace(String message) => _buffer.writeln(message);

  @override
  void write(String message) => _buffer.write(message);

  @override
  void writeCharCode(int charCode) => _buffer.writeCharCode(charCode);

  @override
  void flush() {}
}

Future<void> installPrettierServer() async {
  await PrettierService(logger: DacoLogger(StandardLogger()))
      .installPrettierServer();
}
