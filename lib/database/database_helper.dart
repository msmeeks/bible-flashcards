import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/test_result.dart';
import '../models/verse.dart';

class DatabaseHelper {
  static const _dbName = 'bible_flashcards.db';
  static const _dbVersion = 1;

  // Key stored in Android Keystore / iOS Keychain via flutter_secure_storage.
  static const _secureKeyDbSeed = 'db_encryption_seed_v1';
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

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
    // Future migrations: add ALTER TABLE / CREATE TABLE statements here,
    // gated by version comparisons, e.g. if (oldVersion < 2) { ... }
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
    for (final pack in packs) {
      final verses = (pack as Map<String, dynamic>)['verses'] as List<dynamic>;
      for (final vRaw in verses) {
        final v = vRaw as Map<String, dynamic>;
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
      conflictAlgorithm: ConflictAlgorithm.replace,
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
}
