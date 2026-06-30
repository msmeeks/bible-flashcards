import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/models/settings.dart';
import 'package:bible_flashcards/providers/settings_provider.dart';
import 'package:bible_flashcards/providers/verse_provider.dart';
import 'package:bible_flashcards/screens/verses/add_verse_screen.dart';
import 'package:bible_flashcards/services/esv_lookup_service.dart';

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
}
