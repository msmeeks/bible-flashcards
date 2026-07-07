import 'package:flutter/material.dart';

class AppSettings {
  // Sentinel for copyWith to distinguish "omitted" from "explicit null"
  // on the nullable dailyNotificationTime field.
  static const Object _sentinel = Object();

  // UI displays these as "Verse-of-week probability" / its enabling switch —
  // names are intentionally unchanged here to avoid a pref-key migration.
  final bool audioInterruptEnabled;
  final double audioInterruptProbability; // default 0.5
  final int audioInterruptAfterMinutes; // default 60
  final String defaultTranslation; // "ESV"
  final String themeMode; // "system" | "light" | "dark"
  final TimeOfDay? dailyNotificationTime;
  final String notificationType; // 'verseOfWeek' | 'reviewVerse'
  final bool showOnLockScreen;
  final bool autoAdvanceVerseOfWeek; // default false
  final DateTime? lastVerseAdvanceDate;

  const AppSettings({
    this.audioInterruptEnabled = false,
    this.audioInterruptProbability = 0.5,
    this.audioInterruptAfterMinutes = 60,
    this.defaultTranslation = 'ESV',
    this.themeMode = 'system',
    this.dailyNotificationTime,
    this.notificationType = 'verseOfWeek',
    this.showOnLockScreen = false,
    this.autoAdvanceVerseOfWeek = false,
    this.lastVerseAdvanceDate,
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
    bool? autoAdvanceVerseOfWeek,
    DateTime? lastVerseAdvanceDate,
    bool clearLastVerseAdvanceDate = false,
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
      autoAdvanceVerseOfWeek:
          autoAdvanceVerseOfWeek ?? this.autoAdvanceVerseOfWeek,
      lastVerseAdvanceDate: clearLastVerseAdvanceDate
          ? null
          : (lastVerseAdvanceDate ?? this.lastVerseAdvanceDate),
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
      'auto_advance_verse_of_week': autoAdvanceVerseOfWeek,
      'last_verse_advance_date': lastVerseAdvanceDate?.toIso8601String(),
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    final hour = map['daily_notification_hour'] as int?;
    final minute = map['daily_notification_minute'] as int?;
    final time = (hour != null && minute != null)
        ? TimeOfDay(hour: hour, minute: minute)
        : null;

    final lastVerseAdvanceDate =
        _parseGuardedTimestamp(map['last_verse_advance_date'] as String?);

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
      autoAdvanceVerseOfWeek:
          map['auto_advance_verse_of_week'] as bool? ?? false,
      lastVerseAdvanceDate: lastVerseAdvanceDate,
    );
  }

  /// Parses an ISO-8601 timestamp, rejecting far-future values (tampered
  /// preference guard per security review).
  static DateTime? _parseGuardedTimestamp(String? raw) {
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    if (!parsed.isBefore(DateTime.now().add(const Duration(days: 365)))) {
      return null;
    }
    return parsed;
  }
}
