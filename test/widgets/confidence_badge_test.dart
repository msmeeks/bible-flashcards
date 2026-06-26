import 'package:bible_flashcards/theme/app_theme.dart';
import 'package:bible_flashcards/widgets/confidence_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    );

void main() {
  group('ConfidenceBadge', () {
    testWidgets('null accuracy shows Pending', (tester) async {
      await tester.pumpWidget(
          _wrap(const ConfidenceBadge(accuracy: null, verseRef: 'John 3:16')));
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('accuracy < 0.7 shows Weak', (tester) async {
      await tester.pumpWidget(
          _wrap(const ConfidenceBadge(accuracy: 0.5, verseRef: 'John 3:16')));
      expect(find.text('Weak'), findsOneWidget);
    });

    testWidgets('accuracy 0.7–0.89 shows Learning', (tester) async {
      await tester.pumpWidget(
          _wrap(const ConfidenceBadge(accuracy: 0.8, verseRef: 'John 3:16')));
      expect(find.text('Learning'), findsOneWidget);
    });

    testWidgets('accuracy >= 0.9 shows Strong', (tester) async {
      await tester.pumpWidget(
          _wrap(const ConfidenceBadge(accuracy: 0.95, verseRef: 'John 3:16')));
      expect(find.text('Strong'), findsOneWidget);
    });
  });
}
