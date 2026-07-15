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
  tz.TZDateTime? scheduledDate;

  final List<AndroidNotificationChannel> channels =
      <AndroidNotificationChannel>[];

  @override
  Future<bool> initialize({
    required AndroidInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async {
    calls.add('initialize');
    return true;
  }

  @override
  Future<void> createNotificationChannel(
    AndroidNotificationChannel notificationChannel,
  ) async {
    calls.add('createNotificationChannel');
    channels.add(notificationChannel);
  }

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
    this.scheduledDate = scheduledDate;
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

  group('initialize', () {
    // The real channel would return the host's zone, making the assertions
    // below depend on where the suite runs.
    void mockHostTimezone(String zoneName) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_timezone'),
        (call) async => call.method == 'getLocalTimezone' ? zoneName : null,
      );
    }

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('flutter_timezone'), null);
      tz.setLocalLocation(tz.UTC);
    });

    test('a valid host timezone becomes the local location', () async {
      mockHostTimezone('America/New_York');

      await NotificationService().initialize();

      expect(tz.local.name, 'America/New_York');
    });

    test('an unknown host timezone falls back to UTC rather than throwing',
        () async {
      mockHostTimezone('Mars/Olympus_Mons');

      await NotificationService().initialize();

      expect(tz.local, tz.UTC);
    });

    test('creates both the audio and daily reminder channels', () async {
      mockHostTimezone('UTC');

      await NotificationService().initialize();

      expect(
        fake.channels.map((c) => c.id),
        containsAll(<String>['bible_flashcards_audio', 'bible_flashcards_daily']),
      );
    });
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

    test('the default verse-of-week body stays generic too', () async {
      await NotificationService()
          .scheduleDailyNotification(const TimeOfDay(hour: 9, minute: 0));

      expect(fake.scheduledBody, 'Time to review your verse of the week');
    });
  });

  group('scheduleDailyNotification midnight rollover', () {
    // Pinned so the branch under test is decided by the test, not by the
    // wall-clock time the suite happens to run at. Resolved lazily — the
    // timezone database is only loaded by setUpAll.
    tz.Location newYork() => tz.getLocation('America/New_York');

    test('a time already past today schedules tomorrow', () async {
      final service = NotificationService(
        now: () => tz.TZDateTime(newYork(), 2026, 7, 15, 10, 30),
      );

      await service.scheduleDailyNotification(const TimeOfDay(hour: 9, minute: 0));

      expect(fake.scheduledDate, tz.TZDateTime(newYork(), 2026, 7, 16, 9, 0));
    });

    test('a time still ahead today schedules today', () async {
      final service = NotificationService(
        now: () => tz.TZDateTime(newYork(), 2026, 7, 15, 10, 30),
      );

      await service.scheduleDailyNotification(
        const TimeOfDay(hour: 21, minute: 15),
      );

      expect(fake.scheduledDate, tz.TZDateTime(newYork(), 2026, 7, 15, 21, 15));
    });

    test('the scheduled date carries the clock\'s zone, not a naive local time',
        () async {
      final service = NotificationService(
        now: () => tz.TZDateTime(newYork(), 2026, 7, 15, 10, 30),
      );

      await service.scheduleDailyNotification(
        const TimeOfDay(hour: 21, minute: 15),
      );

      expect(fake.scheduledDate!.location, newYork());
    });

    test('defaults to the real clock when no seam is supplied', () async {
      await NotificationService()
          .scheduleDailyNotification(const TimeOfDay(hour: 9, minute: 0));

      // Only assert the invariant that holds at any wall-clock time.
      expect(fake.scheduledDate!.isAfter(tz.TZDateTime.now(tz.local)), isTrue);
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

  group('NotificationService action dispatch', () {
    late NotificationService service;
    late List<String> fired;

    setUp(() {
      service = NotificationService();
      fired = <String>[];
      service.onAction = fired.add;
    });

    // The valid-action set stays private, so the ids are spelled out here
    // rather than imported — a test that read the production set would pass
    // even if that set were wrong.
    for (final action in ['pause', 'stop', 'play', 'dismiss']) {
      test('the "$action" action fires onAction', () {
        service.debugHandleResponse(
          NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: action,
          ),
        );

        expect(fired, [action]);
      });
    }

    test('an unrecognized action id does not fire onAction', () {
      service.debugHandleResponse(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'launch_rockets',
        ),
      );

      expect(fired, isEmpty);
    });

    test('a null action id does not fire onAction', () {
      service.debugHandleResponse(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          actionId: null,
        ),
      );

      expect(fired, isEmpty);
    });

    test('a valid action with no callback assigned does not throw', () {
      service.onAction = null;

      expect(
        () => service.debugHandleResponse(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: 'play',
          ),
        ),
        returnsNormally,
      );
    });
  });
}
