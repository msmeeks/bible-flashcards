import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/providers/verse_provider.dart';
import 'package:bible_flashcards/screens/verses/verses_screen.dart';

import '../../helpers/async_settle.dart';
import '../../helpers/fake_database_helper.dart';
import '../../helpers/verse_factory.dart';

Widget _wrap(VerseProvider provider) {
  return ChangeNotifierProvider<VerseProvider>.value(
    value: provider,
    child: const MaterialApp(home: VersesScreen()),
  );
}

void main() {
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
    'keeps the Available list scroll position after tapping Memorize',
    (tester) async {
      final dbHelper = DatabaseHelper();
      final provider = VerseProvider(dbHelper);
      await tester.runAsync(() async {
        for (var i = 0; i < 30; i++) {
          await dbHelper.insertVerse(
            makeVerse(
              'verse-$i',
              isMemorized: false,
              addedAt: DateTime(2024, 1, 1 + i),
            ),
          );
        }
        await provider.loadVerses();
      });

      await tester.pumpWidget(_wrap(provider));
      await tester.pump();
      // Switch to the Available tab.
      await tester.tap(find.text('Available'));
      await tester.pumpAndSettle();

      // Scroll partway down so a mid-list item can be tapped without the
      // removal shrinking maxScrollExtent below the current offset.
      final tappedButtonFinder =
          find.byKey(const Key('memorize-button-verse-10'));
      final availableScrollableFinder = find.descendant(
        of: find.byKey(const Key('availableVerseList')),
        matching: find.byType(Scrollable),
      );
      final scrollableState =
          tester.state<ScrollableState>(availableScrollableFinder);
      scrollableState.position.jumpTo(400);
      await tester.pumpAndSettle();
      final offsetBeforeTap = scrollableState.position.pixels;
      expect(offsetBeforeTap, greaterThan(0));

      // Record the reference text of the item currently rendered at the top
      // of the viewport, to confirm it's unaffected by the removal below it.
      final topTileTextBefore =
          tester.widgetList<Text>(find.textContaining('Ref verse-')).first.data;

      await tester.runAsync(() async {
        await tester.tap(tappedButtonFinder);
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
      });

      final scrollableStateAfter =
          tester.state<ScrollableState>(availableScrollableFinder);
      final offsetAfterTap = scrollableStateAfter.position.pixels;
      final topTileTextAfter =
          tester.widgetList<Text>(find.textContaining('Ref verse-')).first.data;

      expect(offsetAfterTap, closeTo(offsetBeforeTap, 5));
      expect(topTileTextAfter, topTileTextBefore);
      expect(tappedButtonFinder, findsNothing);
    },
  );

  testWidgets(
    'keeps showing the Available list instead of a full-screen spinner '
    'when the provider re-enters a loading state after data is already '
    'loaded (e.g. the reload triggered by markMemorized)',
    (tester) async {
      final provider = VerseProvider(DatabaseHelper());
      provider.debugSetVerses(
        List.generate(
          5,
          (i) => makeVerse('verse-$i', isMemorized: false),
        ),
      );

      await tester.pumpWidget(_wrap(provider));
      await tester.pump();
      await tester.tap(find.text('Available'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('availableVerseList')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Simulate the brief isLoading=true window that loadVerses() enters
      // on every refresh, not just the very first load.
      provider.debugSetLoading(true);
      await tester.pump();

      expect(
        find.byKey(const Key('availableVerseList')),
        findsOneWidget,
        reason: 'a refresh of already-loaded data must not tear down the '
            'list (and its ScrollController) behind a full-screen spinner',
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);

      provider.debugSetLoading(false);
      await tester.pump();

      expect(find.byKey(const Key('availableVerseList')), findsOneWidget);
    },
  );

  testWidgets(
    'disables the Memorize button while the operation is in flight, '
    'guarding against a double-tap race',
    (tester) async {
      final dbHelper = DatabaseHelper();
      final provider = VerseProvider(dbHelper);
      await tester.runAsync(() async {
        await dbHelper.insertVerse(makeVerse('verse-0', isMemorized: false));
        await provider.loadVerses();
      });

      await tester.pumpWidget(_wrap(provider));
      await tester.pump();
      await tester.tap(find.text('Available'));
      await tester.pumpAndSettle();

      final buttonFinder = find.descendant(
        of: find.byKey(const Key('memorize-button-verse-0')),
        matching: find.byType(FilledButton),
      );
      final onPressed = tester.widget<FilledButton>(buttonFinder).onPressed!;

      // Start the operation once and check the button disables itself
      // before the async work resolves, so a second (real) tap landing in
      // that window can't fire a concurrent request.
      onPressed();
      await tester.pump();
      expect(
        tester.widget<FilledButton>(buttonFinder).onPressed,
        isNull,
        reason: 'button must disable itself while memorizing is in flight',
      );

      await pumpUntilAsyncSettled(tester,
          finalPump: const Duration(milliseconds: 500));
      await tester.pump();

      final verses = await tester.runAsync(() => dbHelper.getVerses());
      expect(verses!.single.isMemorized, isTrue);
    },
  );

  testWidgets(
    'restores keyboard focus to the Memorize button if the action fails, '
    'leaving the button in place',
    (tester) async {
      final dbHelper = DatabaseHelper();
      final provider = VerseProvider(dbHelper);
      await tester.runAsync(() async {
        await dbHelper.insertVerse(makeVerse('verse-0', isMemorized: false));
        await provider.loadVerses();
      });

      await tester.pumpWidget(_wrap(provider));
      await tester.pump();
      await tester.tap(find.text('Available'));
      await tester.pumpAndSettle();

      final buttonFinder = find.descendant(
        of: find.byKey(const Key('memorize-button-verse-0')),
        matching: find.byType(FilledButton),
      );

      // Give the button keyboard focus first, as a keyboard user would
      // (Tab to it, then Enter/Space to activate).
      final focusNode = tester.widget<FilledButton>(buttonFinder).focusNode!;
      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      // Drop the `verses` table out from under the live connection so the
      // update inside the memorize action throws, leaving the verse (and
      // its button) in place.
      await tester.runAsync(() async {
        final db = await dbHelper.database;
        await db.execute('DROP TABLE verses');
      });

      final onPressed = tester.widget<FilledButton>(buttonFinder).onPressed!;
      onPressed();
      await tester.pump();
      expect(
        focusNode.hasFocus,
        isFalse,
        reason: 'disabling the button during the async op clears its focus',
      );

      await pumpUntilAsyncSettled(tester,
          finalPump: const Duration(milliseconds: 500));
      await tester.pump();

      expect(
        buttonFinder,
        findsOneWidget,
        reason: 'the failed action must not remove the verse from the list',
      );
      expect(
        focusNode.hasFocus,
        isTrue,
        reason: 'focus should return to the button after a failed action',
      );
    },
  );
}
