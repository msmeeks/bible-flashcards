import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/screens/settings/book_variants_screen.dart';

import '../../helpers/fake_database_helper.dart';

/// Pumps [BookVariantsScreen] and lets the initial `getBookNameVariants`
/// FutureBuilder resolve (its spinner animates forever, so this must happen
/// inside `runAsync` before any `pumpAndSettle`).
Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(const MaterialApp(home: BookVariantsScreen()));
    await tester.pump();
    // Real (wall-clock) gap so the sqflite_common_ffi round-trip resolves;
    // a fake-clock `pump(Duration)` would not advance the real async work.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await tester.pump();
  });
  await tester.pump();
}

/// Opens the Add dialog, selects Genesis, and types [variant] — leaving the
/// dialog ready to submit.
Future<void> _openAddDialogWithInput(
  WidgetTester tester,
  String variant,
) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();

  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Genesis').last);
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextFormField), variant);
  await tester.pump();
}

/// Drives the pending sqflite round-trip to completion (mirrors the
/// `_tapAndSettle` pattern used in the Add Verse screen tests).
Future<void> _drainAsync(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 500));
  });
  await tester.pump();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpFakeDatabase();
  });

  tearDown(() async {
    await tearDownFakeDatabase();
  });

  testWidgets(
    'Add button disables and shows a spinner while the variant save is in flight',
    (tester) async {
      await _pumpScreen(tester);
      await _openAddDialogWithInput(tester, 'Gen');

      // Tap Add without runAsync: the sqflite round-trip stays pending, so the
      // dialog is frozen mid-submission.
      final addButton = find.widgetWithText(FilledButton, 'Add');
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pump();

      // While in flight the Add button is disabled and shows a spinner...
      final filled =
          tester.widget<FilledButton>(find.byType(FilledButton));
      expect(filled.onPressed, isNull,
          reason: 'Add button must be disabled while submitting');
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
        reason: 'a loading spinner must be shown while submitting',
      );

      // ...and Cancel is disabled too, so it cannot race the in-flight pop.
      final cancel =
          tester.widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'));
      expect(cancel.onPressed, isNull,
          reason: 'Cancel must be disabled while submitting');

      // Let the pending save finish so no async work leaks past the test.
      await _drainAsync(tester);
    },
  );

  testWidgets(
    'rapid double-tap on Add adds only one variant and does not throw',
    (tester) async {
      await _pumpScreen(tester);
      await _openAddDialogWithInput(tester, 'Gen');

      // Invoke the handler twice back-to-back within the same frame (before
      // any rebuild can disable the button), simulating a double-tap that
      // races ahead of the isSubmitting-driven `onPressed: null` state.
      final onPressed =
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Add'))
              .onPressed!;
      onPressed();
      onPressed();
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'a rapid double-tap must not throw');

      await _drainAsync(tester);
      expect(tester.takeException(), isNull);

      final variants = await tester.runAsync(
        () => DatabaseHelper().getBookNameVariants(),
      );
      expect(variants, hasLength(1),
          reason: 'only one variant should be added per double-tap');
    },
  );
}
