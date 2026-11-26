import 'dart:developer' as developer;

/// 极简日志。release 下静默，便于把语义分析的中间结果留在 debug 控制台。
class Log {
  const Log._();

  static bool verbose = false;

  static void d(String tag, Object? message) {
    if (!verbose) return;
    developer.log('$message', name: tag);
  }

  static void e(String tag, Object? error, [StackTrace? stack]) {
    developer.log('$error', name: tag, error: error, stackTrace: stack);
  }
}
