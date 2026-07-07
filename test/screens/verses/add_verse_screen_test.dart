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
import 'package:bible_flashcards/services/bible_lookup_service.dart';
import 'package:bible_flashcards/services/esv_lookup_service.dart';

import '../../helpers/fake_database_helper.dart';
import '../../helpers/verse_factory.dart';

Widget _wrap(
  SettingsProvider settingsProvider, {
  EsvLookupService? esvLookupService,
  BibleLookupService? lookupService,
  VerseProvider? verseProvider,
  Future<Map<String, String>> Function()? customVariantLookup,
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
      home: AddVerseScreen(
        esvLookupService: esvLookupService,
        lookupService: lookupService,
        customVariantLookup: customVariantLookup,
      ),
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

        await _tapAndSettle(tester, find.text('Continue'));

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

        final searchButton = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('Search'),
            matching: find.byType(FilledButton),
          ),
        );
        expect(searchButton.focusNode!.hasFocus, isTrue);
      },
    );

    testWidgets(
      'fills the verse text field directly on lookup success (consent already granted), '
      'with no intermediate Accept/Dismiss card',
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
        await _tapAndSettle(tester, find.text('Search'));

        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Accept'), findsNothing);
        expect(find.text('Dismiss'), findsNothing);
        final textField =
            tester.widget<TextFormField>(find.byType(TextFormField).last);
        expect(
          textField.controller!.text,
          contains('For God so loved the world.'),
        );
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
        await _tapAndSettle(tester, find.text('Search'));

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
    'losing focus on the reference field normalizes it to the resolved full book name',
    (tester) async {
      final settingsProvider = SettingsProvider();
      final verseProvider = VerseProvider(DatabaseHelper());

      await tester.pumpWidget(
        _wrap(settingsProvider, verseProvider: verseProvider),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'Phil 4:13');
      await tester.runAsync(() async {
        // Move focus to the verse text field, blurring the reference field.
        await tester.tap(find.byType(TextFormField).last);
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      });

      final referenceField =
          tester.widget<TextFormField>(find.byType(TextFormField).first);
      expect(referenceField.controller!.text, 'Philippians 4:13');
    },
  );

  testWidgets(
    'losing focus on the reference field with an unresolved book name shows an inline error '
    'without stealing focus back',
    (tester) async {
      final settingsProvider = SettingsProvider();
      final verseProvider = VerseProvider(DatabaseHelper());

      await tester.pumpWidget(
        _wrap(settingsProvider, verseProvider: verseProvider),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'Xyzzy 1:1');
      await tester.runAsync(() async {
        await tester.tap(find.byType(TextFormField).last);
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      });

      expect(find.text('Unrecognized book name'), findsOneWidget);
    },
  );

  testWidgets(
    'Save Verse opens a confirmation AlertDialog showing the normalized reference and verse text, '
    'without saving yet',
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

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Philippians 4:13'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('I can do all things through him.'),
        ),
        findsOneWidget,
      );

      await tester.runAsync(() async {
        final db = await DatabaseHelper().database;
        expect(await db.query('verses'), isEmpty);
      });
    },
  );

  testWidgets(
    'confirming the Save dialog saves the verse with the normalized full book name',
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
      await _tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Save'),
        ),
      );

      await tester.runAsync(() async {
        final db = await DatabaseHelper().database;
        final rows = await db.query('verses');
        expect(rows, hasLength(1));
        expect(rows.single['reference'], 'Philippians 4:13');
      });
    },
  );

  testWidgets(
    'rapid repeat taps on the Save dialog confirm button save the verse only once',
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

      final confirmButtonFinder = find.byKey(
        const Key('add-verse-confirm-save-button'),
      );
      final confirmButton = tester.widget<FilledButton>(confirmButtonFinder);
      expect(
        confirmButton.onPressed,
        isNotNull,
        reason: 'confirm button should be enabled for the first tap',
      );

      await tester.runAsync(() async {
        // Invoke the confirm button's callback twice back-to-back, as if a
        // buffered second tap were dispatched to it before the first pop
        // took effect — the callback itself must guard against this rather
        // than relying on the tap never reaching it.
        confirmButton.onPressed!();
        confirmButton.onPressed?.call();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await Future.delayed(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 500));
      });

      await tester.runAsync(() async {
        final db = await DatabaseHelper().database;
        final rows = await db.query('verses');
        expect(rows, hasLength(1));
      });
    },
  );

  testWidgets(
    'canceling the Save dialog leaves the form unchanged and saves nothing',
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
      await _tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancel'),
        ),
      );

      expect(find.byType(AlertDialog), findsNothing);
      await tester.runAsync(() async {
        final db = await DatabaseHelper().database;
        expect(await db.query('verses'), isEmpty);
      });
    },
  );

  testWidgets(
    'closing the Save confirmation dialog (via Cancel) restores focus to the '
    'Save button, not the Search button',
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
      await _tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancel'),
        ),
      );

      final saveButton = tester.widget<FilledButton>(
        find.byKey(const Key('add-verse-save-button')),
      );
      final searchButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Search'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(saveButton.focusNode!.hasFocus, isTrue);
      expect(searchButton.focusNode!.hasFocus, isFalse);
    },
  );

  testWidgets(
    'the Save confirmation dialog shows Available as the destination list '
    'when "Add directly to Memorized" is unchecked',
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

      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Available'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'the Save confirmation dialog shows Memorized as the destination list '
    'when "Add directly to Memorized" is checked',
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
      await tester.tap(find.text('Add directly to Memorized'));
      await tester.pump();
      await _tapAndSettle(tester, find.text('Save Verse'));

      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Memorized'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'checking "Save and add more" changes the Save dialog\'s confirm button '
    'to say "Save and add more"',
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
      await tester.tap(find.text('Save and add more'));
      await tester.pump();
      await _tapAndSettle(tester, find.text('Save Verse'));

      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Save and add more'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Save'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'confirming "Save and add more" saves the verse, stays on the screen, '
    'and clears the form back to a blank state',
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
      await tester.tap(find.text('Save and add more'));
      await tester.pump();
      await tester.tap(find.text('Add directly to Memorized'));
      await tester.pump();
      await _tapAndSettle(tester, find.text('Save Verse'));
      await _tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Save and add more'),
        ),
      );

      // Still on the Add Verse screen, not popped.
      expect(find.byType(AddVerseScreen), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      final referenceField =
          tester.widget<TextFormField>(find.byType(TextFormField).first);
      final textField =
          tester.widget<TextFormField>(find.byType(TextFormField).last);
      expect(referenceField.controller!.text, isEmpty);
      expect(textField.controller!.text, isEmpty);

      final memorizedCheckbox = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Add directly to Memorized'),
      );
      expect(memorizedCheckbox.value, isFalse);

      // "Save and add more" stays checked so repeated entry keeps working.
      final addMoreCheckbox = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Save and add more'),
      );
      expect(addMoreCheckbox.value, isTrue);

      await tester.runAsync(() async {
        final db = await DatabaseHelper().database;
        final rows = await db.query('verses');
        expect(rows, hasLength(1));
        expect(rows.single['reference'], 'Philippians 4:13');
      });
    },
  );

  testWidgets(
    'checking "Add directly to Memorized" saves the verse as memorized',
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
      await tester.tap(find.text('Add directly to Memorized'));
      await tester.pump();

      await _tapAndSettle(tester, find.text('Save Verse'));
      await _tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Save'),
        ),
      );

      await tester.runAsync(() async {
        final db = await DatabaseHelper().database;
        final rows = await db.query('verses');
        expect(rows, hasLength(1));
        expect(rows.single['is_memorized'], 1);
        expect(rows.single['memorized_at'], isNotNull);
      });
    },
  );

  testWidgets(
    'tapping Save right after editing the reference field triggers exactly '
    'one reference resolution (not one from blur and one from Save)',
    (tester) async {
      final settingsProvider = SettingsProvider();
      final verseProvider = VerseProvider(DatabaseHelper());
      var lookupCount = 0;
      Future<Map<String, String>> countingLookup() async {
        lookupCount++;
        return DatabaseHelper().getCustomVariantLookup();
      }

      await tester.pumpWidget(
        _wrap(
          settingsProvider,
          verseProvider: verseProvider,
          customVariantLookup: countingLookup,
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'Phil 4:13');
      await tester.enterText(
        find.byType(TextFormField).last,
        'I can do all things through him.',
      );
      // Tapping Save directly (without tabbing away first) blurs the
      // reference field and invokes the save handler in close succession.
      await _tapAndSettle(tester, find.text('Save Verse'));

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(lookupCount, 1);
    },
  );

  testWidgets(
    'defaults to not saving as Memorized when the checkbox is left unchecked',
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
      await _tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Save'),
        ),
      );

      await tester.runAsync(() async {
        final db = await DatabaseHelper().database;
        final rows = await db.query('verses');
        expect(rows.single['is_memorized'], 0);
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

      expect(find.byType(AlertDialog), findsNothing);
      await tester.runAsync(() async {
        final db = await DatabaseHelper().database;
        expect(await db.query('verses'), isEmpty);
      });
      expect(find.textContaining('Book Name Variants'), findsWidgets);
    },
  );

  testWidgets(
    'web lookup resolves a custom book-name variant before calling the lookup service',
    (tester) async {
      final settingsProvider = SettingsProvider();
      final verseProvider = VerseProvider(DatabaseHelper());
      await tester.runAsync(
        () => DatabaseHelper().addBookNameVariant('ROM', 'Rmz'),
      );
      final lookupService = BibleLookupService(
        client: MockClient(
          (_) async => http.Response(
            '{"verses": [{"verse": 28, "text": "And we know."}]}',
            200,
          ),
        ),
      );

      await tester.pumpWidget(
        _wrap(
          settingsProvider,
          verseProvider: verseProvider,
          lookupService: lookupService,
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'Rmz 8:28');
      await _tapAndSettle(tester, find.text('Search'));

      expect(find.byType(AlertDialog), findsOneWidget);
      await _tapAndSettle(tester, find.text('Continue'));

      expect(find.textContaining('Unknown book name'), findsNothing);
      expect(find.textContaining('And we know.'), findsOneWidget);
    },
  );

  testWidgets(
    'web lookup surfaces a distinct "unrecognized book name" error, not the generic format error, '
    'when the book name resolves to neither a built-in name nor a custom variant',
    (tester) async {
      final settingsProvider = SettingsProvider();
      final verseProvider = VerseProvider(DatabaseHelper());
      final lookupService = BibleLookupService(
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      await tester.pumpWidget(
        _wrap(
          settingsProvider,
          verseProvider: verseProvider,
          lookupService: lookupService,
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'Xyzzy 1:1');
      await _tapAndSettle(tester, find.text('Search'));

      expect(find.byType(AlertDialog), findsOneWidget);
      await _tapAndSettle(tester, find.text('Continue'));

      expect(
        find.textContaining('Unrecognized book name'),
        findsWidgets,
      );
      expect(find.textContaining('Invalid reference format'), findsNothing);
    },
  );

  testWidgets(
    'web lookup surfaces the "Open Book Name Variants settings" shortcut on '
    'an unresolved book name, same as a failed save',
    (tester) async {
      final settingsProvider = SettingsProvider();
      final verseProvider = VerseProvider(DatabaseHelper());
      final lookupService = BibleLookupService(
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      await tester.pumpWidget(
        _wrap(
          settingsProvider,
          verseProvider: verseProvider,
          lookupService: lookupService,
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'Xyzzy 1:1');
      await _tapAndSettle(tester, find.text('Search'));

      expect(find.byType(AlertDialog), findsOneWidget);
      await _tapAndSettle(tester, find.text('Continue'));

      await tester.scrollUntilVisible(
        find.text('Open Book Name Variants settings'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Open Book Name Variants settings'), findsOneWidget);
    },
  );

  testWidgets(
    'web lookup falls back to built-in book-name resolution when reading '
    'custom variants from the database throws',
    (tester) async {
      final settingsProvider = SettingsProvider();
      final verseProvider = VerseProvider(DatabaseHelper());
      final lookupService = BibleLookupService(
        client: MockClient(
          (_) async => http.Response(
            '{"verses": [{"verse": 16, "text": "For God so loved the world."}]}',
            200,
          ),
        ),
      );

      // Swap in an in-memory database with no book_name_variants table, so
      // getCustomVariantLookup() throws "no such table" instead of returning.
      await tester.runAsync(() async {
        final brokenDb = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(version: 1),
        );
        DatabaseHelper.debugSetDatabase(brokenDb);
      });

      await tester.pumpWidget(
        _wrap(
          settingsProvider,
          verseProvider: verseProvider,
          lookupService: lookupService,
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'John 3:16');
      await _tapAndSettle(tester, find.text('Search'));

      expect(find.byType(AlertDialog), findsOneWidget);
      await _tapAndSettle(tester, find.text('Continue'));

      expect(find.textContaining('For God so loved the world.'), findsOneWidget);
      expect(find.textContaining('Unrecognized book name'), findsNothing);
    },
  );
}
