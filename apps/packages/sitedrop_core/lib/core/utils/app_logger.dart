// lib/core/utils/app_logger.dart
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import 'file_log_output.dart';

/// App-wide logger. Prefer this over [print] (avoid_print lint).
///
/// Levels: [t] trace, [d] debug, [i] info, [w] warning, [e] error, [f] fatal.
///
/// Console always; durable file log (like Laravel `storage/logs/laravel.log`)
/// when [init] has been awaited on non-web platforms.
///
/// File location (after init):
/// - **Dev** (`flutter run` from app root): `logs/app.log` (e.g. `apps/buyer_app/logs/app.log`)
/// - **Installed app**: app support directory `/logs/app.log`
/// - **Web**: console only
class AppLogger {
  AppLogger._();

  static Logger? _logger;
  static bool _initialized = false;

  static Logger get _log {
    // Lazy console-only logger if [init] not called yet.
    return _logger ??= _buildLogger(fileOutput: null);
  }

  static Logger _buildLogger({FileLogOutput? fileOutput}) {
    final outputs = <LogOutput>[
      ConsoleOutput(),
      ?fileOutput,
    ];

    return Logger(
      // Silence noisy logs in release; keep warnings+.
      level: kReleaseMode ? Level.warning : Level.debug,
      filter: ProductionFilter(),
      printer: _LaravelStylePrinter(
        colors: !kReleaseMode && !kIsWeb,
        printEmojis: !kReleaseMode,
      ),
      output: MultiOutput(outputs),
    );
  }

  /// Call once from [main] before other logging when possible.
  /// Enables `logs/app.log` (non-web).
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final fileOut = await FileLogOutput.create();
    _logger = _buildLogger(fileOutput: fileOut);

    if (fileOut != null && FileLogOutput.logFilePath != null) {
      _log.i('File log: ${FileLogOutput.logFilePath}');
    } else if (kIsWeb) {
      _log.i('File log disabled on web (console only)');
    } else {
      _log.w('File log unavailable — console only');
    }
  }

  /// Absolute path to `app.log` if file logging is active.
  static String? get logFilePath => FileLogOutput.logFilePath;

  static String? get logDirectoryPath => FileLogOutput.logDirectoryPath;

  static void t(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log.t(message, time: time, error: error, stackTrace: stackTrace);
  }

  static void d(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log.d(message, time: time, error: error, stackTrace: stackTrace);
  }

  static void i(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log.i(message, time: time, error: error, stackTrace: stackTrace);
  }

  static void w(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log.w(message, time: time, error: error, stackTrace: stackTrace);
  }

  static void e(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log.e(message, time: time, error: error, stackTrace: stackTrace);
  }

  static void f(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log.f(message, time: time, error: error, stackTrace: stackTrace);
  }
}

/// Single-line format similar to Laravel:
/// `[2026-07-13 07:06:36] local.INFO: message`
class _LaravelStylePrinter extends LogPrinter {
  _LaravelStylePrinter({
    this.colors = true,
    this.printEmojis = true,
  });

  final bool colors;
  final bool printEmojis;

  static final _levelNames = <Level, String>{
    Level.trace: 'DEBUG',
    Level.debug: 'DEBUG',
    Level.info: 'INFO',
    Level.warning: 'WARNING',
    Level.error: 'ERROR',
    Level.fatal: 'CRITICAL',
  };

  static final _levelColors = <Level, AnsiColor>{
    Level.trace: const AnsiColor.fg(8),
    Level.debug: const AnsiColor.fg(12),
    Level.info: const AnsiColor.fg(10),
    Level.warning: const AnsiColor.fg(208),
    Level.error: const AnsiColor.fg(196),
    Level.fatal: const AnsiColor.fg(199),
  };

  @override
  List<String> log(LogEvent event) {
    final time = event.time;
    final stamp =
        '${time.year.toString().padLeft(4, '0')}-'
        '${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';

    final env = kReleaseMode ? 'production' : 'local';
    final levelName = _levelNames[event.level] ?? event.level.name.toUpperCase();
    final emoji = printEmojis ? _emoji(event.level) : '';
    final prefix = '[$stamp] $env.$levelName: $emoji';

    final msg = event.message.toString();
    final lines = <String>['$prefix$msg'];

    if (event.error != null) {
      lines.add('$prefix${event.error}');
    }
    if (event.stackTrace != null) {
      for (final line in event.stackTrace.toString().split('\n')) {
        if (line.trim().isEmpty) continue;
        lines.add('$prefix$line');
      }
    }

    if (!colors) return lines;
    final color = _levelColors[event.level] ?? const AnsiColor.none();
    return lines.map((line) => color(line)).toList();
  }

  String _emoji(Level level) {
    switch (level) {
      case Level.trace:
      case Level.debug:
        return '';
      case Level.info:
        return '';
      case Level.warning:
        return '⚠ ';
      case Level.error:
      case Level.fatal:
        return '❌ ';
      default:
        return '';
    }
  }
}
