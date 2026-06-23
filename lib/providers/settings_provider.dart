import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings.dart';

class SettingsProvider extends ChangeNotifier {
  AppSettings _settings = const AppSettings();

  AppSettings get settings => _settings;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    // Delegate validation logic to AppSettings.fromMap to avoid duplication
    _settings = AppSettings.fromMap({
      'audio_review_enabled': prefs.getBool('audio_review_enabled'),
      'audio_interrupt_enabled': prefs.getBool('audio_interrupt_enabled'),
      'audio_interrupt_probability':
          prefs.getDouble('audio_interrupt_probability'),
      'audio_interrupt_after_minutes':
          prefs.getInt('audio_interrupt_after_minutes'),
      'default_translation': prefs.getString('default_translation'),
      'theme_mode': prefs.getString('theme_mode'),
      'daily_notification_hour': prefs.getInt('daily_notification_hour'),
      'daily_notification_minute': prefs.getInt('daily_notification_minute'),
      'notification_type': prefs.getString('notification_type'),
      'show_on_lock_screen': prefs.getBool('show_on_lock_screen'),
      'drive_backup_enabled': prefs.getBool('drive_backup_enabled'),
      'backup_cadence': prefs.getString('backup_cadence'),
      'last_backup_at': prefs.getString('last_backup_at'),
      'drive_consent_at': prefs.getString('drive_consent_at'),
      'drive_consent_version': prefs.getInt('drive_consent_version'),
    });
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

    await prefs.setBool('drive_backup_enabled', appSettings.driveBackupEnabled);
    await prefs.setString('backup_cadence', appSettings.backupCadence);
    if (appSettings.lastBackupAt != null) {
      await prefs.setString(
          'last_backup_at', appSettings.lastBackupAt!.toIso8601String());
    } else {
      await prefs.remove('last_backup_at');
    }
    if (appSettings.driveConsentAt != null) {
      await prefs.setString('drive_consent_at', appSettings.driveConsentAt!);
    }
    await prefs.setInt('drive_consent_version', appSettings.driveConsentVersion);
  }
}
