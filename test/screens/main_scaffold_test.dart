import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/models/verse.dart';
import 'package:bible_flashcards/providers/audio_provider.dart';
import 'package:bible_flashcards/providers/settings_provider.dart';
import 'package:bible_flashcards/providers/tracking_provider.dart';
import 'package:bible_flashcards/providers/verse_provider.dart';
import 'package:bible_flashcards/screens/main_scaffold.dart';
import 'package:bible_flashcards/screens/verses/verses_screen.dart';
import 'package:bible_flashcards/services/notification_service.dart';

import '../helpers/fake_database_helper.dart';

Verse _memorizedVerse(String id) {
  return Verse(
    id: id,
    reference: 'Ref $id',
    text: 'Text $id',
    translation: 'ESV',
    packId: 'pack1',
    isMemorized: true,
    isVerseOfWeek: false,
    addedAt: DateTime(2024, 1, 1),
  );
}

Widget _wrap({VerseProvider? verseProvider}) {
  final dbHelper = DatabaseHelper();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>(
        create: (_) => SettingsProvider(),
      ),
      ChangeNotifierProvider<VerseProvider>(
        create: (_) => verseProvider ?? VerseProvider(dbHelper),
      ),
      ChangeNotifierProvider<AudioProvider>(
        create: (_) => AudioProvider(
          notificationService: NotificationService(),
        ),
      ),
      ChangeNotifierProvider<TrackingProvider>(
        create: (_) => TrackingProvider(dbHelper),
      ),
    ],
    child: const MaterialApp(home: MainScaffold()),
  );
}

/// The sqflite_common_ffi round-trip behind VerseProvider.loadVerses() is a
/// real (non-fake-clock) async gap, so it needs [WidgetTester.runAsync] to
/// resolve during a test — plain `pump`/`pumpAndSettle` never let it
/// complete, leaving the loading spinner (and a pending Future that fires
/// after teardown) behind.
Future<void> _settleAsync(WidgetTester tester) => tester.runAsync(() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
    });

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    // VerseDetailScreen.initState() logs engagement via DatabaseHelper,
    // which reads the tracking-consent flag through SharedPreferences —
    // without a mock this platform-channel call never resolves in tests.
    SharedPreferences.setMockInitialValues({});
    await setUpFakeDatabase();
  });

  tearDown(() async {
    await tearDownFakeDatabase();
  });

  testWidgets('bottom nav has Review between Verses and Test', (tester) async {
    await tester.pumpWidget(_wrap());
    await _settleAsync(tester);

    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();

    expect(labels, ['Home', 'Verses', 'Review', 'Test', 'Settings']);
  });

  testWidgets('VersesScreen activationCount increments each time Verses tab is selected', (tester) async {
    await tester.pumpWidget(_wrap());
    await _settleAsync(tester);

    // Tap Verses tab (first activation)
    await tester.tap(find.widgetWithText(NavigationDestination, 'Verses'));
    await _settleAsync(tester);
    final countAfterFirst =
        tester.widget<VersesScreen>(find.byType(VersesScreen)).activationCount;

    // Navigate away
    await tester.tap(find.widgetWithText(NavigationDestination, 'Review'));
    await _settleAsync(tester);

    // Return to Verses (second activation)
    await tester.tap(find.widgetWithText(NavigationDestination, 'Verses'));
    await _settleAsync(tester);
    final countAfterSecond =
        tester.widget<VersesScreen>(find.byType(VersesScreen)).activationCount;

    expect(countAfterSecond, greaterThan(countAfterFirst));
  });

  testWidgets('bottom navbar stays visible after pushing into verse detail',
      (tester) async {
    await tester.runAsync(() => DatabaseHelper().insertVerse(_memorizedVerse('v1')));
    await tester.pumpWidget(_wrap());
    await _settleAsync(tester);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Verses'));
    await _settleAsync(tester);

    await tester.tap(find.text('Ref v1'));
    await _settleAsync(tester);

    // We're on the verse detail sub-screen now...
    expect(find.text('Ref v1'), findsWidgets);
    // ...but the persistent shell's navbar is still present.
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets(
      'Android system back from verse detail returns to the Verses list, not app exit',
      (tester) async {
    await tester.runAsync(() => DatabaseHelper().insertVerse(_memorizedVerse('v1')));
    await tester.pumpWidget(_wrap());
    await _settleAsync(tester);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Verses'));
    await _settleAsync(tester);

    await tester.tap(find.text('Ref v1'));
    await _settleAsync(tester);

    // Confirm we actually navigated to the sub-screen before backing out of it
    // ('Play Audio' only appears on VerseDetailScreen, not the Verses list tile).
    expect(find.text('Play Audio'), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    // Back in the Verses list — the verse-detail-only content is gone...
    expect(find.text('Play Audio'), findsNothing);
    // ...the Verses tab is still the one highlighted...
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 1);
    // ...and the shell (navbar) is still present, i.e. the app did not exit.
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets(
      'system back on a non-Home tab root switches to Home instead of exiting',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await _settleAsync(tester);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await _settleAsync(tester);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 0);
  });

  testWidgets('system back on the Home tab root exits the app', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(_wrap());
    await _settleAsync(tester);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(calls.map((c) => c.method), contains('SystemNavigator.pop'));
  });

  testWidgets(
      'controls in inactive tabs are excluded from the semantics tree until selected',
      (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(_wrap());
    await _settleAsync(tester);

    // Home tab is active, so "ESV.org" (a control inside the inactive
    // Settings tab, underneath the IndexedStack) must not be reachable via
    // the semantics tree at all.
    expect(
      () => tester.getSemantics(find.text('Interrupt audio for verse reminders')),
      throwsA(isA<StateError>()),
    );

    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await _settleAsync(tester);

    // Now that Settings is active, its control is reachable again.
    expect(
      () => tester.getSemantics(find.text('Interrupt audio for verse reminders')),
      returnsNormally,
    );

    handle.dispose();
  });
}
