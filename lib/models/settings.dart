import 'package:flutter/material.dart';

class AppSettings {
  // Sentinel for copyWith to distinguish "omitted" from "explicit null"
  // on the nullable dailyNotificationTime field.
  static const Object _sentinel = Object();

  final bool audioInterruptEnabled;
  final double audioInterruptProbability; // default 0.5
  final int audioInterruptAfterMinutes; // default 60
  final String defaultTranslation; // "ESV"
  final String themeMode; // "system" | "light" | "dark"
  final TimeOfDay? dailyNotificationTime;
  final String notificationType; // 'verseOfWeek' | 'reviewVerse'
  final bool showOnLockScreen;
  final bool driveBackupEnabled; // opt-in only, default false
  final String backupCadence; // "daily" | "weekly" | "monthly"
  final DateTime? lastBackupAt;
  // Consent record persisted for audit; null = not yet consented
  final String? driveConsentAt; // ISO-8601
  final int driveConsentVersion; // disclosure version shown at consent time

  const AppSettings({
    this.audioInterruptEnabled = false,
    this.audioInterruptProbability = 0.5,
    this.audioInterruptAfterMinutes = 60,
    this.defaultTranslation = 'ESV',
    this.themeMode = 'system',
    this.dailyNotificationTime,
    this.notificationType = 'verseOfWeek',
    this.showOnLockScreen = false,
    this.driveBackupEnabled = false,
    this.backupCadence = 'weekly',
    this.lastBackupAt,
    this.driveConsentAt,
    this.driveConsentVersion = 0,
  });

  AppSettings copyWith({
    bool? audioInterruptEnabled,
    double? audioInterruptProbability,
    int? audioInterruptAfterMinutes,
    String? defaultTranslation,
    String? themeMode,
    Object? dailyNotificationTime = _sentinel,
    String? notificationType,
    bool? showOnLockScreen,
    bool? driveBackupEnabled,
    String? backupCadence,
    DateTime? lastBackupAt,
    bool clearLastBackupAt = false,
    String? driveConsentAt,
    int? driveConsentVersion,
  }) {
    return AppSettings(
      audioInterruptEnabled:
          audioInterruptEnabled ?? this.audioInterruptEnabled,
      audioInterruptProbability:
          audioInterruptProbability ?? this.audioInterruptProbability,
      audioInterruptAfterMinutes:
          audioInterruptAfterMinutes ?? this.audioInterruptAfterMinutes,
      defaultTranslation: defaultTranslation ?? this.defaultTranslation,
      themeMode: themeMode ?? this.themeMode,
      dailyNotificationTime: identical(dailyNotificationTime, _sentinel)
          ? this.dailyNotificationTime
          : dailyNotificationTime as TimeOfDay?,
      notificationType: notificationType ?? this.notificationType,
      showOnLockScreen: showOnLockScreen ?? this.showOnLockScreen,
      driveBackupEnabled: driveBackupEnabled ?? this.driveBackupEnabled,
      backupCadence: backupCadence ?? this.backupCadence,
      lastBackupAt:
          clearLastBackupAt ? null : (lastBackupAt ?? this.lastBackupAt),
      driveConsentAt: driveConsentAt ?? this.driveConsentAt,
      driveConsentVersion: driveConsentVersion ?? this.driveConsentVersion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'audio_interrupt_enabled': audioInterruptEnabled,
      'audio_interrupt_probability': audioInterruptProbability,
      'audio_interrupt_after_minutes': audioInterruptAfterMinutes,
      'default_translation': defaultTranslation,
      'theme_mode': themeMode,
      'daily_notification_hour': dailyNotificationTime?.hour,
      'daily_notification_minute': dailyNotificationTime?.minute,
      'notification_type': notificationType,
      'show_on_lock_screen': showOnLockScreen,
      'drive_backup_enabled': driveBackupEnabled,
      'backup_cadence': backupCadence,
      'last_backup_at': lastBackupAt?.toIso8601String(),
      'drive_consent_at': driveConsentAt,
      'drive_consent_version': driveConsentVersion,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    final hour = map['daily_notification_hour'] as int?;
    final minute = map['daily_notification_minute'] as int?;
    final time = (hour != null && minute != null)
        ? TimeOfDay(hour: hour, minute: minute)
        : null;

    final lastBackupRaw = map['last_backup_at'] as String?;
    DateTime? lastBackupAt;
    if (lastBackupRaw != null) {
      final parsed = DateTime.tryParse(lastBackupRaw);
      // Reject far-future timestamps (tampered preference guard per security review)
      if (parsed != null &&
          parsed.isBefore(DateTime.now().add(const Duration(days: 365)))) {
        lastBackupAt = parsed;
      }
    }

    final cadenceRaw = map['backup_cadence'] as String? ?? 'weekly';
    const validCadences = {'daily', 'weekly', 'monthly'};
    final backupCadence =
        validCadences.contains(cadenceRaw) ? cadenceRaw : 'weekly';

    return AppSettings(
      audioInterruptEnabled: map['audio_interrupt_enabled'] as bool? ?? false,
      audioInterruptProbability:
          ((map['audio_interrupt_probability'] as num?)?.toDouble() ?? 0.5)
              .clamp(0.0, 1.0),
      audioInterruptAfterMinutes:
          map['audio_interrupt_after_minutes'] as int? ?? 60,
      defaultTranslation: () {
        const validTranslations = {'BSB', 'KJV', 'WEB', 'ESV'};
        final raw = map['default_translation'] as String? ?? 'ESV';
        return validTranslations.contains(raw) ? raw : 'ESV';
      }(),
      themeMode: map['theme_mode'] as String? ?? 'system',
      dailyNotificationTime: time,
      notificationType: map['notification_type'] as String? ?? 'verseOfWeek',
      showOnLockScreen: map['show_on_lock_screen'] as bool? ?? false,
      driveBackupEnabled: map['drive_backup_enabled'] as bool? ?? false,
      backupCadence: backupCadence,
      lastBackupAt: lastBackupAt,
      driveConsentAt: map['drive_consent_at'] as String?,
      driveConsentVersion: map['drive_consent_version'] as int? ?? 0,
    );
  }
}
