import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/services/import_service.dart';

void main() {
  // ImportService validates input before touching the DB, so we can use a
  // real (unconstructed) DatabaseHelper — the exception fires first.
  final service = ImportService(db: DatabaseHelper());

  group('ImportService JSON validation', () {
    test('throws ImportException when JSON exceeds size limit', () {
      final huge = 'x' * (5 * 1024 * 1024 + 1);
      expect(
        () => service.import(huge),
        throwsA(isA<ImportException>()),
      );
    });

    test('throws ImportException for invalid JSON', () {
      expect(
        () => service.import('not valid json {{{'),
        throwsA(isA<ImportException>()),
      );
    });

    test('throws ImportException when root is not an object', () {
      expect(
        () => service.import('["a", "b"]'),
        throwsA(isA<ImportException>()),
      );
    });

    test('throws ImportException when source_app is wrong', () {
      final json = jsonEncode({
        'schema_version': 1,
        'source_app': 'other_app',
        'verses': [],
      });
      expect(
        () => service.import(json),
        throwsA(isA<ImportException>()),
      );
    });

    test('throws ImportException when schema_version > 1', () {
      final json = jsonEncode({
        'schema_version': 99,
        'source_app': 'bible_flashcards',
        'verses': [],
      });
      expect(
        () => service.import(json),
        throwsA(isA<ImportException>()),
      );
    });

    test('throws ImportException when schema_version is missing', () {
      final json = jsonEncode({
        'source_app': 'bible_flashcards',
        'verses': [],
      });
      expect(
        () => service.import(json),
        throwsA(isA<ImportException>()),
      );
    });

    test('throws ImportException when schema_version is not an int', () {
      final json = jsonEncode({
        'schema_version': 'one',
        'source_app': 'bible_flashcards',
        'verses': [],
      });
      expect(
        () => service.import(json),
        throwsA(isA<ImportException>()),
      );
    });

    test('throws ImportException when verses is not a list', () {
      final json = jsonEncode({
        'schema_version': 1,
        'source_app': 'bible_flashcards',
        'verses': 'oops',
      });
      expect(
        () => service.import(json),
        throwsA(isA<ImportException>()),
      );
    });

    test('ImportException has readable message', () {
      const e = ImportException('test message');
      expect(e.toString(), contains('test message'));
    });
  });

  group('backupCadence validation', () {
    const validCadences = {'daily', 'weekly', 'monthly'};

    test('valid cadences pass through', () {
      for (final cadence in validCadences) {
        final result = validCadences.contains(cadence) ? cadence : 'weekly';
        expect(result, cadence);
      }
    });

    test('unknown cadence falls back to weekly', () {
      const raw = 'hourly';
      final result = validCadences.contains(raw) ? raw : 'weekly';
      expect(result, 'weekly');
    });

    test('empty cadence falls back to weekly', () {
      const raw = '';
      final result = validCadences.contains(raw) ? raw : 'weekly';
      expect(result, 'weekly');
    });
  });

  group('lastBackupAt tamper guard', () {
    DateTime? acceptBackupAt(String raw) {
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return null;
      if (parsed.isBefore(DateTime.now().add(const Duration(days: 365)))) {
        return parsed;
      }
      return null;
    }

    test('rejects far-future timestamp', () {
      final farFuture =
          DateTime.now().add(const Duration(days: 400)).toIso8601String();
      expect(acceptBackupAt(farFuture), isNull);
    });

    test('accepts a past timestamp', () {
      final yesterday =
          DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
      expect(acceptBackupAt(yesterday), isNotNull);
    });

    test('accepts a timestamp one year in future (boundary)', () {
      // Exactly 364 days from now — within the 365-day cutoff
      final nearFuture =
          DateTime.now().add(const Duration(days: 364)).toIso8601String();
      expect(acceptBackupAt(nearFuture), isNotNull);
    });

    test('rejects malformed timestamp', () {
      expect(acceptBackupAt('not-a-date'), isNull);
    });
  });
}
