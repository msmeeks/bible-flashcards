import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/models/verse.dart';
import 'package:bible_flashcards/providers/verse_provider.dart';
import 'package:bible_flashcards/screens/review/review_screen.dart';
import 'package:bible_flashcards/screens/review/review_show_screen.dart';

Verse _verse(String id, {bool isMemorized = true, bool isVerseOfWeek = false}) {
  return Verse(
    id: id,
    reference: 'Ref $id',
    text: 'Text $id',
    translation: 'ESV',
    packId: 'pack1',
    isMemorized: isMemorized,
    isVerseOfWeek: isVerseOfWeek,
    addedAt: DateTime(2024, 1, 1),
  );
}

Widget _wrap(VerseProvider provider) {
  return ChangeNotifierProvider<VerseProvider>.value(
    value: provider,
    child: const MaterialApp(home: ReviewScreen()),
  );
}

void main() {
  testWidgets('shows empty state when there are no memorized verses',
      (tester) async {
    final provider = VerseProvider(DatabaseHelper());
    provider.debugSetVerses([]);

    await tester.pumpWidget(_wrap(provider));

    expect(find.text('No memorized verses yet'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('shows count slider, verse-of-week toggle, and format selector',
      (tester) async {
    final provider = VerseProvider(DatabaseHelper());
    provider.debugSetVerses(List.generate(7, (i) => _verse('v$i')));

    await tester.pumpWidget(_wrap(provider));

    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Include verse of the week'), findsOneWidget);
    expect(find.text('Show'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('Start pushes ReviewShowScreen with the drawn verse list',
      (tester) async {
    final provider = VerseProvider(DatabaseHelper());
    provider.debugSetVerses(List.generate(7, (i) => _verse('v$i')));

    await tester.pumpWidget(_wrap(provider));

    await tester.tap(find.widgetWithText(FilterChip, '5'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    final show = tester.widget<ReviewShowScreen>(find.byType(ReviewShowScreen));
    expect(show.verses.length, 5);
  });
}
