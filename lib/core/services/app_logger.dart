import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Lightweight file-backed logger for production diagnostics.
///
/// Writes timestamped lines to a single rotating log file in app documents
/// (`logs/yomi.log`, with a one-generation `.bak` rotation past [_maxBytes]).
/// Logging never throws — failures here are swallowed so a broken log write
/// can never crash the feature that triggered it.
class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  static const _maxBytes = 1 * 1024 * 1024; // 1 MB before rotation

  File? _file;

  Future<File> _ensureFile() async {
    final cached = _file;
    if (cached != null) return cached;
    final dir = await getApplicationDocumentsDirectory();
    final logsDir = Directory('${dir.path}/logs');
    if (!await logsDir.exists()) await logsDir.create(recursive: true);
    final file = File('${logsDir.path}/yomi.log');
    _file = file;
    return file;
  }

  Future<void> _write(
    String level,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) async {
    try {
      final file = await _ensureFile();
      if (await file.exists() && await file.length() > _maxBytes) {
        final backup = File('${file.path}.bak');
        if (await backup.exists()) await backup.delete();
        await file.rename(backup.path);
      }
      final buffer = StringBuffer()
        ..write('[${DateTime.now().toIso8601String()}] ')
        ..write('${level.padRight(5)} ')
        ..write(message);
      if (error != null) buffer.write(' | $error');
      if (stack != null) buffer.write('\n$stack');
      buffer.write('\n');
      await File(file.path)
          .writeAsString(buffer.toString(), mode: FileMode.append, flush: true);
    } catch (_) {
      // Logging must never throw — there's nowhere left to report it.
    }
  }

  void info(String message) => unawaited(_write('INFO', message));

  void warn(String message, [Object? error, StackTrace? stack]) =>
      unawaited(_write('WARN', message, error, stack));

  void error(String message, [Object? error, StackTrace? stack]) =>
      unawaited(_write('ERROR', message, error, stack));

  /// Full log contents (oldest rotated generation first, if present).
  Future<String> readAll() async {
    try {
      final file = await _ensureFile();
      final backup = File('${file.path}.bak');
      final old = await backup.exists() ? await backup.readAsString() : '';
      final current = await file.exists() ? await file.readAsString() : '';
      if (old.isEmpty) return current;
      if (current.isEmpty) return old;
      return '$old\n$current';
    } catch (e) {
      return 'Failed to read log file: $e';
    }
  }

  Future<void> clear() async {
    try {
      final file = await _ensureFile();
      if (await file.exists()) await file.delete();
      final backup = File('${file.path}.bak');
      if (await backup.exists()) await backup.delete();
    } catch (_) {}
  }
}
