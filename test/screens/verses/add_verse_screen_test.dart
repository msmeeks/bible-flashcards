import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/models/settings.dart';
import 'package:bible_flashcards/providers/settings_provider.dart';
import 'package:bible_flashcards/providers/verse_provider.dart';
import 'package:bible_flashcards/screens/verses/add_verse_screen.dart';
import 'package:bible_flashcards/services/esv_lookup_service.dart';

import '../../helpers/fake_database_helper.dart';
import '../../helpers/verse_factory.dart';

Widget _wrap(
  SettingsProvider settingsProvider, {
  EsvLookupService? esvLookupService,
  VerseProvider? verseProvider,
}) {
  final dbHelper = DatabaseHelper();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
      ChangeNotifierProvider<VerseProvider>.value(
        value: verseProvider ?? VerseProvider(dbHelper),
      ),
    ],
    child: MaterialApp(
      home: AddVerseScreen(esvLookupService: esvLookupService),
    ),
  );
}

/// Taps [finder] inside [WidgetTester.runAsync] so a real (non-fake-clock)
/// async gap — e.g. the sqflite_common_ffi round-trip used by the
/// reference-normalization save flow — has a chance to complete. Uses
/// explicit pumps rather than `pumpAndSettle`, which can deadlock when
/// nested inside `runAsync`.
Future<void> _tapAndSettle(WidgetTester tester, Finder finder) =>
    tester.runAsync(() async {
      await tester.tap(finder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await Future.delayed(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500));
    });

