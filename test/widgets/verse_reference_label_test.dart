import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bible_flashcards/widgets/verse_reference_label.dart';

import '../helpers/verse_factory.dart';

void main() {
  testWidgets('shows the verse\'s stored reference when the verse exists',
      (tester) async {
    final verse = makeVerse('a', reference: 'Romans 2:2');

    await tester.pumpWidget(MaterialApp(
      home: VerseReferenceLabel(verse: verse, verseId: 'a'),
    ));

    expect(find.text('Romans 2:2'), findsOneWidget);
  });

  testWidgets(
      'shows an italic "(verse deleted)" fallback with the raw id when null',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: VerseReferenceLabel(verse: null, verseId: 'esv_gone_1_1'),
    ));

    final textWidget =
        tester.widget<Text>(find.text('esv_gone_1_1 (verse deleted)'));

    expect(textWidget.style?.fontStyle, FontStyle.italic);
  });
}
