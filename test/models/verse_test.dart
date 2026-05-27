import 'package:bible_flashcards/models/verse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final baseDate = DateTime.utc(2024, 1, 15, 10, 30);
  final memorizedDate = DateTime.utc(2024, 2, 20, 8, 0);

  Verse baseVerse({bool memorized = false, DateTime? memorizedAt}) => Verse(
        id: 'esv_john_3_16',
        reference: 'John 3:16',
        text: 'For God so loved the world.',
        translation: 'ESV',
        packId: 'navigators_topical',
        isMemorized: memorized,
        memorizedAt: memorizedAt,
        addedAt: baseDate,
      );

  group('Verse.toMap', () {
    test('non-memorized verse encodes booleans as integers', () {
      final map = baseVerse().toMap();
      expect(map['is_memorized'], 0);
      expect(map['is_verse_of_week'], 0);
    });

    test('memorized verse encodes is_memorized as 1', () {
      final map = baseVerse(memorized: true, memorizedAt: memorizedDate).toMap();
      expect(map['is_memorized'], 1);
    });

    test('null memorizedAt is stored as null (not a string)', () {
      final map = baseVerse().toMap();
      expect(map['memorized_at'], isNull);
    });

    test('non-null memorizedAt is stored as ISO 8601 string', () {
      final map = baseVerse(memorized: true, memorizedAt: memorizedDate).toMap();
      expect(map['memorized_at'], memorizedDate.toIso8601String());
    });

    test('addedAt serialized as ISO 8601 string', () {
      final map = baseVerse().toMap();
      expect(map['added_at'], baseDate.toIso8601String());
    });

    test('all required fields present', () {
      final map = baseVerse().toMap();
      for (final key in ['id', 'reference', 'text', 'translation', 'pack_id', 'added_at']) {
        expect(map.containsKey(key), isTrue, reason: 'missing key: $key');
      }
    });
  });

  group('Verse.fromMap', () {
    test('round-trip: toMap then fromMap produces equal fields', () {
      final original = baseVerse(memorized: true, memorizedAt: memorizedDate);
      final map = original.toMap();
      final restored = Verse.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.reference, original.reference);
      expect(restored.text, original.text);
      expect(restored.translation, original.translation);
      expect(restored.packId, original.packId);
      expect(restored.isMemorized, original.isMemorized);
      expect(restored.isVerseOfWeek, original.isVerseOfWeek);
      expect(restored.memorizedAt, original.memorizedAt);
      expect(restored.addedAt, original.addedAt);
    });

    test('is_memorized = 0 → isMemorized = false', () {
      final v = Verse.fromMap({
        'id': 'x',
        'reference': 'Ps 23:1',
        'text': 'The Lord is my shepherd.',
        'translation': 'ESV',
        'pack_id': 'nav',
        'is_memorized': 0,
        'is_verse_of_week': 0,
        'memorized_at': null,
        'added_at': baseDate.toIso8601String(),
      });
      expect(v.isMemorized, isFalse);
    });

    test('is_memorized = 1 → isMemorized = true', () {
      final v = Verse.fromMap({
        'id': 'x',
        'reference': 'Ps 23:1',
        'text': 'The Lord is my shepherd.',
        'translation': 'ESV',
        'pack_id': 'nav',
        'is_memorized': 1,
        'is_verse_of_week': 0,
        'memorized_at': memorizedDate.toIso8601String(),
        'added_at': baseDate.toIso8601String(),
      });
      expect(v.isMemorized, isTrue);
    });

    test('null is_memorized defaults to false (SQLite optional field)', () {
      final v = Verse.fromMap({
        'id': 'x',
        'reference': 'Ps 23:1',
        'text': 'The Lord is my shepherd.',
        'translation': 'ESV',
        'pack_id': 'nav',
        'is_memorized': null,
        'is_verse_of_week': null,
        'memorized_at': null,
        'added_at': baseDate.toIso8601String(),
      });
      expect(v.isMemorized, isFalse);
      expect(v.isVerseOfWeek, isFalse);
    });

    test('null memorized_at → memorizedAt is null', () {
      final v = Verse.fromMap({
        'id': 'x',
        'reference': 'Ps 23:1',
        'text': 'The Lord is my shepherd.',
        'translation': 'ESV',
        'pack_id': 'nav',
        'is_memorized': 0,
        'is_verse_of_week': 0,
        'memorized_at': null,
        'added_at': baseDate.toIso8601String(),
      });
      expect(v.memorizedAt, isNull);
    });
  });

  group('Verse.copyWith', () {
    test('unset fields retain original values', () {
      final v = baseVerse(memorized: true, memorizedAt: memorizedDate);
      final copy = v.copyWith(reference: 'John 3:17');
      expect(copy.id, v.id);
      expect(copy.isMemorized, v.isMemorized);
      expect(copy.memorizedAt, v.memorizedAt);
    });

    test('clearMemorizedAt=true sets memorizedAt to null', () {
      final v = baseVerse(memorized: true, memorizedAt: memorizedDate);
      final copy = v.copyWith(clearMemorizedAt: true);
      expect(copy.memorizedAt, isNull);
    });

    test('clearMemorizedAt=false (default) preserves memorizedAt', () {
      final v = baseVerse(memorized: true, memorizedAt: memorizedDate);
      final copy = v.copyWith(isMemorized: false);
      expect(copy.memorizedAt, memorizedDate);
    });
  });
}
