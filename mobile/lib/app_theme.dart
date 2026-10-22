import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static final ValueNotifier<bool> isDark = ValueNotifier<bool>(true);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    isDark.value = prefs.getBool('dark_mode') ?? true;
  }

  static Future<void> setDark(bool value) async {
    isDark.value = value;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      'dark_mode',
      value,
    );
  }

  static Future<void> toggle() async {
    await setDark(!isDark.value);
  }
}