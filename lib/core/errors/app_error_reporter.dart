import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

final class AppErrorReporter {
  AppErrorReporter._();

  static final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  static void recordFlutterError(FlutterErrorDetails details) {
    FlutterError.presentError(details);
    record(details.exception, details.stack ?? StackTrace.current);
  }

  static void record(Object error, StackTrace stack) {
    developer.log(
      'Falha capturada pelo MV Code',
      name: 'mv_code',
      error: error,
      stackTrace: stack,
    );
    lastError.value = error.toString();
  }

  static void clear() => lastError.value = null;
}
