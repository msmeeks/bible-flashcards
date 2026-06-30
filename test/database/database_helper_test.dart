import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/models/verse.dart';

import '../helpers/verse_factory.dart';

const _versesSchema = '''
  CREATE TABLE verses (
    id                TEXT PRIMARY KEY,
    reference         TEXT NOT NULL,
    text              TEXT NOT NULL,
    translation       TEXT NOT NULL,
    pack_id           TEXT NOT NULL,
    is_memorized      INTEGER NOT NULL DEFAULT 0,
    is_verse_of_week  INTEGER NOT NULL DEFAULT 0,
    memorized_at      TEXT,
    added_at          TEXT NOT NULL
  )
''';

Future<bool> _attemptInsert(Verse verse, {required int cap}) async {
  try {
    await DatabaseHelper().insertEsvVerse(verse, cap: cap);
    return true;
  } on EsvVerseCapExceededException {
    return false;
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async => db.execute(_versesSchema),
      ),
    );
    DatabaseHelper.debugSetDatabase(db);
  });

  tearDown(() async {
    final db = await DatabaseHelper().database;
    await db.close();
    DatabaseHelper.debugReset();
  });

  group('DatabaseHelper.insertEsvVerse', () {
    test('inserts successfully when under the cap', () async {
      await DatabaseHelper().insertEsvVerse(makeVerse('a'), cap: 2);

      final db = await DatabaseHelper().database;
      final rows = await db.query('verses');
      expect(rows, hasLength(1));
      expect(rows.first['id'], 'a');
    });

    test('throws EsvVerseCapExceededException when inserting at the cap',
        () async {
      await DatabaseHelper().insertEsvVerse(makeVerse('a'), cap: 1);

      expect(
        () => DatabaseHelper().insertEsvVerse(makeVerse('b'), cap: 1),
        throwsA(isA<EsvVerseCapExceededException>()),
      );
    });

    test('does not insert the row that would exceed the cap', () async {
      await DatabaseHelper().insertEsvVerse(makeVerse('a'), cap: 1);
      try {
        await DatabaseHelper().insertEsvVerse(makeVerse('b'), cap: 1);
      } on EsvVerseCapExceededException {
        // expected
      }

      final db = await DatabaseHelper().database;
      final rows = await db.query('verses');
      expect(rows, hasLength(1));
      expect(rows.first['id'], 'a');
    });

    test(
        'concurrent inserts at the cap boundary still respect the cap '
        '(TOCTOU-safe transaction)', () async {
      const cap = 2;
      // Pre-fill to cap-1 so exactly one of the next two concurrent inserts
      // must be rejected.
      await DatabaseHelper().insertEsvVerse(makeVerse('seed'), cap: cap);

      final results = await Future.wait([
        _attemptInsert(makeVerse('b'), cap: cap),
        _attemptInsert(makeVerse('c'), cap: cap),
      ]);

      expect(results.where((ok) => ok).length, 1);
      final db = await DatabaseHelper().database;
      final rows = await db.query('verses');
      expect(rows, hasLength(cap));
    });

    test('ignores conflicting id rather than throwing on duplicate insert',
        () async {
      await DatabaseHelper().insertEsvVerse(makeVerse('a'), cap: 5);
      await DatabaseHelper().insertEsvVerse(
        makeVerse('a', text: 'different text'),
        cap: 5,
      );

      final db = await DatabaseHelper().database;
      final rows = await db.query('verses');
      expect(rows, hasLength(1));
      expect(rows.first['text'], 'Text a');
    });
  });
}
