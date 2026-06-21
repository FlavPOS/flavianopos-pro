import 'package:flutter/material.dart';
import '../models/settings_model.dart';

class ThemeNotifier extends ChangeNotifier {
  static final ThemeNotifier instance = ThemeNotifier._();
  ThemeNotifier._();

  bool get isDark => AppSettings.darkMode;

  ThemeMode get themeMode => AppSettings.darkMode ? ThemeMode.dark : ThemeMode.light;

  void toggle() {
    AppSettings.darkMode = !AppSettings.darkMode;
    AppSettings.save('darkMode', AppSettings.darkMode);
    notifyListeners();
  }

  void setDark(bool value) {
    if (AppSettings.darkMode == value) return;
    AppSettings.darkMode = value;
    AppSettings.save('darkMode', value);
    notifyListeners();
  }
}
