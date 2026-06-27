import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/models/settings.dart';
import 'package:bible_flashcards/providers/settings_provider.dart';
import 'package:bible_flashcards/providers/verse_provider.dart';
import 'package:bible_flashcards/screens/verses/add_verse_screen.dart';

Widget _wrap(SettingsProvider settingsProvider) {
  final dbHelper = DatabaseHelper();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
      ChangeNotifierProvider<VerseProvider>.value(
        value: VerseProvider(dbHelper),
      ),
    ],
    child: const MaterialApp(home: AddVerseScreen()),
  );
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
      final settingsProvider = SettingsProvider();
      await settingsProvider.update(
        const AppSettings().copyWith(defaultTranslation: 'ESV'),
      );

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
}
