import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class AppLogger {
  static File? _logFile;
  static late Directory _logDir;

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 1,
      errorMethodCount: 5,
      lineLength: 100,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
    level: kReleaseMode ? Level.info : Level.debug,
    output: _DailyFileOutput(),
  );

  /// Initialize logger (call once in main())
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _logDir = Directory('${dir.path}/app_logs');

    if (!await _logDir.exists()) {
      await _logDir.create(recursive: true);
    }

    await _createTodayLogFile();
    await _deleteOldLogs();
  }

  /// Create today's log file
  static Future<void> _createTodayLogFile() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final file = File('${_logDir.path}/app_$today.log');

    if (!await file.exists()) {
      await file.create();
    }

    _logFile = file;
  }

  /// Delete logs older than 7 days
  static Future<void> _deleteOldLogs() async {
    final now = DateTime.now();

    final files = _logDir.listSync();

    for (var file in files) {
      if (file is File) {
        final stat = await file.stat();
        final difference = now.difference(stat.modified);

        if (difference.inDays > 7) {
          await file.delete();
        }
      }
    }
  }

  static void debug(dynamic message, [dynamic error, StackTrace? stack]) {
    _logger.d(message, error: error, stackTrace: stack);
  }

  static void info(dynamic message) {
    _logger.i(message);
  }

  static void warning(dynamic message) {
    _logger.w(message);
  }

  static void error(dynamic message, [dynamic error, StackTrace? stack]) {
    _logger.e(message, error: error, stackTrace: stack);
  }
}

/// Custom file output with daily rotation
class _DailyFileOutput extends LogOutput {
  @override
  void output(OutputEvent event) async {
    if (AppLogger._logFile == null) return;

    final logText =
        event.lines.map((e) => '[${DateTime.now()}] $e').join('\n');

    await AppLogger._logFile!
        .writeAsString('$logText\n', mode: FileMode.append);
  }
}
