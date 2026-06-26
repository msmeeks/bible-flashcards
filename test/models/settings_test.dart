import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bible_flashcards/models/settings.dart';

void main() {
  group('AppSettings defaults', () {
    test('showOnLockScreen defaults to false', () {
      const s = AppSettings();
      expect(s.showOnLockScreen, isFalse);
    });

    test('notificationType defaults to verseOfWeek', () {
      const s = AppSettings();
      expect(s.notificationType, 'verseOfWeek');
    });

    test('dailyNotificationTime defaults to null', () {
      const s = AppSettings();
      expect(s.dailyNotificationTime, isNull);
    });
  });

  group('AppSettings.toMap', () {
    test('dailyNotificationTime non-null encodes hour and minute', () {
      const s = AppSettings(
        dailyNotificationTime: TimeOfDay(hour: 8, minute: 30),
      );
      final map = s.toMap();
      expect(map['daily_notification_hour'], 8);
      expect(map['daily_notification_minute'], 30);
    });

    test('dailyNotificationTime null encodes as null keys', () {
      const s = AppSettings();
      final map = s.toMap();
      expect(map['daily_notification_hour'], isNull);
      expect(map['daily_notification_minute'], isNull);
    });

    test('showOnLockScreen and notificationType present', () {
      const s = AppSettings(
        notificationType: 'reviewVerse',
        showOnLockScreen: true,
      );
      final map = s.toMap();
      expect(map['notification_type'], 'reviewVerse');
      expect(map['show_on_lock_screen'], isTrue);
    });

    test('showOnLockScreen false is encoded explicitly', () {
      const s = AppSettings(showOnLockScreen: false);
      final map = s.toMap();
      expect(map['show_on_lock_screen'], isFalse);
    });
  });

  group('AppSettings.fromMap', () {
    test('round-trip with all new fields set', () {
      const original = AppSettings(
        dailyNotificationTime: TimeOfDay(hour: 8, minute: 30),
        notificationType: 'reviewVerse',
        showOnLockScreen: true,
      );
      final restored = AppSettings.fromMap(original.toMap());
      expect(
          restored.dailyNotificationTime, const TimeOfDay(hour: 8, minute: 30));
      expect(restored.notificationType, 'reviewVerse');
      expect(restored.showOnLockScreen, isTrue);
    });

    test('missing hour and minute yields null dailyNotificationTime', () {
      final s = AppSettings.fromMap({'notification_type': 'verseOfWeek'});
      expect(s.dailyNotificationTime, isNull);
    });

    test('only hour present (no minute) yields null', () {
      final s = AppSettings.fromMap({'daily_notification_hour': 8});
      expect(s.dailyNotificationTime, isNull);
    });

    test('only minute present (no hour) yields null', () {
      final s = AppSettings.fromMap({'daily_notification_minute': 30});
      expect(s.dailyNotificationTime, isNull);
    });

    test('missing show_on_lock_screen defaults to false', () {
      final s = AppSettings.fromMap({});
      expect(s.showOnLockScreen, isFalse);
    });

    test('missing notification_type defaults to verseOfWeek', () {
      final s = AppSettings.fromMap({});
      expect(s.notificationType, 'verseOfWeek');
    });

    test('midnight boundary round-trips correctly', () {
      const original = AppSettings(
        dailyNotificationTime: TimeOfDay(hour: 0, minute: 0),
      );
      final restored = AppSettings.fromMap(original.toMap());
      expect(
          restored.dailyNotificationTime, const TimeOfDay(hour: 0, minute: 0));
    });

    test('end-of-day boundary round-trips correctly', () {
      const original = AppSettings(
        dailyNotificationTime: TimeOfDay(hour: 23, minute: 59),
      );
      final restored = AppSettings.fromMap(original.toMap());
      expect(restored.dailyNotificationTime,
          const TimeOfDay(hour: 23, minute: 59));
    });

    test('audioInterruptProbability above 1.0 is clamped to 1.0', () {
      final s = AppSettings.fromMap({'audio_interrupt_probability': 5.0});
      expect(s.audioInterruptProbability, 1.0);
    });

    test('audioInterruptProbability below 0.0 is clamped to 0.0', () {
      final s = AppSettings.fromMap({'audio_interrupt_probability': -1.0});
      expect(s.audioInterruptProbability, 0.0);
    });

    test('defaultTranslation accepts each allowed value', () {
      for (final t in ['BSB', 'KJV', 'WEB', 'ESV']) {
        final s = AppSettings.fromMap({'default_translation': t});
        expect(s.defaultTranslation, t);
      }
    });

    test('defaultTranslation falls back to ESV for unrecognized value', () {
      final s = AppSettings.fromMap({'default_translation': 'NIV'});
      expect(s.defaultTranslation, 'ESV');
    });

    test('missing default_translation defaults to ESV', () {
      final s = AppSettings.fromMap({});
      expect(s.defaultTranslation, 'ESV');
    });
  });

  group('AppSettings.copyWith', () {
    test('explicit null dailyNotificationTime overrides non-null', () {
      const original = AppSettings(
        dailyNotificationTime: TimeOfDay(hour: 9, minute: 0),
      );
      final updated = original.copyWith(dailyNotificationTime: null);
      expect(updated.dailyNotificationTime, isNull);
    });

    test('omitting dailyNotificationTime preserves existing value', () {
      const original = AppSettings(
        dailyNotificationTime: TimeOfDay(hour: 9, minute: 0),
      );
      final updated = original.copyWith(notificationType: 'reviewVerse');
      expect(
          updated.dailyNotificationTime, const TimeOfDay(hour: 9, minute: 0));
    });

    test('unset fields retain original values', () {
      const original = AppSettings(
        notificationType: 'reviewVerse',
        showOnLockScreen: true,
      );
      final updated = original.copyWith();
      expect(updated.notificationType, 'reviewVerse');
      expect(updated.showOnLockScreen, isTrue);
    });

    test('explicit showOnLockScreen true overrides default false', () {
      const original = AppSettings();
      final updated = original.copyWith(showOnLockScreen: true);
      expect(updated.showOnLockScreen, isTrue);
    });

    test('explicit notificationType reviewVerse overrides default', () {
      const original = AppSettings();
      final updated = original.copyWith(notificationType: 'reviewVerse');
      expect(updated.notificationType, 'reviewVerse');
    });
  });
}
