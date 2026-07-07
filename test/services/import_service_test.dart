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

    test('throws ImportException when verses array exceeds max length', () {
      final json = jsonEncode({
        'schema_version': 1,
        'source_app': 'bible_flashcards',
        'verses': List.generate(50001, (_) => {}),
      });
      expect(
        () => service.import(json),
        throwsA(isA<ImportException>()),
      );
    });

    test('throws ImportException when test_results array exceeds max length',
        () {
      final json = jsonEncode({
        'schema_version': 1,
        'source_app': 'bible_flashcards',
        'verses': [],
        'test_results': List.generate(50001, (_) => {}),
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

}
