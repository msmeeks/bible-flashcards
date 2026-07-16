// End-to-end smoke test driven against a real device/emulator via
// `flutter test integration_test/app_smoke_test.dart -d <device>`.
// Exercises: add a verse manually, mark it memorized (which also sets it as
// verse of the week), confirm Home reflects that, then complete a test
// session and confirm the results screen is reached.
import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/main.dart' as app;
import 'package:bible_flashcards/screens/test/test_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'add verse, memorize it, home shows verse of week, complete a test',
    (tester) async {
      const reference = 'Genesis 1:1';
      const text = 'In the beginning God created the heavens and the earth.';

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Dismiss the first-launch engagement-tracking consent dialog, if shown.
      final gotIt = find.text('Got it');
      if (gotIt.evaluate().isNotEmpty) {
        await tester.tap(gotIt);
        await tester.pumpAndSettle();
      }

      // Home starts with no verse of the week — go add one.
      await tester.tap(find.byKey(const Key('home-choose-verse-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('add-verse-reference-field')),
        reference,
      );
      await tester.enterText(
        find.byKey(const Key('add-verse-text-field')),
        text,
      );
      // Force a non-ESV translation so save never requires network access
      // or the ESV consent dialog.
      await tester.tap(find.text('BSB'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-verse-save-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-verse-confirm-save-button')));
      await tester.pumpAndSettle();

      // Saving pops back to Home; the new verse isn't memorized/verse-of-week
      // yet. Switch to the Verses tab, then the Available sub-tab (Memorized
      // is the default and would be empty at this point), to memorize it.
      await tester.tap(find.text('Verses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Available'));
      await tester.pumpAndSettle();

      final saved = await DatabaseHelper().getVerses();
      final addedVerse = saved.firstWhere((v) => v.reference == reference);

      // The newly added verse is grouped in its own pack at the end of the
      // Available list, below the fold — scroll it into view first.
      final memorizeButton =
          find.byKey(Key('memorize-button-${addedVerse.id}'));
      final availableList = find.byType(ListView);
      for (var i = 0; i < 20 && memorizeButton.evaluate().isEmpty; i++) {
        await tester.drag(availableList, const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      expect(memorizeButton, findsOneWidget);
      await tester.ensureVisible(memorizeButton);
      await tester.pumpAndSettle();

      await tester.tap(memorizeButton);
      await tester.pumpAndSettle();

      // Back on Home, the verse-of-week card should now show the new verse.
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      final verseOfWeekCard = find.byKey(const Key('verse-of-week-card'));
      expect(verseOfWeekCard, findsOneWidget);
      expect(
        find.descendant(of: verseOfWeekCard, matching: find.text(reference)),
        findsOneWidget,
      );

      // Start a test on the verse of the week, restricted to a single
      // Type/Reference→Text question for a deterministic smoke run.
      await tester.tap(find.byKey(const Key('home-start-test-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('format-chip-fillBlank')));
      await tester.tap(find.byKey(const Key('direction-chip-textToRef')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('test-setup-start-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('type-answer-field')),
        text,
      );
      await tester.tap(find.byKey(const Key('type-check-button')));
      // _onTypeCheck holds the result on screen for ~1s before advancing.
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();

      expect(find.byType(TestResultScreen), findsOneWidget);
    },
  );
}
