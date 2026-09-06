import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color accent = Color(0xFF23A8F2);
  static const Color darkBackground = Color(0xFF111318);
  static const Color darkSurface = Color(0xFF181B22);
  static const Color darkPanel = Color(0xFF20242C);

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: darkSurface,
    ),
    scaffoldBackgroundColor: darkBackground,
    dividerColor: const Color(0xFF303640),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      border: OutlineInputBorder(),
    ),
    visualDensity: VisualDensity.compact,
    useMaterial3: true,
  );

  static ThemeData get light => ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(seedColor: accent),
    scaffoldBackgroundColor: const Color(0xFFF6F7F9),
    dividerColor: const Color(0xFFD9DCE2),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      border: OutlineInputBorder(),
    ),
    visualDensity: VisualDensity.compact,
    useMaterial3: true,
  );
}
