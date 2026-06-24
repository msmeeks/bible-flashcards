import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../database/database_helper.dart';
import '../models/verse.dart';
import '../models/test_result.dart';

/// Thrown when an import file is invalid or unsupported.
class ImportException implements Exception {
  const ImportException(this.message);
  final String message;

  @override
  String toString() => 'ImportException: $message';
}

class ImportService {
  const ImportService({required DatabaseHelper db}) : _db = db;

  final DatabaseHelper _db;

  // Hard file-size cap in bytes — rejects multibyte-heavy files that pass char-count checks
  static const _maxBytes = 5 * 1024 * 1024;

  // Caps array length independent of the byte cap — a 5MB file of tiny,
  // deeply-nested or highly-repetitive entries could still cause excessive
  // allocation/parse work per row.
  static const _maxArrayLength = 50000;

  Future<ImportSummary> import(
    String jsonString, {
    bool replace = false,
  }) async {
    final bytes = utf8.encode(jsonString);
    if (bytes.length > _maxBytes) {
      throw const ImportException('File too large (max 5 MB)');
    }

    final dynamic raw;
    try {
      raw = jsonDecode(jsonString);
    } on FormatException catch (e) {
      throw ImportException('Invalid JSON: ${e.message}');
    }

    if (raw is! Map<String, dynamic>) {
      throw const ImportException('Expected a JSON object at root');
    }

    if (raw['source_app'] != 'bible_flashcards') {
      throw const ImportException(
          'File does not appear to be a Bible Flashcards backup');
    }

    final version = raw['schema_version'];
    if (version is! int) {
      throw const ImportException('Missing or invalid schema_version');
    }
    if (version > 1) {
      throw ImportException('File version $version is not supported by this app version');
    }

    final rawVerses = raw['verses'];
    if (rawVerses is! List) {
      throw const ImportException('Missing or invalid verses array');
    }
    if (rawVerses.length > _maxArrayLength) {
      throw const ImportException('Too many verses in file');
    }

    // Validate and coerce verses — skip invalid rows rather than aborting
    final verses = <Verse>[];
    for (final item in rawVerses) {
      if (item is! Map<String, dynamic>) continue;
      final text = item['text'];
      final ref = item['reference'];
      final id = item['id'];
      final translation = item['translation'];
      final packId = item['pack_id'];
      final addedAt = item['added_at'];
      if (text is! String || text.isEmpty || text.length > 2000) continue;
      if (ref is! String || ref.isEmpty || ref.length > 100) continue;
      if (id is! String || id.isEmpty || id.length > 100) continue;
      if (translation is! String || translation.isEmpty ||
          translation.length > 20) {
        continue;
      }
      if (packId is! String || packId.isEmpty || packId.length > 100) continue;
      if (addedAt is! String) continue;
      if (DateTime.tryParse(addedAt) == null) continue;
      verses.add(Verse.fromMap(item));
    }

    final rawResults = raw['test_results'];
    final results = <VerseTestResult>[];
    if (rawResults is List) {
      if (rawResults.length > _maxArrayLength) {
        throw const ImportException('Too many test results in file');
      }
      for (final item in rawResults) {
        if (item is! Map<String, dynamic>) continue;
        final verseId = item['verse_id'];
        final accuracy = item['accuracy'];
        final testMode = item['test_mode'];
        final testFormat = item['test_format'];
        final testedAt = item['tested_at'];
        if (verseId is! String || verseId.isEmpty || verseId.length > 100) {
          continue;
        }
        if (accuracy is! num || accuracy < 0 || accuracy > 1) continue;
        if (testMode is! String || testMode.length > 50) continue;
        if (testFormat is! String || testFormat.length > 50) continue;
        if (testedAt is! String || DateTime.tryParse(testedAt) == null) {
          continue;
        }
        results.add(VerseTestResult.fromMap(item));
      }
    }

    final db = await _db.database;
    await db.transaction((txn) async {
      if (replace) {
        await txn.delete('test_results');
        await txn.delete('verses');
      }
      for (final v in verses) {
        await txn.insert(
          'verses',
          v.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      for (final r in results) {
        await txn.insert(
          'test_results',
          r.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });

    return ImportSummary(versesImported: verses.length, resultsImported: results.length);
  }
}

class ImportSummary {
  const ImportSummary({
    required this.versesImported,
    required this.resultsImported,
  });

  final int versesImported;
  final int resultsImported;
}
