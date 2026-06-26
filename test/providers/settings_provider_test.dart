import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bible_flashcards/models/settings.dart';
import 'package:bible_flashcards/providers/settings_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsProvider.load', () {
    test('load with hour+minute yields correct TimeOfDay', () async {
      SharedPreferences.setMockInitialValues({
        'daily_notification_hour': 8,
        'daily_notification_minute': 30,
      });
      final provider = SettingsProvider();
      await provider.load();
      expect(
        provider.settings.dailyNotificationTime,
        const TimeOfDay(hour: 8, minute: 30),
      );
    });

    test('load with missing keys yields null dailyNotificationTime', () async {
      final provider = SettingsProvider();
      await provider.load();
      expect(provider.settings.dailyNotificationTime, isNull);
    });

    test('load with show_on_lock_screen true', () async {
      SharedPreferences.setMockInitialValues({'show_on_lock_screen': true});
      final provider = SettingsProvider();
      await provider.load();
      expect(provider.settings.showOnLockScreen, isTrue);
    });

    test('load with notification_type reviewVerse', () async {
      SharedPreferences.setMockInitialValues(
          {'notification_type': 'reviewVerse'});
      final provider = SettingsProvider();
      await provider.load();
      expect(provider.settings.notificationType, 'reviewVerse');
    });
  });

  group('SettingsProvider.update persistence', () {
    test('update with dailyNotificationTime persists hour and minute', () async {
      final provider = SettingsProvider();
      await provider.update(
        const AppSettings(
          dailyNotificationTime: TimeOfDay(hour: 9, minute: 15),
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('daily_notification_hour'), 9);
      expect(prefs.getInt('daily_notification_minute'), 15);
    });

    test('update with null dailyNotificationTime removes keys', () async {
      SharedPreferences.setMockInitialValues({
        'daily_notification_hour': 9,
        'daily_notification_minute': 15,
      });
      final provider = SettingsProvider();
      await provider.update(const AppSettings());
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('daily_notification_hour'), isNull);
      expect(prefs.getInt('daily_notification_minute'), isNull);
    });

    test('update persists showOnLockScreen true', () async {
      final provider = SettingsProvider();
      await provider.update(const AppSettings(showOnLockScreen: true));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('show_on_lock_screen'), isTrue);
    });

    test('update persists notificationType reviewVerse', () async {
      final provider = SettingsProvider();
      await provider.update(
        const AppSettings(notificationType: 'reviewVerse'),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('notification_type'), 'reviewVerse');
    });

    test('update persists showOnLockScreen false', () async {
      SharedPreferences.setMockInitialValues({'show_on_lock_screen': true});
      final provider = SettingsProvider();
      await provider.update(const AppSettings(showOnLockScreen: false));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('show_on_lock_screen'), isFalse);
    });
  });

  group('SettingsProvider listeners', () {
    test('load notifies listeners', () async {
      final provider = SettingsProvider();
      var callCount = 0;
      provider.addListener(() => callCount++);
      await provider.load();
      expect(callCount, 1);
    });

    test('update notifies listeners', () async {
      final provider = SettingsProvider();
      var callCount = 0;
      provider.addListener(() => callCount++);
      await provider.update(const AppSettings());
      expect(callCount, 1);
    });
  });

  group('SettingsProvider partial load', () {
    test('load with only hour key yields null dailyNotificationTime', () async {
      SharedPreferences.setMockInitialValues({'daily_notification_hour': 8});
      final provider = SettingsProvider();
      await provider.load();
      expect(provider.settings.dailyNotificationTime, isNull);
    });

    test('load with only minute key yields null dailyNotificationTime', () async {
      SharedPreferences.setMockInitialValues(
          {'daily_notification_minute': 30});
      final provider = SettingsProvider();
      await provider.load();
      expect(provider.settings.dailyNotificationTime, isNull);
    });
  });

  group('SettingsProvider round-trip', () {
    test('persist then reload preserves all new fields', () async {
      final provider1 = SettingsProvider();
      await provider1.update(
        const AppSettings(
          dailyNotificationTime: TimeOfDay(hour: 20, minute: 45),
          notificationType: 'reviewVerse',
          showOnLockScreen: true,
        ),
      );

      final provider2 = SettingsProvider();
      await provider2.load();
      expect(
        provider2.settings.dailyNotificationTime,
        const TimeOfDay(hour: 20, minute: 45),
      );
      expect(provider2.settings.notificationType, 'reviewVerse');
      expect(provider2.settings.showOnLockScreen, isTrue);
    });
  });

  group('SettingsProvider auto-advance verse of week persistence', () {
    test('update persists autoAdvanceVerseOfWeek and lastVerseAdvanceDate',
        () async {
      final provider = SettingsProvider();
      final date = DateTime(2026, 6, 21);
      await provider.update(
        AppSettings(
          autoAdvanceVerseOfWeek: true,
          lastVerseAdvanceDate: date,
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('auto_advance_verse_of_week'), isTrue);
      expect(
        prefs.getString('last_verse_advance_date'),
        date.toIso8601String(),
      );
    });

    test('update with null lastVerseAdvanceDate removes the key', () async {
      SharedPreferences.setMockInitialValues({
        'last_verse_advance_date': DateTime(2026, 6, 21).toIso8601String(),
      });
      final provider = SettingsProvider();
      await provider.update(const AppSettings());
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_verse_advance_date'), isNull);
    });

    test('load restores autoAdvanceVerseOfWeek and lastVerseAdvanceDate',
        () async {
      final date = DateTime(2026, 6, 21);
      SharedPreferences.setMockInitialValues({
        'auto_advance_verse_of_week': true,
        'last_verse_advance_date': date.toIso8601String(),
      });
      final provider = SettingsProvider();
      await provider.load();
      expect(provider.settings.autoAdvanceVerseOfWeek, isTrue);
      expect(provider.settings.lastVerseAdvanceDate, date);
    });
  });
}
