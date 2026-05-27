import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings.dart';

class SettingsProvider extends ChangeNotifier {
  AppSettings _settings = const AppSettings();

  AppSettings get settings => _settings;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _settings = AppSettings(
      audioReviewEnabled:
          prefs.getBool('audio_review_enabled') ?? false,
      audioInterruptEnabled:
          prefs.getBool('audio_interrupt_enabled') ?? false,
      audioInterruptProbability:
          prefs.getDouble('audio_interrupt_probability') ?? 0.5,
      audioInterruptAfterMinutes:
          prefs.getInt('audio_interrupt_after_minutes') ?? 60,
      defaultTranslation:
          prefs.getString('default_translation') ?? 'ESV',
      themeMode: prefs.getString('theme_mode') ?? 'system',
    );
    notifyListeners();
  }

  Future<void> update(AppSettings updated) async {
    _settings = updated;
    notifyListeners();
    await _persist(updated);
  }

  Future<void> _persist(AppSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audio_review_enabled', s.audioReviewEnabled);
    await prefs.setBool('audio_interrupt_enabled', s.audioInterruptEnabled);
    await prefs.setDouble(
        'audio_interrupt_probability', s.audioInterruptProbability);
    await prefs.setInt(
        'audio_interrupt_after_minutes', s.audioInterruptAfterMinutes);
    await prefs.setString('default_translation', s.defaultTranslation);
    await prefs.setString('theme_mode', s.themeMode);
  }
}
