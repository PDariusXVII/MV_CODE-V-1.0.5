import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  static const String _themeKey = 'settings.theme';
  static const String _fontSizeKey = 'settings.fontSize';
  static const String _tabSizeKey = 'settings.tabSize';
  static const String _wordWrapKey = 'settings.wordWrap';
  static const String _autoSaveKey = 'settings.autoSave';
  static const String _lineNumbersKey = 'settings.lineNumbers';

  ThemeMode _themeMode = ThemeMode.dark;
  double _fontSize = 14;
  int _tabSize = 2;
  bool _wordWrap = false;
  bool _autoSave = false;
  bool _lineNumbers = true;
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  double get fontSize => _fontSize;
  int get tabSize => _tabSize;
  bool get wordWrap => _wordWrap;
  bool get autoSave => _autoSave;
  bool get lineNumbers => _lineNumbers;
  bool get loaded => _loaded;

  Map<String, Object> get editorOptions => <String, Object>{
    'theme': _themeMode == ThemeMode.light ? 'mv-light' : 'mv-dark',
    'fontSize': _fontSize,
    'tabSize': _tabSize,
    'wordWrap': _wordWrap,
    'lineNumbers': _lineNumbers,
  };

  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _themeMode = switch (prefs.getString(_themeKey)) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    _fontSize = (prefs.getDouble(_fontSizeKey) ?? 14).clamp(11, 24).toDouble();
    _tabSize = (prefs.getInt(_tabSizeKey) ?? 2).clamp(2, 8).toInt();
    _wordWrap = prefs.getBool(_wordWrapKey) ?? false;
    _autoSave = prefs.getBool(_autoSaveKey) ?? false;
    _lineNumbers = prefs.getBool(_lineNumbersKey) ?? true;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    _themeMode = value;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, value.name);
  }

  Future<void> setFontSize(double value) async {
    _fontSize = value.clamp(11, 24).toDouble();
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, _fontSize);
  }

  Future<void> setTabSize(int value) async {
    _tabSize = value.clamp(2, 8).toInt();
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_tabSizeKey, _tabSize);
  }

  Future<void> setWordWrap(bool value) async {
    _wordWrap = value;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wordWrapKey, value);
  }

  Future<void> setAutoSave(bool value) async {
    _autoSave = value;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSaveKey, value);
  }

  Future<void> setLineNumbers(bool value) async {
    _lineNumbers = value;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lineNumbersKey, value);
  }
}
