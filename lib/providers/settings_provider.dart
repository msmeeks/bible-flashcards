import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings.dart';

class SettingsProvider extends ChangeNotifier {
  AppSettings _settings = const AppSettings();

  AppSettings get settings => _settings;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('daily_notification_hour');
    final minute = prefs.getInt('daily_notification_minute');
    final time = (hour != null && minute != null)
        ? TimeOfDay(hour: hour, minute: minute)
        : null;

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
      dailyNotificationTime: time,
      notificationType:
          prefs.getString('notification_type') ?? 'verseOfWeek',
      showOnLockScreen: prefs.getBool('show_on_lock_screen') ?? false,
    );
    notifyListeners();
  }

  Future<void> update(AppSettings updated, {String? announcement}) async {
    _settings = updated;
    notifyListeners();
    if (announcement != null) {
      // SemanticsService.announce is deprecated but no stable replacement exists
      // in Flutter 3.22; tracked upstream as flutter/flutter#126491.
      // ignore: deprecated_member_use
      SemanticsService.announce(announcement, TextDirection.ltr);
    }
    await _persist(updated);
  }

  Future<void> _persist(AppSettings appSettings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audio_review_enabled', appSettings.audioReviewEnabled);
    await prefs.setBool('audio_interrupt_enabled', appSettings.audioInterruptEnabled);
    await prefs.setDouble(
        'audio_interrupt_probability', appSettings.audioInterruptProbability);
    await prefs.setInt(
        'audio_interrupt_after_minutes', appSettings.audioInterruptAfterMinutes);
    await prefs.setString('default_translation', appSettings.defaultTranslation);
    await prefs.setString('theme_mode', appSettings.themeMode);
    await prefs.setString('notification_type', appSettings.notificationType);
    await prefs.setBool('show_on_lock_screen', appSettings.showOnLockScreen);

    final time = appSettings.dailyNotificationTime;
    if (time != null) {
      await prefs.setInt('daily_notification_hour', time.hour);
      await prefs.setInt('daily_notification_minute', time.minute);
    } else {
      await prefs.remove('daily_notification_hour');
      await prefs.remove('daily_notification_minute');
    }
  }
}
