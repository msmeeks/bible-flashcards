import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/providers/verse_provider.dart';
import 'package:bible_flashcards/screens/verses/verse_detail_screen.dart';

import '../../helpers/fake_database_helper.dart';
import '../../helpers/verse_factory.dart';

Widget _wrap(VerseProvider provider, String verseId) {
  return ChangeNotifierProvider<VerseProvider>.value(
    value: provider,
    child: MaterialApp(home: VerseDetailScreen(verseId: verseId)),
  );
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
    'shows the verse translation as read-only text, not an interactive selector',
    (tester) async {
      final dbHelper = DatabaseHelper();
      final provider = VerseProvider(dbHelper);
      await tester.runAsync(() async {
        await dbHelper.insertVerse(
          makeVerse('verse-1', translation: 'CSB'),
        );
        await provider.loadVerses();
      });

      await tester.pumpWidget(_wrap(provider, 'verse-1'));
      await tester.pumpAndSettle();

      expect(find.byType(SegmentedButton<String>), findsNothing);
      expect(find.text('CSB'), findsWidgets);
    },
  );
}
