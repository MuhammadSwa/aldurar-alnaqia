import 'package:flutter/foundation.dart';

void logInfo(Object message) {
  if (kDebugMode) debugPrint('[INFO] $message');
}

void logWarn(Object message) {
  if (kDebugMode) debugPrint('[WARN] $message');
}

void logError(Object message, [Object? error, StackTrace? stackTrace]) {
  if (kDebugMode) {
    debugPrint('[ERROR] $message');
    if (error != null) debugPrint('  error: $error');
    if (stackTrace != null) debugPrint(stackTrace.toString());
  }
}
