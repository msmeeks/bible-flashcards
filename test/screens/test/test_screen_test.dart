import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/models/verse.dart';
import 'package:bible_flashcards/providers/verse_provider.dart';
import 'package:bible_flashcards/screens/test/test_screen.dart';
import 'package:bible_flashcards/screens/test/test_session_screen.dart';

Verse _verse(String id, {bool isMemorized = true, bool isVerseOfWeek = false}) {
  return Verse(
    id: id,
    reference: 'Ref $id',
    text: 'Text $id',
    translation: 'ESV',
    packId: 'pack1',
    isMemorized: isMemorized,
    isVerseOfWeek: isVerseOfWeek,
    addedAt: DateTime(2024, 1, 1),
  );
}

Widget _wrap(VerseProvider provider) {
  return ChangeNotifierProvider<VerseProvider>.value(
    value: provider,
    child: const MaterialApp(home: TestScreen()),
  );
}

Future<void> _selectReviewMode(WidgetTester tester) async {
  await tester.tap(find.text('Review'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Review mode shows a count slider and verse-of-week toggle',
    (tester) async {
      final provider = VerseProvider(DatabaseHelper());
      provider.debugSetVerses(
        List.generate(7, (i) => _verse('v$i')),
      );

      await tester.pumpWidget(_wrap(provider));
      await _selectReviewMode(tester);

      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('Include verse of the week'), findsOneWidget);
    },
  );

  testWidgets(
    'Verse of Week mode hides the review controls',
    (tester) async {
      final provider = VerseProvider(DatabaseHelper());
      provider.debugSetVerses(
        List.generate(7, (i) => _verse('v$i')),
      );

      await tester.pumpWidget(_wrap(provider));

      expect(find.byType(Slider), findsNothing);
      expect(find.text('Include verse of the week'), findsNothing);
    },
  );

  testWidgets(
    'count chip presets are grouped under a single Semantics label',
    (tester) async {
      final provider = VerseProvider(DatabaseHelper());
      provider.debugSetVerses(
        List.generate(7, (i) => _verse('v$i')),
      );

      await tester.pumpWidget(_wrap(provider));
      await _selectReviewMode(tester);

      expect(
        find.bySemanticsLabel('Number of verses — select a preset'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'jump-chips beyond the memorized count are absent, not disabled',
    (tester) async {
      final provider = VerseProvider(DatabaseHelper());
      provider.debugSetVerses(
        List.generate(7, (i) => _verse('v$i')),
      );

      await tester.pumpWidget(_wrap(provider));
      await _selectReviewMode(tester);

      expect(find.widgetWithText(FilterChip, '5'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, '10'), findsNothing);
      expect(find.widgetWithText(FilterChip, '20'), findsNothing);
      expect(find.widgetWithText(FilterChip, 'All'), findsOneWidget);
    },
  );

  testWidgets(
    'choosing a custom count and toggle passes them into the test session',
    (tester) async {
      final provider = VerseProvider(DatabaseHelper());
      provider.debugSetVerses([
        ...List.generate(7, (i) => _verse('v$i')),
        _verse('vow', isVerseOfWeek: true),
      ]);

      await tester.pumpWidget(_wrap(provider));
      await _selectReviewMode(tester);

      await tester.tap(find.widgetWithText(FilterChip, '5'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Include verse of the week'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Start Test'), 200);
      await tester.tap(find.text('Start Test'));
      await tester.pumpAndSettle();

      final session =
          tester.widget<TestSessionScreen>(find.byType(TestSessionScreen));
      expect(session.verses.length, 5);
      expect(session.verses.any((v) => v.id == 'vow'), isFalse);
    },
  );

  testWidgets(
    'start with no formats selected shows error',
    (tester) async {
      final provider = VerseProvider(DatabaseHelper());
      provider.debugSetVerses([_verse('vow', isVerseOfWeek: true)]);

      await tester.pumpWidget(_wrap(provider));

      for (final label in ['Recite', 'Type', 'Fill Blanks']) {
        final finder = find.widgetWithText(FilterChip, label);
        if (finder.evaluate().isNotEmpty) {
          await tester.tap(finder);
          await tester.pump();
        }
      }

      await tester.tap(find.text('Start Test'));
      await tester.pump();

      expect(find.text('Select at least one format.'), findsOneWidget);
    },
  );

  testWidgets(
    'start with no directions selected shows error',
    (tester) async {
      final provider = VerseProvider(DatabaseHelper());
      provider.debugSetVerses([_verse('vow', isVerseOfWeek: true)]);

      await tester.pumpWidget(_wrap(provider));

      await tester.tap(find.text('Reference → Text'));
      await tester.pump();
      await tester.tap(find.text('Text → Reference'));
      await tester.pump();

      await tester.tap(find.text('Start Test'));
      await tester.pump();

      expect(
        find.text('Select at least one prompt direction.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'verse-of-week mode with no verse shows error',
    (tester) async {
      final provider = VerseProvider(DatabaseHelper());
      provider.debugSetVerses([]);

      await tester.pumpWidget(_wrap(provider));

      await tester.tap(find.text('Start Test'));
      await tester.pump();

      expect(
        find.text('No verse of the week is set. Go to Home to set one.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'verse-of-week mode with verse set navigates to session',
    (tester) async {
      final provider = VerseProvider(DatabaseHelper());
      provider.debugSetVerses([_verse('vow', isVerseOfWeek: true)]);

      await tester.pumpWidget(_wrap(provider));

      await tester.tap(find.text('Start Test'));
      await tester.pumpAndSettle();

      expect(find.byType(TestSessionScreen), findsOneWidget);
    },
  );

  testWidgets(
    'review mode with no memorized verses shows error',
    (tester) async {
      final provider = VerseProvider(DatabaseHelper());
      provider.debugSetVerses([]);

      await tester.pumpWidget(_wrap(provider));
      await _selectReviewMode(tester);

      await tester.tap(find.text('Start Test'));
      await tester.pump();

      expect(
        find.text('You need at least 1 memorized verse for Review mode.'),
        findsOneWidget,
      );
    },
  );
}
