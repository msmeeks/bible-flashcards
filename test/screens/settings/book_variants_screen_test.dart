import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/screens/settings/book_variants_screen.dart';

import '../../helpers/async_settle.dart';
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
      final filled = tester.widget<FilledButton>(find.byType(FilledButton));
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
      final cancel = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Cancel'));
      expect(cancel.onPressed, isNull,
          reason: 'Cancel must be disabled while submitting');

      // Let the pending save finish so no async work leaks past the test.
      await pumpUntilAsyncSettled(tester,
          finalPump: const Duration(milliseconds: 500));
      await tester.pump();
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
      final onPressed = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add'))
          .onPressed!;
      onPressed();
      onPressed();
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'a rapid double-tap must not throw');

      await pumpUntilAsyncSettled(tester,
          finalPump: const Duration(milliseconds: 500));
      await tester.pump();
      expect(tester.takeException(), isNull);

      final variants = await tester.runAsync(
        () => DatabaseHelper().getBookNameVariants(),
      );
      expect(variants, hasLength(1),
          reason: 'only one variant should be added per double-tap');
    },
  );

  testWidgets(
    'submitting with no book selected shows a validation error and adds nothing',
    (tester) async {
      await _pumpScreen(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Gen');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pump();

      expect(find.text('Select a book.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget,
          reason: 'dialog must stay open on validation failure');

      final variants = await tester.runAsync(
        () => DatabaseHelper().getBookNameVariants(),
      );
      expect(variants, isEmpty);
    },
  );

  testWidgets(
    'submitting with empty variant text shows a validation error and adds nothing',
    (tester) async {
      await _pumpScreen(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Genesis').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pump();

      expect(find.text('Enter a variant.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget,
          reason: 'dialog must stay open on validation failure');

      final variants = await tester.runAsync(
        () => DatabaseHelper().getBookNameVariants(),
      );
      expect(variants, isEmpty);
    },
  );

  testWidgets(
    'a duplicate variant surfaces the DB error, keeps the dialog open, and '
    'resets the submitting state',
    (tester) async {
      await tester.runAsync(
        () => DatabaseHelper().addBookNameVariant('GEN', 'Gen'),
      );

      await _pumpScreen(tester);
      await _openAddDialogWithInput(tester, 'Gen');

      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pump();
      await pumpUntilAsyncSettled(tester,
          finalPump: const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget,
          reason: 'dialog must stay open when the save throws');
      expect(
        find.text('That variant has already been added for this book.'),
        findsOneWidget,
      );

      final filled = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Add'),
      );
      expect(filled.onPressed, isNotNull,
          reason: 'submitting state must reset so Add is usable again');

      final variants = await tester.runAsync(
        () => DatabaseHelper().getBookNameVariants(),
      );
      expect(variants, hasLength(1),
          reason: 'the failed duplicate add must not create a second row');
    },
  );

  testWidgets(
    'Cancel closes the dialog without adding a variant',
    (tester) async {
      await _pumpScreen(tester);
      await _openAddDialogWithInput(tester, 'Gen');

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);

      final variants = await tester.runAsync(
        () => DatabaseHelper().getBookNameVariants(),
      );
      expect(variants, isEmpty);
    },
  );

  testWidgets(
    'removing a variant deletes it and reloads the list',
    (tester) async {
      await tester.runAsync(
        () => DatabaseHelper().addBookNameVariant('GEN', 'Gen'),
      );

      await _pumpScreen(tester);
      expect(find.text('Gen'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.delete_outline_rounded));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      });
      await tester.pump();

      expect(find.text('Gen'), findsNothing);
      final variants = await tester.runAsync(
        () => DatabaseHelper().getBookNameVariants(),
      );
      expect(variants, isEmpty);
    },
  );

  testWidgets(
    'renders the empty-state message when there are no custom variants',
    (tester) async {
      await _pumpScreen(tester);

      expect(find.textContaining('No custom variants yet'), findsOneWidget);
    },
  );

  testWidgets(
    'a blocked dismiss attempt while submitting keeps the dialog present',
    (tester) async {
      await _pumpScreen(tester);
      await _openAddDialogWithInput(tester, 'Gen');

      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget,
          reason: 'a blocked dismiss attempt must not close the dialog');

      await pumpUntilAsyncSettled(tester,
          finalPump: const Duration(milliseconds: 500));
      await tester.pump();
    },
  );

  testWidgets(
    'a normal dismiss (Cancel, not submitting) does not announce',
    (tester) async {
      final accessibilityEvents = <Map<Object?, Object?>>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
        SystemChannels.accessibility,
        (message) async {
          accessibilityEvents.add(message as Map<Object?, Object?>);
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler(SystemChannels.accessibility, null);
      });

      await _pumpScreen(tester);
      await _openAddDialogWithInput(tester, 'Gen');

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        accessibilityEvents.where((e) => e['type'] == 'announce'),
        isEmpty,
        reason: 'a normal dismiss must not trigger an announcement',
      );
    },
  );

  testWidgets(
    'announces once when a dismiss attempt is blocked while submitting',
    (tester) async {
      final accessibilityEvents = <Map<Object?, Object?>>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
        SystemChannels.accessibility,
        (message) async {
          accessibilityEvents.add(message as Map<Object?, Object?>);
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler(SystemChannels.accessibility, null);
      });

      await _pumpScreen(tester);
      await _openAddDialogWithInput(tester, 'Gen');

      final addButton = find.widgetWithText(FilledButton, 'Add');
      await tester.tap(addButton);
      await tester.pump();

      // Attempt to dismiss via system back while the save is in flight.
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(
        accessibilityEvents.where((e) => e['type'] == 'announce'),
        hasLength(1),
        reason: 'a blocked dismiss attempt must announce exactly once',
      );

      // A second blocked attempt in the same in-flight window must not
      // announce again mid-rebuild (only once per attempt).
      await tester.pump();
      expect(
        accessibilityEvents.where((e) => e['type'] == 'announce'),
        hasLength(1),
      );

      await pumpUntilAsyncSettled(tester,
          finalPump: const Duration(milliseconds: 500));
      await tester.pump();
    },
  );
}
