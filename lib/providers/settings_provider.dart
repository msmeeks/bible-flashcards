import 'package:flutter/foundation.dart';
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
      'drive_backup_enabled': prefs.getBool('drive_backup_enabled'),
      'backup_cadence': prefs.getString('backup_cadence'),
      'last_backup_at': prefs.getString('last_backup_at'),
      'drive_consent_at': prefs.getString('drive_consent_at'),
      'drive_consent_version': prefs.getInt('drive_consent_version'),
    });
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
    await prefs.setBool('drive_backup_enabled', s.driveBackupEnabled);
    await prefs.setString('backup_cadence', s.backupCadence);
    if (s.lastBackupAt != null) {
      await prefs.setString(
          'last_backup_at', s.lastBackupAt!.toIso8601String());
    } else {
      await prefs.remove('last_backup_at');
    }
    if (s.driveConsentAt != null) {
      await prefs.setString('drive_consent_at', s.driveConsentAt!);
    }
    await prefs.setInt('drive_consent_version', s.driveConsentVersion);
  }
}