Future<SettingsProvider> _esvDefaultSettings() async {
  final settingsProvider = SettingsProvider();
  await settingsProvider.update(
    const AppSettings().copyWith(defaultTranslation: 'ESV'),
  );
  return settingsProvider;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'initializes the translation selector to the default translation setting',
    (tester) async {
      final settingsProvider = SettingsProvider();
      await settingsProvider.update(
        const AppSettings().copyWith(defaultTranslation: 'KJV'),
      );

      await tester.pumpWidget(_wrap(settingsProvider));
      await tester.pump();

      final segmentedButton = tester.widget<SegmentedButton<String>>(
        find.byWidgetPredicate(
          (w) => w is SegmentedButton<String> && w.selected.contains('KJV'),
        ),
      );
      expect(segmentedButton.selected, {'KJV'});
    },
  );

  testWidgets(
    'falls back to BSB when the default translation is ESV but the lookup service has no API key',
    (tester) async {
      final settingsProvider = await _esvDefaultSettings();

      await tester.pumpWidget(_wrap(settingsProvider));
      await tester.pump();

      final segmentedButton = tester.widget<SegmentedButton<String>>(
        find.byWidgetPredicate(
          (w) => w is SegmentedButton<String> && w.selected.contains('BSB'),
        ),
      );
      expect(segmentedButton.selected, {'BSB'});
    },
  );

  testWidgets(
    'translation selector has no separate ActionChip toggle for ESV; '
    'it is a segment in the same SegmentedButton as the other translations',
    (tester) async {
      final settingsProvider = SettingsProvider();
      await settingsProvider.update(
        const AppSettings().copyWith(defaultTranslation: 'BSB'),
      );

      await tester.pumpWidget(_wrap(settingsProvider));
      await tester.pump();

      expect(find.byType(ActionChip), findsNothing);
      final segmentedButton = tester.widget<SegmentedButton<String>>(
        find.byWidgetPredicate(
          (w) => w is SegmentedButton<String> && w.selected.contains('BSB'),
        ),
      );
      // ESV segment isn't offered in this test build (no API key configured).
      expect(
        segmentedButton.segments.any((s) => s.value == 'ESV'),
        isFalse,
      );
    },
  );

  testWidgets(
    'ESV selection in the translation control is conveyed by semantics and a '
    'non-color check icon, not background color alone',
    (tester) async {
      final settingsProvider = SettingsProvider();
      await settingsProvider.update(
        const AppSettings().copyWith(defaultTranslation: 'BSB'),
      );
      final esvService = EsvLookupService(
        client: MockClient((_) async => http.Response('{}', 200)),
        apiKey: 'test-key',
      );

      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        settingsProvider,
        esvLookupService: esvService,
      ));
      await tester.pump();

      final segmentedButton = tester.widget<SegmentedButton<String>>(
        find.byWidgetPredicate(
          (w) => w is SegmentedButton<String> && w.selected.contains('BSB'),
        ),
      );
      expect(segmentedButton.showSelectedIcon, isTrue);

      await tester.tap(find.text('ESV'));
      await tester.pump();

      final esvSemantics =
          tester.getSemantics(find.text('ESV')).getSemanticsData();
      expect(esvSemantics.hasFlag(SemanticsFlag.isSelected), isTrue);

      handle.dispose();
    },
  );

  group('ESV lookup flow (with injected EsvLookupService)', () {
    testWidgets(
      'shows cap warning and skips the consent prompt when already at the ESV cap',
      (tester) async {
        final settingsProvider = await _esvDefaultSettings();
        final esvService = EsvLookupService(
          client: MockClient((_) async => http.Response('{}', 200)),
          apiKey: 'test-key',
        );
        final verseProvider = VerseProvider(DatabaseHelper())
          ..debugSetVerses(List.generate(500, (i) => makeVerse('esv$i')));

        await tester.pumpWidget(_wrap(
          settingsProvider,
          esvLookupService: esvService,
          verseProvider: verseProvider,
        ));
        await tester.pump();

        await tester.enterText(find.byType(TextFormField).first, 'John 3:16');
        await tester.tap(find.text('Search'));
        await tester.pump();

        expect(
          find.textContaining('You have 500 ESV verses stored'),
          findsOneWidget,
        );
        expect(find.byType(AlertDialog), findsNothing);
      },
    );

    testWidgets(
      'consent dialog accept proceeds to lookup and shows the preview',
      (tester) async {
        final settingsProvider = await _esvDefaultSettings();
        final esvService = EsvLookupService(
          client: MockClient(
            (_) async => http.Response(
              '{"passages": ["For God so loved the world. "]}',
              200,
            ),
          ),
          apiKey: 'test-key',
        );

        await tester.pumpWidget(
          _wrap(settingsProvider, esvLookupService: esvService),
        );
        await tester.pump();

        await tester.enterText(find.byType(TextFormField).first, 'John 3:16');
        await tester.tap(find.text('Search'));
        await tester.pump();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('ESV Verse Lookup'), findsOneWidget);

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(find.textContaining('For God so loved the world.'),
            findsOneWidget);
      },
    );

    testWidgets(
      'consent dialog cancel does not perform the lookup',
      (tester) async {
        final settingsProvider = await _esvDefaultSettings();
        var requested = false;
        final esvService = EsvLookupService(
          client: MockClient((_) async {
            requested = true;
            return http.Response('{"passages": ["Text. "]}', 200);
          }),
          apiKey: 'test-key',
        );

        await tester.pumpWidget(
          _wrap(settingsProvider, esvLookupService: esvService),
        );
        await tester.pump();

        await tester.enterText(find.byType(TextFormField).first, 'John 3:16');
        await tester.tap(find.text('Search'));
        await tester.pump();

        await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancel'),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(requested, isFalse);
        expect(find.text('Accept'), findsNothing);
      },
    );

    testWidgets(
      'renders the ESV verse preview on lookup success (consent already granted)',
      (tester) async {
        SharedPreferences.setMockInitialValues({'esv_lookup_consent_v1': true});
        final settingsProvider = await _esvDefaultSettings();
        final esvService = EsvLookupService(
          client: MockClient(
            (_) async => http.Response(
              '{"passages": ["For God so loved the world. "]}',
              200,
            ),
          ),
          apiKey: 'test-key',
        );

        await tester.pumpWidget(
          _wrap(settingsProvider, esvLookupService: esvService),
        );
        await tester.pump();

        await tester.enterText(find.byType(TextFormField).first, 'John 3:16');
        await tester.tap(find.text('Search'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Accept'), findsOneWidget);
        expect(find.textContaining('For God so loved the world.'),
            findsOneWidget);
      },
    );

    testWidgets(
      'renders the lookup error on failure (consent already granted)',
      (tester) async {
        SharedPreferences.setMockInitialValues({'esv_lookup_consent_v1': true});
        final settingsProvider = await _esvDefaultSettings();
        final esvService = EsvLookupService(
          client: MockClient((_) async => http.Response('{}', 404)),
          apiKey: 'test-key',
        );

        await tester.pumpWidget(
          _wrap(settingsProvider, esvLookupService: esvService),
        );
        await tester.pump();

        await tester.enterText(find.byType(TextFormField).first, 'John 3:16');
        await tester.tap(find.text('Search'));
        await tester.pumpAndSettle();

        expect(find.text('Accept'), findsNothing);
        expect(
          find.textContaining('Verse not found'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'cap warning clears when switching translation away from ESV',
      (tester) async {
        final settingsProvider = await _esvDefaultSettings();
        final esvService = EsvLookupService(
          client: MockClient((_) async => http.Response('{}', 200)),
          apiKey: 'test-key',
        );
        final verseProvider = VerseProvider(DatabaseHelper())
          ..debugSetVerses(List.generate(500, (i) => makeVerse('esv$i')));

        await tester.pumpWidget(_wrap(
          settingsProvider,
          esvLookupService: esvService,
          verseProvider: verseProvider,
        ));
        await tester.pump();

        await tester.enterText(find.byType(TextFormField).first, 'John 3:16');
        await tester.tap(find.text('Search'));
        await tester.pump();
        expect(
          find.textContaining('You have 500 ESV verses stored'),
          findsOneWidget,
        );

        await tester.tap(find.text('BSB'));
        await tester.pump();

        expect(
          find.textContaining('You have 500 ESV verses stored'),
          findsNothing,
        );
      },
    );
  });

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    await setUpFakeDatabase();
  });

  tearDown(() async {
    await tearDownFakeDatabase();
  });

  testWidgets(
    'save-time reference normalization: first Save tap shows the normalized reference for confirmation without saving',
    (tester) async {
      final settingsProvider = SettingsProvider();
      final verseProvider = VerseProvider(DatabaseHelper());

      await tester.pumpWidget(
        _wrap(settingsProvider, verseProvider: verseProvider),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'Phil 4:13');
      await tester.enterText(
        find.byType(TextFormField).last,
        'I can do all things through him.',
      );
      await _tapAndSettle(tester, find.text('Save Verse'));

      expect(find.textContaining('Philippians 4:13'), findsOneWidget);
      expect(find.text('Confirm & Save'), findsOneWidget);

      await tester.runAsync(() async {
        final db = await DatabaseHelper().database;
        expect(await db.query('verses'), isEmpty);
      });
    },
  );

  testWidgets(
    'save-time reference normalization: confirming the normalized reference saves the verse with the full book name',
    (tester) async {
      final settingsProvider = SettingsProvider();
      final verseProvider = VerseProvider(DatabaseHelper());

      await tester.pumpWidget(
        _wrap(settingsProvider, verseProvider: verseProvider),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'Phil 4:13');
      await tester.enterText(
        find.byType(TextFormField).last,
        'I can do all things through him.',
      );
      await _tapAndSettle(tester, find.text('Save Verse'));
      await _tapAndSettle(tester, find.text('Confirm & Save'));

      await tester.runAsync(() async {
        final db = await DatabaseHelper().database;
        final rows = await db.query('verses');
        expect(rows, hasLength(1));
        expect(rows.single['reference'], 'Philippians 4:13');
      });
    },
  );

  testWidgets(
    'save-time reference normalization: unresolved book name blocks save and surfaces both a field error and a banner',
    (tester) async {
      final settingsProvider = SettingsProvider();
      final verseProvider = VerseProvider(DatabaseHelper());

      await tester.pumpWidget(
        _wrap(settingsProvider, verseProvider: verseProvider),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'Xyzzy 1:1');
      await tester.enterText(
        find.byType(TextFormField).last,
        'Some verse text.',
      );
      await _tapAndSettle(tester, find.text('Save Verse'));

      expect(find.text('Confirm & Save'), findsNothing);
      await tester.runAsync(() async {
        final db = await DatabaseHelper().database;
        expect(await db.query('verses'), isEmpty);
      });
      expect(find.textContaining('Book Name Variants'), findsWidgets);
    },
  );
}
