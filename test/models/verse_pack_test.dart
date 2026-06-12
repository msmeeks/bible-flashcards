import 'dart:convert';

import 'package:bible_flashcards/models/verse_pack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VersePack.toMap / fromMap', () {
    const base = VersePack(
      id: 'p1',
      name: 'Nav Part 1',
      description: 'desc',
      verseIds: ['v1', 'v2', 'v3'],
    );

    test('round-trip preserves all fields', () {
      final restored = VersePack.fromMap(base.toMap());
      expect(restored.id, base.id);
      expect(restored.name, base.name);
      expect(restored.description, base.description);
      expect(restored.verseIds, base.verseIds);
    });

    test('verse_ids stored as JSON array, not CSV', () {
      final raw = base.toMap()['verse_ids'] as String;
      expect(raw, startsWith('['));
      expect(jsonDecode(raw), ['v1', 'v2', 'v3']);
    });

    test('empty verseIds serializes and deserializes to empty list', () {
      const pack =
          VersePack(id: 'p1', name: 'N', description: '', verseIds: []);
      expect(VersePack.fromMap(pack.toMap()).verseIds, isEmpty);
    });

    test('single verseId survives round-trip', () {
      const pack = VersePack(
          id: 'p1', name: 'N', description: '', verseIds: ['only']);
      expect(VersePack.fromMap(pack.toMap()).verseIds, ['only']);
    });

    test('fromMap with missing verse_ids key defaults to empty list', () {
      final map = {'id': 'p1', 'name': 'N', 'description': ''};
      expect(VersePack.fromMap(map).verseIds, isEmpty);
    });

    test('fromMap with legacy CSV verse_ids throws FormatException', () {
      // Old serialization was CSV — documents that it is NOT backward-compatible
      expect(
        () => VersePack.fromMap({
          'id': 'p1',
          'name': 'N',
          'description': '',
          'verse_ids': 'john_3_16,psalm_23_1',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('VersePack.copyWith', () {
    const base = VersePack(
      id: 'p1',
      name: 'Nav',
      description: 'desc',
      verseIds: ['v1'],
    );

    test('unset fields retain original values', () {
      final copy = base.copyWith(verseIds: ['v2', 'v3']);
      expect(copy.id, 'p1');
      expect(copy.name, 'Nav');
      expect(copy.description, 'desc');
      expect(copy.verseIds, ['v2', 'v3']);
    });
  });

  group('VersePack equality', () {
    test('equality uses only id', () {
      const a =
          VersePack(id: 'same', name: 'A', description: '', verseIds: []);
      const b =
          VersePack(id: 'same', name: 'B', description: '', verseIds: ['x']);
      expect(a, equals(b));
    });

    test('different ids are not equal', () {
      const a =
          VersePack(id: 'p1', name: 'A', description: '', verseIds: []);
      const b =
          VersePack(id: 'p2', name: 'A', description: '', verseIds: []);
      expect(a, isNot(equals(b)));
    });

    test('hashCode consistent with equality', () {
      const a =
          VersePack(id: 'same', name: 'A', description: '', verseIds: []);
      const b =
          VersePack(id: 'same', name: 'B', description: '', verseIds: ['x']);
      expect(a.hashCode, b.hashCode);
      expect({a, b}.length, 1);
    });
  });
}
