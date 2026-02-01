import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  static File? _logFile;

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
    output: _FileLogOutput(),
  );

  /// Initialize logger (call once in main())
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${dir.path}/app_logs');

    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    _logFile = File('${logDir.path}/app.log');

    if (!await _logFile!.exists()) {
      await _logFile!.create();
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

/// Custom file output
class _FileLogOutput extends LogOutput {
  @override
  void output(OutputEvent event) async {
    // Still print to console
    for (var line in event.lines) {
      // ignore: avoid_print
      print(line);
    }

    if (AppLogger._logFile == null) return;

    final logText =
        event.lines.map((e) => '[${DateTime.now()}] $e').join('\n');

    await AppLogger._logFile!
        .writeAsString('$logText\n', mode: FileMode.append);
  }
}
