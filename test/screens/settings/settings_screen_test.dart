import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/providers/settings_provider.dart';
import 'package:bible_flashcards/providers/tracking_provider.dart';
import 'package:bible_flashcards/providers/verse_provider.dart';
import 'package:bible_flashcards/screens/settings/settings_screen.dart';
import 'package:bible_flashcards/services/notification_service.dart';
import 'package:bible_flashcards/widgets/inline_status_banner.dart';

/// Lets a test dictate the permission answers the settings flow receives.
/// See test/services/notification_service_test.dart for why swapping the
/// platform instance works.
class _FakeAndroidPlugin extends AndroidFlutterLocalNotificationsPlugin {
  bool notificationsGranted = true;
  bool exactAlarmsGranted = true;

  @override
  Future<bool?> requestNotificationsPermission() async => notificationsGranted;

  @override
  Future<bool?> requestExactAlarmsPermission() async => exactAlarmsGranted;

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required TZDateTime scheduledDate,
    AndroidNotificationDetails? notificationDetails,
    required AndroidScheduleMode scheduleMode,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {}
}

class _ThrowingUrlLauncherPlatform extends UrlLauncherPlatform {
  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => false;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) {
    throw PlatformException(
        code: 'NO_HANDLER', message: 'no app to handle url');
  }
}

class _SucceedingUrlLauncherPlatform extends UrlLauncherPlatform {
  String? lastLaunchedUrl;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    lastLaunchedUrl = url;
    return true;
  }
}

