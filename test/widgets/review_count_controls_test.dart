import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bible_flashcards/widgets/review_count_controls.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('SectionLabel', () {
    testWidgets('renders its text', (tester) async {
      await tester.pumpWidget(_wrap(const SectionLabel('Number of verses')));

      expect(find.text('Number of verses'), findsOneWidget);
    });
  });

  group('ReviewCountControls', () {
    testWidgets('shows preset chips up to memorizedCount plus All',
        (tester) async {
      await tester.pumpWidget(_wrap(ReviewCountControls(
        count: 5,
        memorizedCount: 12,
        includeVerseOfWeek: true,
        onCountChanged: (_) {},
        onVowChanged: (_) {},
      )));

      expect(find.widgetWithText(FilterChip, '5'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, '10'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'All'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, '20'), findsNothing);
    });

    testWidgets('tapping a preset chip invokes onCountChanged',
        (tester) async {
      int? changedTo;
      await tester.pumpWidget(_wrap(ReviewCountControls(
        count: 5,
        memorizedCount: 12,
        includeVerseOfWeek: true,
        onCountChanged: (value) => changedTo = value,
        onVowChanged: (_) {},
      )));

      await tester.tap(find.widgetWithText(FilterChip, '10'));
      await tester.pump();

      expect(changedTo, 10);
    });

    testWidgets('toggling the verse-of-week switch invokes onVowChanged',
        (tester) async {
      bool? changedTo;
      await tester.pumpWidget(_wrap(ReviewCountControls(
        count: 5,
        memorizedCount: 12,
        includeVerseOfWeek: true,
        onCountChanged: (_) {},
        onVowChanged: (value) => changedTo = value,
      )));

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(changedTo, false);
    });

    testWidgets('shows "No memorized verses yet" when memorizedCount is 0',
        (tester) async {
      await tester.pumpWidget(_wrap(ReviewCountControls(
        count: 0,
        memorizedCount: 0,
        includeVerseOfWeek: true,
        onCountChanged: (_) {},
        onVowChanged: (_) {},
      )));

      expect(find.text('No memorized verses yet'), findsOneWidget);
    });
  });
}
