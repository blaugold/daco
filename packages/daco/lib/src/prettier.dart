import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:path/path.dart' as p;

import 'logging.dart';
import 'utils.dart';

final _serverPath = packageRoot.then((dir) => p.join(dir, 'prettier-server'));
final _lockFilePath = _serverPath.then((dir) => p.join(dir, 'lock'));
final _nodeModulesPath = _serverPath.then((dir) => p.join(dir, 'node_modules'));
final _serverEntrypoint = _serverPath.then(
  (dir) => p.join(dir, 'dist/tsc-out/index.js'),
);

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
  /// Creates a service for formatting source code with prettier in a separate
  /// server process.
  PrettierService({required DacoLogger logger}) : _logger = logger;

  final DacoLogger _logger;

  int? _port;
  Process? _process;
  Client? _client;
  int _nextRequestId = 0;
  int _pendingRequests = 0;

  /// Installs the prettier server if it is not already installed.
  Future<void> installPrettierServer() async {
    // We use a lock file to ensure that the NPM package is only installed once.
    final lockFile = await File(await _lockFilePath).open(mode: FileMode.write);
    await lockFile.lock(FileLock.blockingExclusive);

    try {
      if (Directory(await _nodeModulesPath).existsSync()) {
        if (_logger.isVerbose) {
          _logger.trace('prettier server is already installed.');
        }
        return;
      }

      _logger.stdout('Installing prettier server...');
      await runProcess('npm', ['ci'], workingDirectory: await _serverPath);
      _logger.stdout('prettier server installed.');
    } finally {
      await lockFile.unlock();
      await lockFile.close();
    }
  }

  /// Starts the server process and completes when it is ready.
  Future<void> start() async {
    await installPrettierServer();

    if (_logger.isVerbose) {
      _logger.trace('Starting prettier server...');
    }

    _process = await Process.start('node', [
      await _serverEntrypoint,
    ], workingDirectory: await _serverPath);

    final readyCompleter = Completer<void>();

    final stdoutLines = const LineSplitter().bind(
      utf8.decoder.bind(_process!.stdout),
    );
    final stderrLines = const LineSplitter().bind(
      utf8.decoder.bind(_process!.stderr),
    );

    stdoutLines.listen((line) {
      if (!readyCompleter.isCompleted) {
        // The first line is some JSON containing the port number.
        final message = jsonDecode(line) as Map<String, Object?>;
        _port = message['port']! as int;
        // The NodeJS server seems to be unable to accept many concurrent
        // connections (~ >80), so we limit it to something below that.
        _client = IOClient(HttpClient()..maxConnectionsPerHost = 40);
        readyCompleter.complete();
      } else {
        if (_logger.isVerbose) {
          _logger.trace('[prettier server] $line');
        }
      }
    });

    stderrLines.listen((line) {
      if (_logger.isVerbose) {
        _logger.trace('[prettier server] $line');
      }
    });

    if (_logger.isVerbose) {
      // ignore: unawaited_futures
      _process!.exitCode.then(
        (exitCode) =>
            _logger.trace('prettier server exited with code $exitCode'),
      );
    }

    await Future.any([
      // ignore: void_checks
      _process!.exitCode.then((exitCode) {
        throw Exception('prettier server exited with exit code $exitCode.');
      }),
      readyCompleter.future,
    ]);

    if (_logger.isVerbose) {
      _logger.trace('prettier server is ready.');
    }
  }

  /// Stops the server process.
  Future<void> stop() async {
    if (_logger.isVerbose) {
      _logger.trace('Stopping prettier server.');
    }
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
      throw Exception('prettier server not started.');
    }

    final requestId = _nextRequestId++;
    _pendingRequests++;

    if (_logger.isVerbose) {
      _logger
        ..trace('prettier request #$requestId: pending')
        ..trace('prettier requests pending: $_pendingRequests');
    }

    Response response;
    try {
      response = await client.post(
        Uri.parse('http://localhost:$_port/format'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'source': source,
          'options': {
            'parser': parser,
            'printWidth': printWidth,
            'proseWrap': proseWrap.name,
          },
        }),
      );

      _pendingRequests--;

      if (_logger.isVerbose) {
        _logger
          ..trace('prettier request #$requestId: success')
          ..trace('prettier requests pending: $_pendingRequests');
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      _pendingRequests--;

      if (_logger.isVerbose) {
        _logger
          ..trace('prettier request #$requestId: error')
          ..trace('prettier requests pending: $_pendingRequests')
          ..trace(e.toString())
          ..trace('Source:')
          ..trace(source);
      }
      rethrow;
    }

    if (response.statusCode != 200) {
      throw Exception(
        'prettier server returned status code ${response.statusCode}.\n'
        '${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, Object?>;
    return body['result']! as String;
  }
}
