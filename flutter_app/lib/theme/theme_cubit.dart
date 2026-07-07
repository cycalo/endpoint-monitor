import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists user choice: system, light, or dark.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.dark);

  static const _key = 'em_theme_mode';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final mode = _parse(p.getString(_key));
    if (mode == ThemeMode.system) {
      await setTheme(ThemeMode.dark);
    } else {
      emit(mode);
    }
  }

  ThemeMode _parse(String? v) => switch (v) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };

  Future<void> setTheme(ThemeMode mode) async {
    emit(mode);
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _key,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
  }
}
