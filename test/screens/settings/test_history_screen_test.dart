import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/models/test_result.dart';
import 'package:bible_flashcards/screens/settings/test_history_screen.dart';

import '../../helpers/async_settle.dart';
import '../../helpers/fake_database_helper.dart';
import '../../helpers/verse_factory.dart';

Widget _wrap() {
  return const MaterialApp(home: TestHistoryScreen());
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
      await tester.runAsync(() async {
        await dbHelper.insertVerse(
          makeVerse('esv_romans_2_2', reference: 'Romans 2:2'),
        );
        await dbHelper.insertTestResult(
          VerseTestResult(
            verseId: 'esv_romans_2_2',
            accuracy: 1.0,
            testMode: 'review',
            testFormat: 'type',
            testedAt: DateTime(2024, 1, 1, 9),
          ),
        );
      });

      await tester.pumpWidget(_wrap());
      await pumpUntilAsyncSettled(tester);

      expect(find.text('Romans 2:2'), findsOneWidget);
      expect(find.text('esv_romans_2_2'), findsNothing);
    },
  );

  testWidgets(
    'labels a fill-blank result as "Fill Blanks"',
    (tester) async {
      final dbHelper = DatabaseHelper();
      await tester.runAsync(() async {
        await dbHelper.insertVerse(
          makeVerse('esv_romans_2_2', reference: 'Romans 2:2'),
        );
        await dbHelper.insertTestResult(
          VerseTestResult(
            verseId: 'esv_romans_2_2',
            accuracy: 1.0,
            testMode: 'review',
            testFormat: 'fillBlank',
            testedAt: DateTime(2024, 1, 1, 9),
          ),
        );
      });

      await tester.pumpWidget(_wrap());
      await pumpUntilAsyncSettled(tester);

      expect(find.textContaining('Fill Blanks'), findsOneWidget);
    },
  );

  testWidgets(
    'Clear Test History confirmation uses OutlinedButton for Cancel, '
    'keeping the error-colored FilledButton for the destructive action',
    (tester) async {
      final dbHelper = DatabaseHelper();
      await tester.runAsync(() async {
        await dbHelper.insertVerse(
          makeVerse('esv_romans_2_2', reference: 'Romans 2:2'),
        );
        await dbHelper.insertTestResult(
          VerseTestResult(
            verseId: 'esv_romans_2_2',
            accuracy: 1.0,
            testMode: 'review',
            testFormat: 'type',
            testedAt: DateTime(2024, 1, 1, 9),
          ),
        );
      });

      await tester.pumpWidget(_wrap());
      await pumpUntilAsyncSettled(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Clear History'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Clear'), findsOneWidget);
    },
  );
}
