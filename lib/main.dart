import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/errors/app_error_reporter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  FlutterError.onError = AppErrorReporter.recordFlutterError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppErrorReporter.record(error, stack);
    return true;
  };

  runApp(const MVCodeApp());
}
