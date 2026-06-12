import 'package:flutter/material.dart';

class AppSettings {
  // Sentinel for copyWith to distinguish "omitted" from "explicit null"
  // on the nullable dailyNotificationTime field.
  static const Object _sentinel = Object();

  final bool audioReviewEnabled;
  final bool audioInterruptEnabled;
  final double audioInterruptProbability;
  final int audioInterruptAfterMinutes;
  final String defaultTranslation;
  final String themeMode;
  final TimeOfDay? dailyNotificationTime;
  final String notificationType; // 'verseOfWeek' | 'reviewVerse'
  final bool showOnLockScreen;

  const AppSettings({
    this.audioReviewEnabled = false,
    this.audioInterruptEnabled = false,
    this.audioInterruptProbability = 0.5,
    this.audioInterruptAfterMinutes = 60,
    this.defaultTranslation = 'ESV',
    this.themeMode = 'system',
    this.dailyNotificationTime,
    this.notificationType = 'verseOfWeek',
    this.showOnLockScreen = false,
  });

  AppSettings copyWith({
    bool? audioReviewEnabled,
    bool? audioInterruptEnabled,
    double? audioInterruptProbability,
    int? audioInterruptAfterMinutes,
    String? defaultTranslation,
    String? themeMode,
    Object? dailyNotificationTime = _sentinel,
    String? notificationType,
    bool? showOnLockScreen,
  }) {
    return AppSettings(
      audioReviewEnabled: audioReviewEnabled ?? this.audioReviewEnabled,
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'audio_review_enabled': audioReviewEnabled,
      'audio_interrupt_enabled': audioInterruptEnabled,
      'audio_interrupt_probability': audioInterruptProbability,
      'audio_interrupt_after_minutes': audioInterruptAfterMinutes,
      'default_translation': defaultTranslation,
      'theme_mode': themeMode,
      'daily_notification_hour': dailyNotificationTime?.hour,
      'daily_notification_minute': dailyNotificationTime?.minute,
      'notification_type': notificationType,
      'show_on_lock_screen': showOnLockScreen,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    final hour = map['daily_notification_hour'] as int?;
    final minute = map['daily_notification_minute'] as int?;
    final time = (hour != null && minute != null)
        ? TimeOfDay(hour: hour, minute: minute)
        : null;

    return AppSettings(
      audioReviewEnabled: map['audio_review_enabled'] as bool? ?? false,
      audioInterruptEnabled: map['audio_interrupt_enabled'] as bool? ?? false,
      audioInterruptProbability:
          (map['audio_interrupt_probability'] as num?)?.toDouble() ?? 0.5,
      audioInterruptAfterMinutes:
          map['audio_interrupt_after_minutes'] as int? ?? 60,
      defaultTranslation: map['default_translation'] as String? ?? 'ESV',
      themeMode: map['theme_mode'] as String? ?? 'system',
      dailyNotificationTime: time,
      notificationType:
          map['notification_type'] as String? ?? 'verseOfWeek',
      showOnLockScreen: map['show_on_lock_screen'] as bool? ?? false,
    );
  }
}
