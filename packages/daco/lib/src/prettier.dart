import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:path/path.dart' as p;

import 'utils.dart';

final _serverPath = packageRoot.then((dir) => p.join(dir, 'prettier-server'));
final _lockFilePath = _serverPath.then((dir) => p.join(dir, 'lock'));
final _nodeModulesPath = _serverPath.then((dir) => p.join(dir, 'node_modules'));
final _serverEntrypoint =
    _serverPath.then((dir) => p.join(dir, 'dist/tsc-out/index.js'));

Future<void> _preparePrettierServer() async {
  // We use a lock file to ensure that the NPM package is only installed once.
  final lockFile = await File(await _lockFilePath).open(mode: FileMode.write);
  await lockFile.lock(FileLock.blockingExclusive);

  try {
    if (Directory(await _nodeModulesPath).existsSync()) {
      return;
    }

    await runProcess('npm', ['ci'], workingDirectory: await _serverPath);
  } finally {
    await lockFile.unlock();
    await lockFile.close();
  }
}

/// How to handle wrapping in markdown text.
enum ProseWrap {
  /// Wrap prose if it exceeds the print width.
  always,

  /// Un-wrap each block of prose into one line.
  never,

  /// Do nothing, leave prose as-is.
  preserve,
}

/// Service for formatting source code with prettier in a separate server
/// process.
class PrettierService {
  int? _port;
  Process? _process;
  Client? _client;

  /// Starts the server process and completes when it is ready.
  Future<void> start() async {
    await _preparePrettierServer();

    _process = await Process.start(
      'node',
      [await _serverEntrypoint],
      workingDirectory: await _serverPath,
    );

    final readyCompleter = Completer<void>();

    final stdoutLines =
        const LineSplitter().bind(utf8.decoder.bind(_process!.stdout));
    final stderrLines =
        const LineSplitter().bind(utf8.decoder.bind(_process!.stderr));

    stdoutLines.listen((line) {
      if (!readyCompleter.isCompleted) {
        // The first line is some JSON containing the port number.
        final message = jsonDecode(line) as Map<String, Object?>;
        _port = message['port']! as int;
        _client = Client();
        readyCompleter.complete();
      } else {
        stdout.writeln('[prettier server] $line');
      }
    });

    stderrLines.listen((line) => stderr.writeln('[prettier server] $line'));

    return Future.any([
      // ignore: void_checks
      _process!.exitCode.then((exitCode) {
        throw Exception(
          'Prettier server exited with exit code $exitCode.',
        );
      }),
      readyCompleter.future,
    ]);
  }

  /// Stops the server process.
  Future<void> stop() async {
    _process?.kill();
    _client?.close();
  }

  /// Formats the given [source] code.
  Future<String> format(
    String source, {
    required String parser,
    required int printWidth,
    required ProseWrap proseWrap,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Prettier server not started.');
    }

    final response = await client.post(
      Uri.parse('http://localhost:$_port/format'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'source': source,
        'options': {
          'parser': parser,
          'printWidth': printWidth,
          'proseWrap': proseWrap.name,
        }
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Prettier server returned status code ${response.statusCode}.\n'
        '${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, Object?>;
    return body['result']! as String;
  }
}
