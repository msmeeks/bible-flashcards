import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bible_flashcards/models/verse.dart';
import 'package:bible_flashcards/screens/review/review_show_screen.dart';

Verse _verse(String id) {
  return Verse(
    id: id,
    reference: 'Ref $id',
    text: 'Text $id',
    translation: 'ESV',
    packId: 'pack1',
    isMemorized: true,
    addedAt: DateTime(2024, 1, 1),
  );
}

void main() {
  testWidgets('lists references and reveals text on tap', (tester) async {
    final verses = List.generate(3, (i) => _verse('v$i'));

    await tester.pumpWidget(
      MaterialApp(home: ReviewShowScreen(verses: verses)),
    );

    expect(find.text('Ref v0'), findsOneWidget);
    expect(find.text('Text v0'), findsNothing);

    await tester.tap(find.text('Ref v0'));
    await tester.pumpAndSettle();

    expect(find.text('Text v0'), findsOneWidget);
  });

  testWidgets('verse list stays fixed across a rebuild', (tester) async {
    final verses = List.generate(3, (i) => _verse('v$i'));

    await tester.pumpWidget(
      MaterialApp(home: ReviewShowScreen(verses: verses)),
    );
    await tester.pumpWidget(
      MaterialApp(home: ReviewShowScreen(verses: verses)),
    );

    expect(find.text('Ref v0'), findsOneWidget);
    expect(find.text('Ref v1'), findsOneWidget);
    expect(find.text('Ref v2'), findsOneWidget);
  });
}
