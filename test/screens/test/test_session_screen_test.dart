import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bible_flashcards/models/verse.dart';
import 'package:bible_flashcards/screens/test/test_enums.dart';
import 'package:bible_flashcards/screens/test/test_session_screen.dart';

Verse _verse() => Verse(
      id: 'john_3_16',
      reference: 'John 3:16',
      text: 'For God so loved the world',
      translation: 'ESV',
      packId: 'pack_1',
      addedAt: DateTime(2024, 1, 1),
    );

/// Finds diff tokens with [op] rendering [word]. Diff keys carry their
/// position (`diff-<i>-<op>-<word>`) because a verse may repeat a word, so
/// this matches on op+word and lets the caller assert the count.
Finder diffToken(String op, String word) => find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.key is ValueKey<String> &&
          RegExp('^diff-\\d+-$op-${RegExp.escape(word)}\$')
              .hasMatch((w.key as ValueKey<String>).value),
      description: '$op diff token "$word"',
    );

void main() {
  // Prompt is the reference, so the answer is the verse text — the diff's
  // real use case.
  Widget wrapType(Verse verse) => MaterialApp(
        home: TestSessionScreen(
          verses: [verse],
          testMode: TestMode.review,
          selectedFormats: const {TestFormat.type},
          selectedDirections: const {PromptDirection.refToText},
        ),
      );

  Future<void> checkAnswer(WidgetTester tester, String answer) async {
    await tester.enterText(find.byKey(const Key('type-answer-field')), answer);
    await tester.tap(find.byKey(const Key('type-check-button')));
    await tester.pump();
  }

  group('Type-mode word diff (#162)', () {
    testWidgets('a perfect answer renders every source word plainly',
        (tester) async {
      await tester.pumpWidget(wrapType(_verse()));
      await tester.pump();

      await checkAnswer(tester, 'For God so loved the world');

      expect(find.byKey(const Key('type-answer-diff')), findsOneWidget);
      for (final word in ['For', 'God', 'so', 'loved', 'the', 'world']) {
        expect(diffToken('match', word), findsOneWidget);
      }
      expect(find.byKey(const Key('type-answer-diff-legend')), findsNothing);
    });

    testWidgets(
        'a missed source word renders struck through, not by colour '
        'alone', (tester) async {
      await tester.pumpWidget(wrapType(_verse()));
      await tester.pump();

      await checkAnswer(tester, 'For God so the world');

      final missed = tester.widget<Text>(diffToken('delete', 'loved'));
      expect(missed.style?.decoration, TextDecoration.lineThrough);
      // A legend spells the cue out in words, so the meaning survives even
      // if the strikethrough itself is missed.
      expect(
        find.byKey(const Key('type-answer-diff-legend')),
        findsOneWidget,
      );
      expect(find.textContaining('1 missed (struck through)'), findsOneWidget);
    });

    testWidgets('an extra typed word renders underlined, not by colour alone',
        (tester) async {
      await tester.pumpWidget(wrapType(_verse()));
      await tester.pump();

      await checkAnswer(tester, 'For God truly so loved the world');

      final extra = tester.widget<Text>(diffToken('insert', 'truly'));
      expect(extra.style?.decoration, TextDecoration.underline);
    });

    testWidgets(
        'a mixed answer renders matches, a deletion and an insertion '
        'together', (tester) async {
      await tester.pumpWidget(wrapType(_verse()));
      await tester.pump();

      await checkAnswer(tester, 'For God so hated the world');

      expect(diffToken('match', 'For'), findsOneWidget);
      expect(diffToken('delete', 'loved'), findsOneWidget);
      expect(diffToken('insert', 'hated'), findsOneWidget);
    });

    testWidgets(
        'missed and extra words are announced to screen readers, so '
        'the distinction is not carried by colour', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrapType(_verse()));
      await tester.pump();

      await checkAnswer(tester, 'For God so hated the world');

      expect(find.bySemanticsLabel('Missing word: loved'), findsOneWidget);
      expect(find.bySemanticsLabel('Extra word: hated'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the diff uses theme tokens rather than hard-coded colours',
        (tester) async {
      await tester.pumpWidget(wrapType(_verse()));
      await tester.pump();

      await checkAnswer(tester, 'For God so hated the world');

      final context = tester.element(find.byKey(const Key('type-answer-diff')));
      final cs = Theme.of(context).colorScheme;
      expect(
        tester.widget<Text>(diffToken('delete', 'loved')).style?.color,
        cs.error,
      );
      expect(
        tester.widget<Text>(diffToken('match', 'For')).style?.color,
        cs.onSurface,
      );
    });
  });

  // Real verses repeat words constantly ("the", "is", "and"). Keying diff
  // tokens by word alone throws "Duplicate keys found" and replaces the
  // whole answer area with a red error box — found by running the app.
  testWidgets(
      'a verse repeating a word renders the diff without a '
      'duplicate-key crash', (tester) async {
    final repeats = Verse(
      id: '2cor_5_17',
      reference: '2 Corinthians 5:17',
      text: 'Therefore, if anyone is in Christ, he is a new creation. The '
          'old has passed away; behold, the new has come.',
      translation: 'ESV',
      packId: 'pack_1',
      addedAt: DateTime(2024, 1, 1),
    );

    await tester.pumpWidget(wrapType(repeats));
    await tester.pump();

    await checkAnswer(
      tester,
      'Therefore if anyone is in Christ he is a brand new creation',
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('type-answer-diff')), findsOneWidget);
    // "is" appears twice in the source and twice in the answer: both must
    // render, rather than one clobbering the other.
    expect(diffToken('match', 'is'), findsNWidgets(2));
  });

  // The default 800px test surface hides overflow that real ~360dp phones
  // hit; this iteration has already shipped two such defects.
  testWidgets(
      'the diff of a long verse lays out at a 375px viewport without '
      'overflowing', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final long = Verse(
      id: 'rom_8_28',
      reference: 'Romans 8:28',
      text: 'And we know that all things work together for good to them that '
          'love God to them who are the called according to his purpose',
      translation: 'ESV',
      packId: 'pack_1',
      addedAt: DateTime(2024, 1, 1),
    );

    await tester.pumpWidget(wrapType(long));
    await tester.pump();

    // Every word wrong: maximal token count, legend present, worst case.
    await checkAnswer(tester, 'completely different words entirely here now');

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('type-answer-diff')), findsOneWidget);
    expect(find.byKey(const Key('type-answer-diff-legend')), findsOneWidget);
  });

  // The score canonicalizes a recognized book-name variant before comparing
  // (#30); the diff must use that same comparable text, or a 100% answer
  // renders with words marked missed and extra.
  testWidgets(
      'a recognized book abbreviation scores 100% and shows a diff '
      'that agrees with it', (tester) async {
    final verse = Verse(
      id: '1thess_5_19',
      reference: '1 Thessalonians 5:19',
      text: 'Do not quench the Spirit',
      translation: 'ESV',
      packId: 'pack_1',
      addedAt: DateTime(2024, 1, 1),
    );
    await tester.pumpWidget(MaterialApp(
      home: TestSessionScreen(
        verses: [verse],
        testMode: TestMode.review,
        selectedFormats: const {TestFormat.type},
        selectedDirections: const {PromptDirection.textToRef},
      ),
    ));
    await tester.pump();

    // "1 Thess" resolves to the same book as "1 Thessalonians", so the
    // score forgives it — the diff must not contradict that.
    await checkAnswer(tester, '1 Thess 5:19');

    expect(find.text('100%'), findsOneWidget);
    expect(diffToken('delete', 'Thessalonians'), findsNothing);
    expect(diffToken('insert', 'Thess'), findsNothing);
    expect(find.byKey(const Key('type-answer-diff-legend')), findsNothing);
  });

  group('Type-mode advance (#166)', () {
    Verse second() => Verse(
          id: 'rom_8_28',
          reference: 'Romans 8:28',
          text: 'And we know that all things work together for good',
          translation: 'ESV',
          packId: 'pack_1',
          addedAt: DateTime(2024, 1, 1),
        );

    Widget wrapTwo() => MaterialApp(
          home: TestSessionScreen(
            verses: [_verse(), second()],
            testMode: TestMode.review,
            selectedFormats: const {TestFormat.type},
            selectedDirections: const {PromptDirection.refToText},
          ),
        );

    testWidgets(
        'checking reveals the score and stays put — no timer '
        'advances the session', (tester) async {
      await tester.pumpWidget(wrapTwo());
      await tester.pump();
      expect(find.text('Verse 1 of 2'), findsOneWidget);

      await checkAnswer(tester, 'For God so loved the world');
      expect(find.text('100%'), findsOneWidget);

      // The old behavior advanced ~1s after scoring. Wait well past that:
      // the session must not move on its own.
      await tester.pump(const Duration(seconds: 5));

      expect(find.text('Verse 1 of 2'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.byKey(const Key('type-next-button')), findsOneWidget);
    });

    testWidgets('Next advances to the following verse', (tester) async {
      await tester.pumpWidget(wrapTwo());
      await tester.pump();

      await checkAnswer(tester, 'For God so loved the world');
      await tester.tap(find.byKey(const Key('type-next-button')));
      await tester.pump();

      expect(find.text('Verse 2 of 2'), findsOneWidget);
      expect(find.text('Romans 8:28'), findsOneWidget);
      // The next verse starts clean: no stale score or diff.
      expect(find.text('100%'), findsNothing);
      expect(find.byKey(const Key('type-answer-diff')), findsNothing);
      expect(find.byKey(const Key('type-check-button')), findsOneWidget);
    });

    testWidgets('Next is absent until an answer has been checked',
        (tester) async {
      await tester.pumpWidget(wrapTwo());
      await tester.pump();

      expect(find.byKey(const Key('type-next-button')), findsNothing);
      expect(find.byKey(const Key('type-check-button')), findsOneWidget);
    });

    testWidgets('a double-tapped Next records the verse only once',
        (tester) async {
      await tester.pumpWidget(wrapTwo());
      await tester.pump();

      await checkAnswer(tester, 'For God so loved the world');

      // Two taps in the same frame — the second must be a no-op, or the
      // session would record verse 1 twice and skip verse 2.
      final next = find.byKey(const Key('type-next-button'));
      await tester.tap(next, warnIfMissed: false);
      await tester.tap(next, warnIfMissed: false);
      await tester.pump();

      expect(find.text('Verse 2 of 2'), findsOneWidget);
    });

    testWidgets('Next is a ≥48dp FilledButton and takes focus on reveal',
        (tester) async {
      await tester.pumpWidget(wrapTwo());
      await tester.pump();

      await checkAnswer(tester, 'For God so loved the world');
      await tester.pump();

      final next = find.byKey(const Key('type-next-button'));
      expect(
        tester.widget(next),
        isA<FilledButton>(),
        reason: 'a forward action is a FilledButton per the Action Pairs rule',
      );
      expect(tester.getSize(next).height, greaterThanOrEqualTo(48));
      expect(
        tester.widget<FilledButton>(next).focusNode?.hasFocus,
        isTrue,
        reason: 'focus must land on the only forward action after reveal',
      );
    });
  });

  Widget wrapFillBlank(Verse verse) => MaterialApp(
        home: TestSessionScreen(
          verses: [verse],
          testMode: TestMode.review,
          selectedFormats: const {TestFormat.fillBlank},
          selectedDirections: const {PromptDirection.textToRef},
        ),
      );

  testWidgets(
    'fill-blank renders at least one real blank for a 2-token reference',
    (tester) async {
      await tester.pumpWidget(wrapFillBlank(_verse()));
      await tester.pump();

      expect(find.byType(TextField), findsAtLeastNWidgets(1));
    },
  );

  testWidgets(
    'fill-blank fields show no visible label and carry a numbered '
    'accessible name for screen readers',
    (tester) async {
      await tester.pumpWidget(wrapFillBlank(_verse()));
      await tester.pump();

      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields, isNotEmpty);
      final total = fields.length;
      for (var i = 0; i < total; i++) {
        expect(fields.elementAt(i).decoration?.labelText, isNull);
        expect(
          find.bySemanticsLabel('Blank ${i + 1} of $total'),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets(
    'after checking, no "Correct" or "Incorrect —" text is shown',
    (tester) async {
      await tester.pumpWidget(wrapFillBlank(_verse()));
      await tester.pump();

      await tester.tap(find.text('Check Answer'));
      await tester.pump();

      expect(find.text('Correct'), findsNothing);
      expect(find.textContaining('Incorrect —'), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    },
  );

  Verse referenceVerse() => Verse(
        id: '1thess_5_19',
        reference: '1 Thessalonians 5:19',
        text: 'Do not quench the Spirit',
        translation: 'ESV',
        packId: 'pack_1',
        addedAt: DateTime(2024, 1, 1),
      );

  testWidgets(
    'a blank landing inside the reference book-name span accepts a '
    'recognized abbreviation',
    (tester) async {
      // Tokens of '1 Thessalonians 5:19' are ['1','Thessalonians','5',':','19'];
      // index 1 is the book-name word.
      await tester.pumpWidget(MaterialApp(
        home: TestSessionScreen(
          verses: [referenceVerse()],
          testMode: TestMode.review,
          selectedFormats: const {TestFormat.fillBlank},
          selectedDirections: const {PromptDirection.textToRef},
          debugBlankIndices: const [1],
        ),
      ));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Thess');
      await tester.tap(find.text('Check Answer'));
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.errorText, isNull);
    },
  );

  testWidgets(
    'typed text remains visible in a blank after checking, and clears on '
    'retry',
    (tester) async {
      await tester.pumpWidget(wrapFillBlank(_verse()));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'wrong');
      await tester.tap(find.text('Check Answer'));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'wrong',
      );

      await tester.tap(find.text('Try Again'));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'a correctly-answered blank announces "Correct" for screen readers',
    (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: TestSessionScreen(
          verses: [_verse()],
          testMode: TestMode.review,
          selectedFormats: const {TestFormat.fillBlank},
          selectedDirections: const {PromptDirection.textToRef},
          debugBlankIndices: const [0],
        ),
      ));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'John');
      await tester.tap(find.text('Check Answer'));
      await tester.pump();

      expect(find.bySemanticsLabel('Correct'), findsOneWidget);
    },
  );

  Verse longVerse() => Verse(
        id: 'rom_8_28',
        reference: 'Romans 8:28',
        text: 'And we know that all things work together for good to them '
            'that love God to them who are the called according to his purpose',
        translation: 'ESV',
        packId: 'pack_1',
        addedAt: DateTime(2024, 1, 1),
      );

  Widget wrapFillBlankWithDensity(Verse verse, BlankDensity density) =>
      MaterialApp(
        home: TestSessionScreen(
          // Forces a fresh State (and thus a fresh initState blank-count
          // computation) each time this test re-pumps with a new density —
          // otherwise Flutter would reuse the existing element/state since
          // the widget type and tree position are unchanged.
          key: ValueKey(density),
          verses: [verse],
          testMode: TestMode.review,
          selectedFormats: const {TestFormat.fillBlank},
          selectedDirections: const {PromptDirection.refToText},
          blankDensity: density,
        ),
      );

  testWidgets(
    'a higher blank density selection produces more blank fields',
    (tester) async {
      await tester.pumpWidget(
        wrapFillBlankWithDensity(longVerse(), BlankDensity.twenty),
      );
      await tester.pump();
      final lowCount =
          tester.widgetList<TextField>(find.byType(TextField)).length;

      await tester.pumpWidget(
        wrapFillBlankWithDensity(longVerse(), BlankDensity.seventyFive),
      );
      await tester.pump();
      final highCount =
          tester.widgetList<TextField>(find.byType(TextField)).length;

      expect(highCount, greaterThan(lowCount));
    },
  );
}
