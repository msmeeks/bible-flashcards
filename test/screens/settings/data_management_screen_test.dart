import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bible_flashcards/screens/settings/data_management_screen.dart';

Widget _wrap() {
  return const MaterialApp(home: DataManagementScreen());
}

Future<void> _openDialog(WidgetTester tester, String tileTitle) async {
  await tester.pumpWidget(_wrap());
  await tester.pump();
  await tester.tap(find.text(tileTitle));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Export Data dialog uses OutlinedButton for Cancel, not a bare TextButton',
    (tester) async {
      await _openDialog(tester, 'Export Data');

      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Export'), findsOneWidget);
    },
  );

  testWidgets(
    'Save Locally dialog uses OutlinedButton for Cancel, not a bare TextButton',
    (tester) async {
      await _openDialog(tester, 'Save Locally');

      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Choose Location'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Import Data dialog uses OutlinedButton for Cancel, not a bare TextButton',
    (tester) async {
      await _openDialog(tester, 'Import Data');

      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Import'), findsOneWidget);
    },
  );

  testWidgets(
    'Replace All Data confirmation uses OutlinedButton for Cancel, keeping '
    'the error-colored FilledButton for the destructive action',
    (tester) async {
      await _openDialog(tester, 'Import Data');

      await tester.tap(find.text('Replace'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Replace All Data'));
      await tester.pumpAndSettle();

      expect(find.text('Replace All Data?'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsNothing);

      final replaceButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Replace All Data'),
      );
      final cs = Theme.of(tester.element(find.byType(DataManagementScreen)))
          .colorScheme;
      expect(
        replaceButton.style?.backgroundColor?.resolve(<WidgetState>{}),
        cs.error,
      );
    },
  );
}
