import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:bible_flashcards/services/notification_service.dart';

/// Records what the platform was asked to do, and lets each test dictate the
/// permission answers. Subclassing the real Android implementation and swapping
/// it into [FlutterLocalNotificationsPlatform.instance] is what the plugin's own
/// `resolvePlatformSpecificImplementation` reads, so the service under test runs
/// unmodified — no native plugin registration required.
class _FakeAndroidPlugin extends AndroidFlutterLocalNotificationsPlugin {
  bool notificationsGranted = true;
  bool exactAlarmsGranted = true;
  bool notificationsThrows = false;

  final List<String> calls = <String>[];
  int scheduleCount = 0;
  String? scheduledBody;
  AndroidScheduleMode? scheduleMode;

  @override
  Future<bool?> requestNotificationsPermission() async {
    calls.add('requestNotificationsPermission');
    if (notificationsThrows) {
      throw PlatformException(code: 'permissionRequestInProgress');
    }
    return notificationsGranted;
  }

  @override
  Future<bool?> requestExactAlarmsPermission() async {
    calls.add('requestExactAlarmsPermission');
    return exactAlarmsGranted;
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    AndroidNotificationDetails? notificationDetails,
    required AndroidScheduleMode scheduleMode,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    calls.add('zonedSchedule');
    scheduleCount++;
    scheduledBody = body;
    this.scheduleMode = scheduleMode;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAndroidPlugin fake;

  setUpAll(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
  });

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    fake = _FakeAndroidPlugin();
    FlutterLocalNotificationsPlatform.instance = fake;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('scheduleDailyNotification permissions', () {
    test('returns notificationsDenied and does not schedule when the '
        'notification permission is refused', () async {
      fake.notificationsGranted = false;

      final result = await NotificationService()
          .scheduleDailyNotification(const TimeOfDay(hour: 9, minute: 0));

      expect(result, DailyReminderResult.notificationsDenied);
      expect(fake.scheduleCount, 0);
    });

    test('returns exactAlarmsDenied and does not schedule when exact alarms '
        'are refused', () async {
      fake.exactAlarmsGranted = false;

      final result = await NotificationService()
          .scheduleDailyNotification(const TimeOfDay(hour: 9, minute: 0));

      expect(result, DailyReminderResult.exactAlarmsDenied);
      expect(fake.scheduleCount, 0);
    });

    test('asks for the notification permission before exact alarms', () async {
      await NotificationService()
          .scheduleDailyNotification(const TimeOfDay(hour: 9, minute: 0));

      expect(fake.calls, [
        'requestNotificationsPermission',
        'requestExactAlarmsPermission',
        'zonedSchedule',
      ]);
    });

    test('treats a platform error from the permission request as denied',
        () async {
      fake.notificationsThrows = true;

      final result = await NotificationService()
          .scheduleDailyNotification(const TimeOfDay(hour: 9, minute: 0));

      expect(result, DailyReminderResult.notificationsDenied);
      expect(fake.scheduleCount, 0);
    });
  });

  group('scheduleDailyNotification scheduling', () {
    test('schedules once and reports scheduled when both permissions are '
        'granted', () async {
      final result = await NotificationService()
          .scheduleDailyNotification(const TimeOfDay(hour: 9, minute: 0));

      expect(result, DailyReminderResult.scheduled);
      expect(fake.scheduleCount, 1);
    });

    test('schedules with allow-while-idle so Doze does not defer it', () async {
      await NotificationService()
          .scheduleDailyNotification(const TimeOfDay(hour: 9, minute: 0));

      expect(fake.scheduleMode, AndroidScheduleMode.exactAllowWhileIdle);
    });

    test('body stays generic and carries no verse content', () async {
      await NotificationService().scheduleDailyNotification(
        const TimeOfDay(hour: 9, minute: 0),
        notificationType: 'reviewVerse',
      );

      expect(fake.scheduledBody, 'Time to practice a memorized verse');
    });
  });

  group('NotificationService onAction', () {
    test('onAction is null by default', () {
      final service = NotificationService();
      expect(service.onAction, isNull);
    });

    test('onAction can be set and replaced', () {
      final service = NotificationService();
      service.onAction = (_) {};
      expect(service.onAction, isNotNull);
      service.onAction = null;
      expect(service.onAction, isNull);
    });
  });
}
