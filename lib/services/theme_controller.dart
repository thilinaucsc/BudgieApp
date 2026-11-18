import 'package:flutter/material.dart';
import '../db/database_helper.dart';

class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.system);
  static final ThemeController instance = ThemeController._();

  static const _settingKey = 'theme_mode';

  Future<void> load() async {
    try {
      final name =
          await DatabaseHelper.instance.getSetting(_settingKey, 'system');
      value = ThemeMode.values.firstWhere(
        (m) => m.name == name,
        orElse: () => ThemeMode.system,
      );
    } catch (e) {
      debugPrint('ThemeController.load: $e');
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    value = mode;
    await DatabaseHelper.instance.setSetting(_settingKey, mode.name);
  }
}
