import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Simple structured logger with info, warning, and error levels.
class Logger {
  const Logger._();

  static String _formatMessage(String tag, String message) {
    final timestamp = DateTime.now().toIso8601String();
    return '[$timestamp][$tag] $message';
  }

  /// Logs an informational message.
  static void i(String tag, String message) {
    final formatted = _formatMessage(tag, message);
    debugPrint(formatted);
    developer.log(formatted, name: tag, level: 800);
  }

  /// Logs a warning message.
  static void w(String tag, String message) {
    final formatted = _formatMessage(tag, message);
    debugPrint(formatted);
    developer.log(formatted, name: tag, level: 900);
  }

  /// Logs an error message with optional error and stack trace details.
  static void e(String tag, String message, [Object? error, StackTrace? stack]) {
    final formatted = _formatMessage(tag, message);
    if (error != null) {
      debugPrint('$formatted | error=$error');
    } else {
      debugPrint(formatted);
    }
    developer.log(
      formatted,
      name: tag,
      level: 1000,
      error: error,
      stackTrace: stack,
    );
  }
}
