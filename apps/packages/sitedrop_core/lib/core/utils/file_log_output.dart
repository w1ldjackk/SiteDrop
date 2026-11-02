// lib/core/utils/file_log_output.dart
// Laravel-style append-only log file (mirrors storage/logs/laravel.log).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

/// Writes plain-text lines to [logFilePath], with simple size rotation.
///
/// **Not used on web** (no durable local file path the user can open).
class FileLogOutput extends LogOutput {
  FileLogOutput._(this._file);

  final File _file;
  final StreamController<String> _writeQueue = StreamController<String>();
  StreamSubscription<void>? _sub;
  bool _ready = false;

  static const String fileName = 'app.log';
  static const String dirName = 'logs';
  static const int maxBytes = 5 * 1024 * 1024; // 5 MB
  static const int keepRotated = 5;

  /// Absolute path once [create] succeeds; null on web / failure.
  static String? logFilePath;

  /// Directory containing the log file.
  static String? logDirectoryPath;

  static FileLogOutput? _instance;

  /// Prepare log directory + file. Safe to call once from [AppLogger.init].
  static Future<FileLogOutput?> create() async {
    if (kIsWeb) {
      return null;
    }
    if (_instance != null) return _instance;

    try {
      final dir = await _resolveLogDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      if (!await file.exists()) {
        await file.create(recursive: true);
        await file.writeAsString(
          '# SiteDrop mobile log — ${DateTime.now().toIso8601String()}\n'
          '# Similar to Laravel storage/logs/laravel.log\n',
          mode: FileMode.writeOnly,
        );
      }

      logDirectoryPath = dir.path;
      logFilePath = file.path;

      final output = FileLogOutput._(file);
      await output._startWriter();
      _instance = output;
      return output;
    } catch (e, st) {
      debugPrint('FileLogOutput create failed: $e\n$st');
      return null;
    }
  }

  /// Prefer project `logs/` when running from the app root (flutter run),
  /// otherwise application support directory (installed builds).
  static Future<Directory> _resolveLogDirectory() async {
    try {
      final cwd = Directory.current;
      final pubspec = File('${cwd.path}${Platform.pathSeparator}pubspec.yaml');
      if (await pubspec.exists()) {
        final content = await pubspec.readAsString();
        // Local `flutter run` from any Flutter package root under apps/.
        if (content.contains('name: sitedrop_buyer') ||
            content.contains('name: sitedrop_seller') ||
            content.contains('name: sitedrop_driver') ||
            content.contains('name: sitedrop_mobile') || // test_app package name
            content.contains('\nflutter:')) {
          return Directory('${cwd.path}${Platform.pathSeparator}$dirName');
        }
      }
    } catch (_) {
      // fall through
    }

    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}${Platform.pathSeparator}$dirName');
  }

  Future<void> _startWriter() async {
    _sub = _writeQueue.stream.asyncMap(_appendLine).listen(
      (_) {},
      onError: (Object e, StackTrace st) {
        debugPrint('FileLogOutput write error: $e\n$st');
      },
    );
    _ready = true;
  }

  Future<void> _appendLine(String line) async {
    try {
      await _rotateIfNeeded();
      await _file.writeAsString(
        line.endsWith('\n') ? line : '$line\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      debugPrint('FileLogOutput append failed: $e');
    }
  }

  Future<void> _rotateIfNeeded() async {
    if (!await _file.exists()) return;
    final len = await _file.length();
    if (len < maxBytes) return;

    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final rotated = File(
      '${_file.parent.path}${Platform.pathSeparator}app-$stamp.log',
    );
    await _file.rename(rotated.path);
    await _file.create(recursive: true);
    await _file.writeAsString(
      '# Rotated from app.log at ${DateTime.now().toIso8601String()}\n',
    );

    final logs = _file.parent
        .listSync()
        .whereType<File>()
        .where((f) {
          final name = f.uri.pathSegments.last;
          return name.startsWith('app-') && name.endsWith('.log');
        })
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));

    for (var i = keepRotated; i < logs.length; i++) {
      try {
        await logs[i].delete();
      } catch (_) {}
    }
  }

  @override
  void output(OutputEvent event) {
    if (!_ready) return;
    for (final line in event.lines) {
      // Strip ANSI color codes for a clean file like laravel.log
      final plain = line.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
      if (plain.trim().isEmpty) continue;
      if (!_writeQueue.isClosed) {
        _writeQueue.add(plain);
      }
    }
  }

  @override
  Future<void> destroy() async {
    await _sub?.cancel();
    if (!_writeQueue.isClosed) {
      await _writeQueue.close();
    }
    _ready = false;
  }

  /// Read the tail of the log (debug / support UI).
  static Future<String> readTail({int maxBytes = 64 * 1024}) async {
    final path = logFilePath;
    if (path == null) return '';
    final file = File(path);
    if (!await file.exists()) return '';
    final length = await file.length();
    final raf = await file.open();
    try {
      final start = length > maxBytes ? length - maxBytes : 0;
      await raf.setPosition(start);
      final bytes = await raf.read(length - start);
      return utf8.decode(bytes, allowMalformed: true);
    } finally {
      await raf.close();
    }
  }
}
