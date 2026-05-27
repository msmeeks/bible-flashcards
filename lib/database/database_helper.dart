import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/test_result.dart';
import '../models/verse.dart';

class DatabaseHelper {
  static const _dbName = 'bible_flashcards.db';
  static const _dbVersion = 1;

  // Preference key for the stored encryption seed.
  // TODO: Replace with Android Keystore-backed key derivation for production.
  static const _prefKeyDbSeed = 'db_encryption_seed_v1';

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
  /// TODO: Migrate seed storage to Android Keystore for hardware-backed security.
  Future<String> _encryptionKey() async {
    final prefs = await SharedPreferences.getInstance();
    var seed = prefs.getString(_prefKeyDbSeed);
    if (seed == null) {
      // Generate a fresh 32-byte random seed on first run.
      final rng = Random.secure();
      final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
      seed = base64Url.encode(bytes);
      await prefs.setString(_prefKeyDbSeed, seed);
    }
    // Derive the SQLCipher key via SHA-256 to normalise length/encoding.
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
      final verses = pack['verses'] as List<dynamic>;
      for (final v in verses) {
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
