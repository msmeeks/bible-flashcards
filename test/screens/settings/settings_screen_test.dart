import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/providers/settings_provider.dart';
import 'package:bible_flashcards/providers/tracking_provider.dart';
import 'package:bible_flashcards/providers/verse_provider.dart';
import 'package:bible_flashcards/screens/settings/settings_screen.dart';
import 'package:bible_flashcards/services/notification_service.dart';

class _ThrowingUrlLauncherPlatform extends UrlLauncherPlatform {
  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => false;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) {
    throw PlatformException(code: 'NO_HANDLER', message: 'no app to handle url');
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
Widget _wrap() {
  final dbHelper = DatabaseHelper();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: SettingsProvider()),
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

      expect(
        find.text('Auto-advance verse of the week'),
        findsOneWidget,
      );
      final switchFinder = find.byType(SwitchListTile);
      final autoAdvanceSwitch = tester
          .widgetList<SwitchListTile>(switchFinder)
          .firstWhere((s) => (s.title as Text).data ==
              'Auto-advance verse of the week');
      expect(autoAdvanceSwitch.value, isFalse);

      await tester.tap(find.text('Auto-advance verse of the week'));
      await tester.pump();

      final updatedSwitch = tester
          .widgetList<SwitchListTile>(switchFinder)
          .firstWhere((s) => (s.title as Text).data ==
              'Auto-advance verse of the week');
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

      await tester.tap(find.text('Auto-advance verse of the week'));
      await tester.pump();

      final switchFinder = find.byType(SwitchListTile);
      final enabledSwitch = tester
          .widgetList<SwitchListTile>(switchFinder)
          .firstWhere((s) => (s.title as Text).data ==
              'Auto-advance verse of the week');
      expect(enabledSwitch.value, isTrue);

      await tester.tap(find.text('Auto-advance verse of the week'));
      await tester.pump();

      final disabledSwitch = tester
          .widgetList<SwitchListTile>(switchFinder)
          .firstWhere((s) => (s.title as Text).data ==
              'Auto-advance verse of the week');
      expect(disabledSwitch.value, isFalse);
    },
  );
}
