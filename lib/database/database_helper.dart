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

class DatabaseHelper {
  static const _dbName = 'bible_flashcards.db';
  static const _dbVersion = 2;

  static const _secureKeyDbSeed = 'db_encryption_seed_v1';
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  static const _validEventTypes = {'flashcard_tap', 'test_complete'};
  static bool? _trackingEnabled;

  /// Call after the user changes their activity-tracking consent preference.
  static void invalidateTrackingCache() => _trackingEnabled = null;

  static DatabaseHelper? _instance;
  static Database? _db;

  DatabaseHelper._();

  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._();
    return _instance!;
  }

  Future<Database> get database async {
    _db ??= await _openDatabase();
    return _db!;
  }

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
      await _createEngagementLogTable(db);
    }
  }

  Future<void> _createTables(Database db) async {
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
