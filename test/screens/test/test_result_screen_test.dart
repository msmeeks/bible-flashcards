import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/models/test_result.dart';
import 'package:bible_flashcards/screens/test/test_result_screen.dart';

import '../../helpers/async_settle.dart';
import '../../helpers/fake_database_helper.dart';
import '../../helpers/verse_factory.dart';

Widget _wrap(TestSessionResult result) {
  return MaterialApp(home: TestResultScreen(sessionResult: result));
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
    'shows the verse\'s stored reference for a custom verse id',
    (tester) async {
      final dbHelper = DatabaseHelper();
      await tester.runAsync(() => dbHelper.insertVerse(
            makeVerse('esv_romans_2_2', reference: 'Romans 2:2'),
          ));

      final sessionResult = TestSessionResult(
        sessionAt: DateTime(2024, 1, 1),
        verseResults: [
          VerseTestResult(
            verseId: 'esv_romans_2_2',
            accuracy: 1.0,
            testMode: 'review',
            testFormat: 'type',
            testedAt: DateTime(2024, 1, 1),
          ),
        ],
      );

      await tester.pumpWidget(_wrap(sessionResult));
      await pumpUntilAsyncSettled(tester);

      expect(find.text('Romans 2:2'), findsOneWidget);
      expect(find.text('esv_romans_2_2'), findsNothing);
    },
  );

  testWidgets(
    'shows a deleted-verse fallback when the verse id has no matching verse',
    (tester) async {
      final sessionResult = TestSessionResult(
        sessionAt: DateTime(2024, 1, 1),
        verseResults: [
          VerseTestResult(
            verseId: 'esv_gone_1_1',
            accuracy: 1.0,
            testMode: 'review',
            testFormat: 'type',
            testedAt: DateTime(2024, 1, 1),
          ),
        ],
      );

      await tester.pumpWidget(_wrap(sessionResult));
      await pumpUntilAsyncSettled(tester);

      expect(find.text('esv_gone_1_1 (verse deleted)'), findsOneWidget);
    },
  );

  // Recite was removed in #165, but rows written before that still say
  // "recite". They must render rather than crash on the unknown format.
  testWidgets(
    'renders a legacy "recite" result without error, falling back to the '
    'stored string as its label',
    (tester) async {
      final dbHelper = DatabaseHelper();
      await tester.runAsync(() => dbHelper.insertVerse(
            makeVerse('esv_romans_2_2', reference: 'Romans 2:2'),
          ));

      final sessionResult = TestSessionResult(
        sessionAt: DateTime(2024, 1, 1),
        verseResults: [
          VerseTestResult(
            verseId: 'esv_romans_2_2',
            accuracy: 1.0,
            testMode: 'review',
            testFormat: 'recite',
            testedAt: DateTime(2024, 1, 1),
          ),
        ],
      );

      await tester.pumpWidget(_wrap(sessionResult));
      await pumpUntilAsyncSettled(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Romans 2:2'), findsOneWidget);
      expect(find.textContaining('recite'), findsOneWidget);
    },
  );
}
