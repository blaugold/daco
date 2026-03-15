import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:path/path.dart' as p;

import 'logging.dart';
import 'utils.dart';

final _serverPath = packageRoot.then((dir) => p.join(dir, 'prettier-server'));
final _lockFilePath =
    _serverPath.then((dir) => p.join(dir, '.install-lock'));
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
    final serverEntrypoint = await _serverEntrypoint;
    if (File(serverEntrypoint).existsSync()) {
      if (_logger.isVerbose) {
        _logger.trace('prettier server is already installed.');
      }
      return;
    }

    // Use exclusive file creation as a lock. This is atomic on all platforms
    // and works correctly across isolates within the same process, unlike
    // fcntl-based file locks which are per-process on Linux.
    final lockFilePath = await _lockFilePath;
    bool acquiredLock;
    try {
      File(lockFilePath).createSync(exclusive: true);
      acquiredLock = true;
    } on FileSystemException {
      acquiredLock = false;
    }

    if (acquiredLock) {
      try {
        if (File(serverEntrypoint).existsSync()) {
          return;
        }

        _logger.stdout('Installing prettier server...');
        await runProcess('npm', ['ci'], workingDirectory: await _serverPath);
        _logger.stdout('prettier server installed.');
      } finally {
        try {
          File(lockFilePath).deleteSync();
        } catch (_) {}
      }
    } else {
      // Another isolate or process is already installing. Wait for it.
      if (_logger.isVerbose) {
        _logger.trace('Waiting for prettier server installation...');
      }
      final deadline = DateTime.now().add(const Duration(minutes: 2));
      while (!File(serverEntrypoint).existsSync()) {
        if (DateTime.now().isAfter(deadline)) {
          throw Exception(
            'Timed out waiting for prettier server installation.',
          );
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }
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