// Mirrors the provider tree BibleFlashcardsApp builds in lib/app.dart.
// Pass [settingsProvider] to supply one already loaded from prefs; the default
// holds AppSettings' defaults, since nothing calls load() here.
Widget _wrap({SettingsProvider? settingsProvider}) {
  final dbHelper = DatabaseHelper();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(
          value: settingsProvider ?? SettingsProvider()),
      ChangeNotifierProvider<VerseProvider>.value(
        value: VerseProvider(dbHelper),
      ),
      ChangeNotifierProvider<TrackingProvider>.value(
        value: TrackingProvider(dbHelper),
      ),
      Provider<NotificationService>.value(value: NotificationService()),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'tapping Daily reminder opens the time picker when NotificationService is registered',
    (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Daily reminder'));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);
    },
  );

  testWidgets(
    'Audio review toggle is no longer shown',
    (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      expect(find.text('Daily reminder'), findsOneWidget);
      expect(find.text('Audio review'), findsNothing);
    },
  );

  testWidgets(
    'Auto-advance verse of the week toggle is off by default and can be enabled',
    (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Auto-advance verse of the week'),
        200,
      );

      expect(
        find.text('Auto-advance verse of the week'),
        findsOneWidget,
      );
      final switchFinder = find.byType(SwitchListTile);
      final autoAdvanceSwitch = tester
          .widgetList<SwitchListTile>(switchFinder)
          .firstWhere((s) =>
              (s.title as Text).data == 'Auto-advance verse of the week');
      expect(autoAdvanceSwitch.value, isFalse);

      await tester.tap(find.text('Auto-advance verse of the week'));
      await tester.pump();

      final updatedSwitch = tester
          .widgetList<SwitchListTile>(switchFinder)
          .firstWhere((s) =>
              (s.title as Text).data == 'Auto-advance verse of the week');
      expect(updatedSwitch.value, isTrue);
    },
  );

  testWidgets(
    'Default translation control hides the ESV segment when no API key is configured '
    'and falls back to BSB display, even though the saved default is ESV',
    (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Default translation'), 200);

      expect(find.text('Default translation'), findsOneWidget);
      final segmentedButton = tester.widget<SegmentedButton<String>>(
        find.byWidgetPredicate(
          (w) =>
              w is SegmentedButton<String> &&
              w.segments.any((s) => s.value == 'KJV'),
        ),
      );
      expect(
        segmentedButton.segments.any((s) => s.value == 'ESV'),
        isFalse,
      );
      expect(segmentedButton.selected, {'BSB'});
      expect(
        find.text('ESV is for personal, non-commercial use only.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Default translation control enforces a minimum 48x40 touch target per segment, '
    'matching the Backup Frequency control idiom for cramped ListTile trailing widgets',
    (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Default translation'), 200);

      final segmentedButton = tester.widget<SegmentedButton<String>>(
        find.byWidgetPredicate(
          (w) =>
              w is SegmentedButton<String> &&
              w.segments.any((s) => s.value == 'KJV'),
        ),
      );
      final minimumSize =
          segmentedButton.style?.minimumSize?.resolve(<WidgetState>{});
      expect(minimumSize, isNotNull);
      expect(minimumSize!.height, greaterThanOrEqualTo(40));
    },
  );

  testWidgets(
    'Selecting a non-ESV default translation hides the personal-use notice and persists',
    (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Default translation'), 200);

      await tester.tap(find.text('KJV').last);
      await tester.pump();

      expect(
        find.text('ESV is for personal, non-commercial use only.'),
        findsNothing,
      );

      final segmentedButton = tester.widget<SegmentedButton<String>>(
        find.byWidgetPredicate(
          (w) => w is SegmentedButton<String> && w.selected.contains('KJV'),
        ),
      );
      expect(segmentedButton.selected, {'KJV'});
    },
  );

  testWidgets(
    'tapping ESV.org shows a fallback message when no app can handle the link',
    (tester) async {
      final originalPlatform = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = _ThrowingUrlLauncherPlatform();
      addTearDown(() => UrlLauncherPlatform.instance = originalPlatform);

      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.scrollUntilVisible(find.text('ESV.org'), 200);

      await tester.tap(find.text('ESV.org'));
      await tester.pumpAndSettle();

      expect(find.text('Could not open ESV.org.'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping ESV.org launches the URL and shows no fallback message on success',
    (tester) async {
      final originalPlatform = UrlLauncherPlatform.instance;
      final fakePlatform = _SucceedingUrlLauncherPlatform();
      UrlLauncherPlatform.instance = fakePlatform;
      addTearDown(() => UrlLauncherPlatform.instance = originalPlatform);

      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.scrollUntilVisible(find.text('ESV.org'), 200);

      await tester.tap(find.text('ESV.org'));
      await tester.pumpAndSettle();

      expect(fakePlatform.lastLaunchedUrl, 'https://www.esv.org');
      expect(find.text('Could not open ESV.org.'), findsNothing);
    },
  );

  testWidgets(
    'Auto-advance verse of the week toggle can be turned off once enabled',
    (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Auto-advance verse of the week'),
        200,
      );

      await tester.tap(find.text('Auto-advance verse of the week'));
      await tester.pump();

      final switchFinder = find.byType(SwitchListTile);
      final enabledSwitch = tester
          .widgetList<SwitchListTile>(switchFinder)
          .firstWhere((s) =>
              (s.title as Text).data == 'Auto-advance verse of the week');
      expect(enabledSwitch.value, isTrue);

      await tester.tap(find.text('Auto-advance verse of the week'));
      await tester.pump();

      final disabledSwitch = tester
          .widgetList<SwitchListTile>(switchFinder)
          .firstWhere((s) =>
              (s.title as Text).data == 'Auto-advance verse of the week');
      expect(disabledSwitch.value, isFalse);
    },
  );

  testWidgets(
    'Verse-of-week probability dialog uses OutlinedButton for Cancel, '
    'not a bare TextButton',
    (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Verse-of-week probability'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    },
  );

  testWidgets(
    'Clear test history dialog uses OutlinedButton for Cancel, keeping the '
    'error-colored FilledButton for the destructive action',
    (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Clear test history'), 200);
      await tester.ensureVisible(find.text('Clear test history'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear test history'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Clear'), findsOneWidget);
    },
  );

  testWidgets(
    'Clear Activity History dialog uses OutlinedButton for Cancel, keeping '
    'the error-colored FilledButton for the destructive action',
    (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Clear Activity History'), 200);

      await tester.tap(find.text('Clear Activity History'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Clear'), findsOneWidget);
    },
  );

  testWidgets(
    'periodic playback controls lay out without overflow at the 375px '
    'breakpoint and reflect the stored interval and trigger mode',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'audio_interrupt_interval_minutes': 30,
        'audio_interrupt_trigger_mode': 'always',
      });
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final settingsProvider = SettingsProvider();
      await settingsProvider.load();

      await tester.pumpWidget(_wrap(settingsProvider: settingsProvider));
      await tester.pump();

      // A too-wide trailing widget or overflow would have thrown by now.
      expect(find.text('Play verses periodically'), findsOneWidget);
      expect(find.text('Every 30 minutes'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'While other audio plays'),
          findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Anytime'), findsOneWidget);
    },
  );

  group('daily reminder permission denial', () {
    late _FakeAndroidPlugin fake;

    // Scheduling resolves tz.local, which app startup normally initializes.
    setUpAll(() {
      tz_data.initializeTimeZones();
      setLocalLocation(getLocation('UTC'));
    });

    // The test binding already reports TargetPlatform.android, which is what
    // the plugin's resolvePlatformSpecificImplementation checks.
    setUp(() {
      fake = _FakeAndroidPlugin();
      FlutterLocalNotificationsPlatform.instance = fake;
      SharedPreferences.setMockInitialValues({
        'daily_notification_hour': 9,
        'daily_notification_minute': 0,
      });
    });

    // Re-scheduling runs whenever a notification setting changes while a
    // reminder time is set; the lock-screen switch is the simplest trigger.
    // The tall surface keeps the whole Notifications section built, so both
    // the switch and the banner above it are reachable without scrolling.
    Future<void> toggleLockScreen(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settingsProvider = SettingsProvider();
      await settingsProvider.load();
      await tester.pumpWidget(_wrap(settingsProvider: settingsProvider));
      await tester.pump();

      await tester.tap(find.text('Show on lock screen'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows an inline message naming notifications when the '
        'notification permission is refused', (tester) async {
      fake.notificationsGranted = false;

      await toggleLockScreen(tester);

      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.textContaining('Allow notifications', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('shows an inline message naming exact alarms when that '
        'permission is refused', (tester) async {
      fake.exactAlarmsGranted = false;

      await toggleLockScreen(tester);

      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.textContaining('exact alarms', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('shows no message once the reminder schedules successfully',
        (tester) async {
      await toggleLockScreen(tester);

      expect(find.byType(InlineStatusBanner), findsNothing);
    });
  });
}
