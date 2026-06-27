import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/test_result.dart';
import '../models/verse.dart';
import '../utils/book_name_variants.dart'
    show bookDisplayNames, maxCustomVariants, maxVariantLength, normalizeBookNameKey;

class DatabaseHelper {
  static const _dbName = 'bible_flashcards.db';
  static const _dbVersion = 3;

  static const _secureKeyDbSeed = 'db_encryption_seed_v1';
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  static const _validEventTypes = {'flashcard_tap', 'test_complete'};
  static bool? _trackingEnabled;

  /// Call after the user changes their activity-tracking consent preference.
  static void invalidateTrackingCache() => _trackingEnabled = null;

  static DatabaseHelper? _instance;
  // Stores the open Future so concurrent callers share one initialization.
  static Future<Database>? _dbFuture;

  DatabaseHelper._();

  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._();
    return _instance!;
  }

  Future<Database> get database => _dbFuture ??= _openDatabase();

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    await database;
  }

  Future<Database> _openDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);
    final key = await _encryptionKey();

    return openDatabase(
      path,
      version: _dbVersion,
      password: key,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Derives a deterministic encryption key from a per-install random seed.
  /// The seed is stored in Android Keystore / iOS Keychain via flutter_secure_storage,
  /// making it hardware-bound and inaccessible to other apps or unencrypted backups.
  Future<String> _encryptionKey() async {
    var seed = await _secureStorage.read(key: _secureKeyDbSeed);
    if (seed == null) {
      final rng = Random.secure();
      final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
      seed = base64Url.encode(bytes);
      await _secureStorage.write(key: _secureKeyDbSeed, value: seed);
    }
    final digest = sha256.convert(utf8.encode(seed));
    return digest.toString();
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
    await _seedNavigatorPack(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.transaction((txn) async {
        await txn.execute('''
          CREATE TABLE packs (
            id          TEXT PRIMARY KEY,
            name        TEXT NOT NULL CHECK(length(name) <= 200),
            description TEXT NOT NULL DEFAULT '',
            verse_ids   TEXT NOT NULL DEFAULT '[]'
          )
        ''');
        final jsonStr =
            await rootBundle.loadString('assets/packs/navigators_pack.json');
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        for (final packRaw in data['packs'] as List<dynamic>) {
          final pack = packRaw as Map<String, dynamic>;
          final verseIds = (pack['verses'] as List<dynamic>)
              .map((v) => (v as Map<String, dynamic>)['id'] as String)
              .toList();
          await txn.insert(
            'packs',
            {
              'id': pack['id'] as String,
              'name': pack['name'] as String,
              'description': (pack['description'] as String?) ?? '',
              'verse_ids': jsonEncode(verseIds),
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      });
      await _createEngagementLogTable(db);
    }
    if (oldVersion < 3) {
      await _createBookNameVariantsTable(db);
    }
  }

  Future<void> _createBookNameVariantsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS book_name_variants (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        book_code    TEXT NOT NULL CHECK(length(book_code) <= 10),
        variant_text TEXT NOT NULL CHECK(length(variant_text) <= 60),
        UNIQUE(book_code, variant_text)
      )
    ''');
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE packs (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL CHECK(length(name) <= 200),
        description TEXT NOT NULL DEFAULT '',
        verse_ids   TEXT NOT NULL DEFAULT '[]'
      )
    ''');

    await db.execute('''
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
    ''');

    await db.execute('''
      CREATE TABLE test_results (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        verse_id    TEXT NOT NULL,
        accuracy    REAL NOT NULL,
        test_mode   TEXT NOT NULL,
        test_format TEXT NOT NULL,
        tested_at   TEXT NOT NULL,
        FOREIGN KEY (verse_id) REFERENCES verses (id)
      )
    ''');

    await _createEngagementLogTable(db);
    await _createBookNameVariantsTable(db);
  }

  Future<void> _createEngagementLogTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS engagement_log (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        date       TEXT NOT NULL,
        event_type TEXT NOT NULL,
        count      INTEGER NOT NULL DEFAULT 1,
        UNIQUE(date, event_type)
      )
    ''');
  }

  // ---------------------------------------------------------------------------
  // Seed data
  // ---------------------------------------------------------------------------

  Future<void> _seedNavigatorPack(Database db) async {
    final jsonStr =
        await rootBundle.loadString('assets/packs/navigators_pack.json');
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final packs = data['packs'] as List<dynamic>;
    final now = DateTime.now().toIso8601String();

    final batch = db.batch();
    for (final pack in packs.cast<Map<String, dynamic>>()) {
      final verses = pack['verses'] as List<dynamic>;
      batch.insert(
        'packs',
        {
          'id': pack['id'] as String,
          'name': pack['name'] as String,
          'description': (pack['description'] as String?) ?? '',
          'verse_ids': jsonEncode(verses
              .map((v) => (v as Map<String, dynamic>)['id'] as String)
              .toList()),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      for (final v in verses.cast<Map<String, dynamic>>()) {
        batch.insert(
          'verses',
          {
            'id': v['id'] as String,
            'reference': v['reference'] as String,
            'text': v['text'] as String,
            'translation': v['translation'] as String,
            'pack_id': v['pack_id'] as String,
            'is_memorized': 0,
            'is_verse_of_week': 0,
            'memorized_at': null,
            'added_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    await batch.commit(noResult: true);
  }

  // ---------------------------------------------------------------------------
  // Pack name lookup
  // ---------------------------------------------------------------------------

  Future<Map<String, String>> getPackNames() async {
    final db = await database;
    final rows = await db.query('packs', columns: ['id', 'name']);
    return {for (final r in rows) r['id'] as String: r['name'] as String};
  }

  // ---------------------------------------------------------------------------
  // Verse CRUD
  // ---------------------------------------------------------------------------

  Future<List<Verse>> getVerses() async {
    final db = await database;
    final rows = await db.query('verses', orderBy: 'added_at ASC');
    return rows.map(Verse.fromMap).toList();
  }

  Future<Verse?> getVerseById(String id) async {
    final db = await database;
    final rows = await db.query(
      'verses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Verse.fromMap(rows.first);
  }

  Future<void> insertVerse(Verse verse) async {
    final db = await database;
    await db.insert(
      'verses',
      verse.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Inserts an ESV verse, enforcing Crossway's 500-verse storage cap
  /// atomically inside a transaction to prevent double-save races.
  Future<void> insertEsvVerse(Verse verse, {int cap = 500}) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.rawQuery(
        "SELECT COUNT(*) AS c FROM verses WHERE translation = 'ESV'",
      );
      final count = rows.first['c'] as int;
      if (count >= cap) {
        throw const EsvVerseCapExceededException('ESV verse limit reached (500).');
      }
      await txn.insert(
        'verses',
        verse.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    });
  }

  Future<void> updateVerse(Verse verse) async {
    final db = await database;
    await db.update(
      'verses',
      verse.toMap(),
      where: 'id = ?',
      whereArgs: [verse.id],
    );
  }

  // ---------------------------------------------------------------------------
  // Pack import
  // ---------------------------------------------------------------------------

  /// Imports verses from a JSON pack map in a single transaction.
  ///
  /// Expected shape: `{ "verses": [ { "id", "reference", "text", "translation",
  /// "pack_id" }, ... ] }`. Rows that fail validation or conflict are skipped.
  Future<int> importPackFromJson(Map<String, dynamic> packJson) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    int imported = 0;

    await db.transaction((txn) async {
      final verses = packJson['verses'];
      if (verses is! List) return;

      for (final v in verses) {
        if (v is! Map<String, dynamic>) continue;

        final id = v['id'] as String?;
        final reference = v['reference'] as String?;
        final text = v['text'] as String?;
        final translation = v['translation'] as String?;
        final packId = v['pack_id'] as String?;

        if (id == null || reference == null || text == null ||
            translation == null || packId == null) {
          continue;
        }
        if (reference.length > 100 || text.length > 2000) continue;
        if (id.length > 100 || translation.length > 20 || packId.length > 100) continue;
        if (id.isEmpty || translation.isEmpty || packId.isEmpty) continue;

        final rows = await txn.insert(
          'verses',
          {
            'id': id,
            'reference': reference,
            'text': text,
            'translation': translation,
            'pack_id': packId,
            'is_memorized': 0,
            'is_verse_of_week': 0,
            'memorized_at': null,
            'added_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (rows > 0) imported++;
      }
    });

    return imported;
  }

  // ---------------------------------------------------------------------------
  // Test results
  // ---------------------------------------------------------------------------

  Future<List<VerseTestResult>> getTestResults() async {
    final db = await database;
    final rows = await db.query('test_results', orderBy: 'tested_at DESC');
    return rows.map(VerseTestResult.fromMap).toList();
  }

  Future<void> insertTestResult(VerseTestResult result) async {
    final db = await database;
    await db.insert('test_results', result.toMap());
  }

  Future<void> clearTestHistory() async {
    final db = await database;
    await db.delete('test_results');
  }

  // ---------------------------------------------------------------------------
  // Engagement log
  // ---------------------------------------------------------------------------

  Future<void> logEngagement(String eventType) async {
    if (!_validEventTypes.contains(eventType)) return;
    // Cache the preference; reset via invalidateTrackingCache() on consent change.
    _trackingEnabled ??= (await SharedPreferences.getInstance())
        .getBool('engagement_tracking_enabled') ?? true;
    if (!_trackingEnabled!) return;

    final db = await database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await db.rawInsert(
      'INSERT INTO engagement_log (date, event_type, count) VALUES (?, ?, 1) '
      'ON CONFLICT(date, event_type) DO UPDATE SET count = count + 1',
      [today, eventType],
    );
    // Keep table bounded; 90-day window is sufficient for streak/chart features.
    final cutoff = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 90)));
    await db.delete('engagement_log', where: 'date < ?', whereArgs: [cutoff]);
  }

  Future<void> clearEngagementLog() async {
    final db = await database;
    await db.delete('engagement_log');
  }

  Future<List<Map<String, Object?>>> getEngagementLog() async {
    final db = await database;
    return db.query('engagement_log', orderBy: 'date ASC');
  }

  // ---------------------------------------------------------------------------
  // Custom book-name variants (#30)
  // ---------------------------------------------------------------------------

  /// Returns all stored custom variants as `{id, book_code, variant_text}` rows.
  Future<List<Map<String, Object?>>> getBookNameVariants() async {
    final db = await database;
    return db.query('book_name_variants', orderBy: 'book_code ASC, variant_text ASC');
  }

  /// Adds a custom (book code, variant text) pair. Throws [ArgumentError] if
  /// [bookCode] is unrecognized, [variantText] is empty/too long, the pair
  /// is a duplicate, or the per-user variant cap is already reached (data
  /// minimization).
  Future<void> addBookNameVariant(String bookCode, String variantText) async {
    if (!bookDisplayNames.containsKey(bookCode)) {
      throw ArgumentError('Unrecognized book code: $bookCode');
    }
    final trimmed = variantText.trim();
    if (trimmed.isEmpty || trimmed.length > maxVariantLength) {
      throw ArgumentError('Variant text must be 1-$maxVariantLength characters.');
    }
    final db = await database;
    await db.transaction((txn) async {
      final countResult =
          await txn.rawQuery('SELECT COUNT(*) AS c FROM book_name_variants');
      final count = countResult.first['c'] as int;
      if (count >= maxCustomVariants) {
        throw ArgumentError('Maximum of $maxCustomVariants custom variants reached.');
      }
      final rowId = await txn.insert(
        'book_name_variants',
        {'book_code': bookCode, 'variant_text': trimmed},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      if (rowId == 0) {
        throw ArgumentError('That variant has already been added for this book.');
      }
    });
  }

  Future<void> removeBookNameVariant(int id) async {
    final db = await database;
    await db.delete('book_name_variants', where: 'id = ?', whereArgs: [id]);
  }

  /// Builds a normalized-key → USFM-code lookup map for scoring, merging all
  /// stored custom variants on top of the built-in table (without mutating it).
  Future<Map<String, String>> getCustomVariantLookup() async {
    final rows = await getBookNameVariants();
    return {
      for (final row in rows)
        normalizeBookNameKey(row['variant_text'] as String):
            row['book_code'] as String,
    };
  }

  Future<List<Map<String, Object?>>> getTestResultsRaw() async {
    final db = await database;
    return db.query('test_results', orderBy: 'tested_at DESC');
  }

  Future<double?> getLatestVerseAccuracy(String verseId) async {
    final db = await database;
    final rows = await db.query(
      'test_results',
      columns: ['accuracy'],
      where: 'verse_id = ?',
      whereArgs: [verseId],
      orderBy: 'tested_at DESC',
      limit: 5,
    );
    if (rows.isEmpty) return null;
    final avg = rows.map((r) => r['accuracy'] as double).reduce((a, b) => a + b) / rows.length;
    return avg;
  }

  // Atomically clears memorized status and erases test history — satisfies GDPR data erasure on unmark.
  Future<void> unmarkMemorizedVerse(Verse updatedVerse) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'verses',
        updatedVerse.toMap(),
        where: 'id = ?',
        whereArgs: [updatedVerse.id],
      );
      await txn.delete(
        'test_results',
        where: 'verse_id = ?',
        whereArgs: [updatedVerse.id],
      );
    });
  }
}

/// Thrown by [DatabaseHelper.insertEsvVerse] when Crossway's 500-verse
/// storage cap is reached. DB-layer exception, not the service-layer
/// [LookupException] used by lookup network calls.
class EsvVerseCapExceededException implements Exception {
  const EsvVerseCapExceededException(this.message);
  final String message;

  @override
  String toString() => message;
}
