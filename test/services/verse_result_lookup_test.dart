import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/models/test_result.dart';
import 'package:bible_flashcards/services/verse_result_lookup.dart';

import '../helpers/fake_database_helper.dart';
import '../helpers/verse_factory.dart';

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

  test('resolves each result\'s verse and omits deleted verses from the map',
      () async {
    await DatabaseHelper().insertVerse(makeVerse('a', reference: 'A 1:1'));
    final results = [
      VerseTestResult(
        verseId: 'a',
        accuracy: 1.0,
        testMode: 'review',
        testFormat: 'type',
        testedAt: DateTime(2024, 1, 1),
      ),
      VerseTestResult(
        verseId: 'gone',
        accuracy: 1.0,
        testMode: 'review',
        testFormat: 'type',
        testedAt: DateTime(2024, 1, 1),
      ),
    ];

    final versesById =
        await resolveVersesForResults(results, DatabaseHelper());

    expect(versesById['a']?.reference, 'A 1:1');
    expect(versesById.containsKey('gone'), isFalse);
  });
}
