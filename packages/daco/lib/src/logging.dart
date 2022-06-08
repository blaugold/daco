import 'package:cli_util/cli_logging.dart';

/// Extension for creating a [DacoLogger] from a [Logger].
extension ToDacoLoggerExtension on Logger {
  /// Creates a [DacoLogger] which delegates to this logger or returns this
  /// logger if it is already a [DacoLogger].
  DacoLogger toDacoLogger() {
    final self = this;
    if (self is DacoLogger) {
      return self;
    }
    return DacoLogger(this);
  }
}

/// A logger which encapsulates the formatting of the daco CLI.
class DacoLogger with _DelegateLogger {
  /// Creates a new [DacoLogger].
  DacoLogger(this._logger);

  @override
  final Logger _logger;
}

mixin _DelegateLogger implements Logger {
  Logger get _logger;

  @override
  Ansi get ansi => _logger.ansi;

  @override
  bool get isVerbose => _logger.isVerbose;

  @override
  void stdout(String message) => _logger.stdout(message);

  @override
  void stderr(String message) => _logger.stderr(message);

  @override
  void trace(String message) => _logger.trace(message);

  @override
  Progress progress(String message) => _logger.progress(message);

  @override
  void write(String message) => _logger.write(message);

  @override
  void writeCharCode(int charCode) => _logger.writeCharCode(charCode);

  @override
  // ignore: deprecated_member_use
  void flush() => _logger.flush();
}
