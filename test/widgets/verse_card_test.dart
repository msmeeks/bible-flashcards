import 'package:bible_flashcards/models/verse.dart';
import 'package:bible_flashcards/theme/app_theme.dart';
import 'package:bible_flashcards/widgets/verse_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Verse _verse({
  bool memorized = false,
  bool verseOfWeek = false,
  String text = 'For God so loved the world.',
}) =>
    Verse(
      id: 'esv_john_3_16',
      reference: 'John 3:16',
      text: text,
      translation: 'ESV',
      packId: 'nav_tms_part1',
      isMemorized: memorized,
      isVerseOfWeek: verseOfWeek,
      addedAt: DateTime.utc(2024, 1, 1),
    );

Widget _wrap(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );
}

Future<void> _pump(WidgetTester tester) async {
  // Two pumps: one to process setState, one to process zero-duration frames.
  await tester.pump();
  await tester.pump();
}

void main() {
  group('FlashcardState cycling', () {
    testWidgets('default state shows reference chip label', (tester) async {
      await tester.pumpWidget(_wrap(VerseCard(verse: _verse())));
      await _pump(tester);
      expect(find.text('John 3:16'), findsAtLeastNWidgets(1));
    });

    testWidgets('tap cycles referenceOnly → textOnly', (tester) async {
      await tester.pumpWidget(_wrap(VerseCard(verse: _verse())));
      await _pump(tester);

      await tester.tap(find.byType(InkWell).first);
      await _pump(tester);

      // textOnly: verse text should be visible
      expect(find.text('For God so loved the world.'), findsAtLeastNWidgets(1));
    });

    testWidgets('second tap flips back to referenceOnly, never both',
        (tester) async {
      await tester.pumpWidget(_wrap(VerseCard(verse: _verse())));
      await _pump(tester);

      await tester.tap(find.byType(InkWell).first);
      await _pump(tester);
      await tester.tap(find.byType(InkWell).first);
      await _pump(tester);

      expect(find.text('John 3:16'), findsAtLeastNWidgets(1));
      expect(find.text('For God so loved the world.'), findsNothing);
    });

    testWidgets('tapping from the combined view collapses to referenceOnly',
        (tester) async {
      await tester.pumpWidget(
          _wrap(VerseCard(verse: _verse(), initialState: FlashcardState.both)));
      await _pump(tester);

      await tester.tap(find.byType(InkWell).first);
      await _pump(tester);

      expect(find.text('John 3:16'), findsAtLeastNWidgets(1));
      expect(find.text('For God so loved the world.'), findsNothing);
    });

    testWidgets('long press reveals reference and text together',
        (tester) async {
      await tester.pumpWidget(_wrap(VerseCard(verse: _verse())));
      await _pump(tester);

      await tester.longPress(find.byType(InkWell).first);
      await _pump(tester);

      expect(find.text('John 3:16'), findsAtLeastNWidgets(1));
      expect(find.text('For God so loved the world.'), findsAtLeastNWidgets(1));
    });

    testWidgets('long press again returns to referenceOnly', (tester) async {
      await tester.pumpWidget(_wrap(VerseCard(verse: _verse())));
      await _pump(tester);

      await tester.longPress(find.byType(InkWell).first);
      await _pump(tester);
      await tester.longPress(find.byType(InkWell).first);
      await _pump(tester);

      expect(find.text('For God so loved the world.'), findsNothing);
    });

    testWidgets('initialState=both shows reference and text immediately',
        (tester) async {
      await tester.pumpWidget(
          _wrap(VerseCard(verse: _verse(), initialState: FlashcardState.both)));
      await _pump(tester);

      expect(find.text('John 3:16'), findsAtLeastNWidgets(1));
      expect(find.text('For God so loved the world.'), findsAtLeastNWidgets(1));
    });
  });

  group('Verse text rendering', () {
    testWidgets('long verse text is not truncated', (tester) async {
      const longText =
          'For God so loved the world, that he gave his only Son, that '
          'whoever believes in him should not perish but have eternal life. '
          'For God did not send his Son into the world to condemn the world, '
          'but in order that the world might be saved through him.';
      await tester.pumpWidget(_wrap(VerseCard(
        verse: _verse(text: longText),
        initialState: FlashcardState.both,
      )));
      await _pump(tester);

      final text = tester.widget<Text>(find.text(longText));
      expect(text.maxLines, isNull);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
    });
  });

  group('Status chip label', () {
    testWidgets('available verse shows Available chip', (tester) async {
      await tester.pumpWidget(_wrap(VerseCard(verse: _verse())));
      await _pump(tester);
      expect(find.text('Available'), findsOneWidget);
    });

    testWidgets('memorized verse shows Memorized chip', (tester) async {
      await tester.pumpWidget(_wrap(VerseCard(verse: _verse(memorized: true))));
      await _pump(tester);
      expect(find.text('Memorized'), findsOneWidget);
    });

    testWidgets('verse-of-week shows This Week chip', (tester) async {
      await tester
          .pumpWidget(_wrap(VerseCard(verse: _verse(verseOfWeek: true))));
      await _pump(tester);
      expect(find.text('This Week'), findsOneWidget);
    });
  });

  group('confidenceFuture', () {
    testWidgets('resolves to weak accuracy shows Weak chip', (tester) async {
      await tester.pumpWidget(_wrap(VerseCard(
        verse: _verse(memorized: true),
        confidenceFuture: Future.value(0.5),
      )));
      await tester.pump();
      await tester.pump();
      expect(find.text('Weak'), findsOneWidget);
      expect(find.text('Memorized'), findsNothing);
    });
  });

  group('Semantics', () {
    testWidgets('outer semantics is a button with label containing status',
        (tester) async {
      await tester.pumpWidget(_wrap(VerseCard(verse: _verse())));
      await _pump(tester);

      final semantics = tester.getSemantics(find.byType(VerseCard));
      expect(semantics.label, contains('Available'));
      expect(semantics.label, contains('John 3:16'));
    });

    testWidgets('label offers long press as the route to the combined view',
        (tester) async {
      await tester.pumpWidget(_wrap(VerseCard(verse: _verse())));
      await _pump(tester);

      final semantics = tester.getSemantics(find.byType(VerseCard));
      expect(semantics.label, contains('Tap to reveal text'));
      expect(semantics.label, contains('long press'));
    });

    testWidgets('label never tells the user tapping shows both', (tester) async {
      await tester.pumpWidget(_wrap(VerseCard(verse: _verse())));
      await _pump(tester);
      await tester.tap(find.byType(InkWell).first);
      await _pump(tester);

      final semantics = tester.getSemantics(find.byType(VerseCard));
      expect(semantics.label, contains('Tap to show reference'));
      expect(semantics.label, isNot(contains('Tap to show reference and text')));
    });

    testWidgets('combined view label describes long press to collapse',
        (tester) async {
      await tester.pumpWidget(
          _wrap(VerseCard(verse: _verse(), initialState: FlashcardState.both)));
      await _pump(tester);

      final semantics = tester.getSemantics(find.byType(VerseCard));
      expect(semantics.label, contains('long press'));
    });
  });
}
