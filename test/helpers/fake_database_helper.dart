import 'package:bible_flashcards/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _packsSchema = '''
  CREATE TABLE packs (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    verse_ids   TEXT NOT NULL DEFAULT '[]'
  )
''';

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

const _bookNameVariantsSchema = '''
  CREATE TABLE book_name_variants (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    book_code    TEXT NOT NULL,
    variant_text TEXT NOT NULL,
    UNIQUE(book_code, variant_text)
  )
''';

/// Opens an in-memory sqflite_common_ffi database with the minimal schema
/// (packs/verses/book_name_variants) needed to exercise
/// [DatabaseHelper.insertVerse]/`insertEsvVerse`/`getVerses`/`getPackNames`/
/// `getCustomVariantLookup` without platform channels, then injects it via
/// [DatabaseHelper.debugSetDatabase]. Call `sqfliteFfiInit()` once in
/// `setUpAll` before using this.
Future<void> setUpFakeDatabase() async {
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute(_packsSchema);
        await db.execute(_versesSchema);
        await db.execute(_bookNameVariantsSchema);
      },
    ),
  );
  DatabaseHelper.debugSetDatabase(db);
}

Future<void> tearDownFakeDatabase() async {
  final db = await DatabaseHelper().database;
  await db.close();
  DatabaseHelper.debugReset();
}
