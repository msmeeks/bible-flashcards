import 'package:flutter_test/flutter_test.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/models/verse.dart';
import 'package:bible_flashcards/providers/verse_provider.dart';

Verse _verse(String id, {bool isMemorized = true, bool isVerseOfWeek = false}) {
  return Verse(
    id: id,
    reference: 'Ref $id',
    text: 'Text $id',
    translation: 'ESV',
    packId: 'pack1',
    isMemorized: isMemorized,
    isVerseOfWeek: isVerseOfWeek,
    addedAt: DateTime(2024, 1, 1),
  );
}

Verse _verseWithTranslation(String id, String translation) {
  return Verse(
    id: id,
    reference: 'Ref $id',
    text: 'Text $id',
    translation: translation,
    packId: 'pack1',
    isMemorized: true,
    isVerseOfWeek: false,
    addedAt: DateTime(2024, 1, 1),
  );
}

void main() {
  group('VerseProvider.esvVerseCount', () {
    test('is 0 when no ESV verses are stored', () {
      final provider = VerseProvider(DatabaseHelper());
      provider.debugSetVerses([
        _verseWithTranslation('a', 'BSB'),
        _verseWithTranslation('b', 'KJV'),
      ]);

      expect(provider.esvVerseCount, 0);
    });

    test('counts only ESV-translation verses, ignoring BSB/KJV/WEB', () {
      final provider = VerseProvider(DatabaseHelper());
      provider.debugSetVerses([
        _verseWithTranslation('a', 'ESV'),
        _verseWithTranslation('b', 'BSB'),
        _verseWithTranslation('c', 'ESV'),
        _verseWithTranslation('d', 'KJV'),
        _verseWithTranslation('e', 'WEB'),
      ]);

      expect(provider.esvVerseCount, 2);
    });
  });

  group('VerseProvider.getRandomMemorizedVerses', () {
    test('returns full pool when count exceeds pool size', () {
      final provider = VerseProvider(DatabaseHelper());
      final pool = [_verse('a'), _verse('b'), _verse('c')];
      provider.debugSetVerses(pool);

      final result = provider.getRandomMemorizedVerses(10);

      expect(result.length, 3);
      expect(result.map((v) => v.id).toSet(), {'a', 'b', 'c'});
    });

    test('returns exactly count verses when count is below pool size', () {
      final provider = VerseProvider(DatabaseHelper());
      final pool = [_verse('a'), _verse('b'), _verse('c'), _verse('d')];
      provider.debugSetVerses(pool);

      final result = provider.getRandomMemorizedVerses(2);

      expect(result.length, 2);
      expect(
        result.map((v) => v.id).toSet().every({'a', 'b', 'c', 'd'}.contains),
        isTrue,
      );
    });

    test('includeVerseOfWeek true ensures eligible verse-of-week is in result',
        () {
      final provider = VerseProvider(DatabaseHelper());
      final vow = _verse('vow', isVerseOfWeek: true);
      final pool = [vow, _verse('a'), _verse('b'), _verse('c')];
      provider.debugSetVerses(pool);

      final result = provider.getRandomMemorizedVerses(
        2,
        includeVerseOfWeek: true,
      );

      expect(result.length, 2);
      expect(result.any((v) => v.id == 'vow'), isTrue);
    });

    test(
        'includeVerseOfWeek true keeps the verse-of-week as one of the slots at full-pool count',
        () {
      final provider = VerseProvider(DatabaseHelper());
      final vow = _verse('vow', isVerseOfWeek: true);
      final pool = [vow, _verse('a'), _verse('b')];
      provider.debugSetVerses(pool);

      final result = provider.getRandomMemorizedVerses(
        3,
        includeVerseOfWeek: true,
      );

      expect(result.length, 3);
      expect(result.any((v) => v.id == 'vow'), isTrue);
    });

    test(
        'includeVerseOfWeek true with no verse-of-week falls back to plain selection',
        () {
      final provider = VerseProvider(DatabaseHelper());
      final pool = [_verse('a'), _verse('b'), _verse('c')];
      provider.debugSetVerses(pool);

      final result = provider.getRandomMemorizedVerses(
        2,
        includeVerseOfWeek: true,
      );

      expect(result.length, 2);
    });

    test(
        'includeVerseOfWeek true with unmemorized verse-of-week falls back to plain selection',
        () {
      final provider = VerseProvider(DatabaseHelper());
      final vow = _verse('vow', isMemorized: false, isVerseOfWeek: true);
      final pool = [vow, _verse('a'), _verse('b')];
      provider.debugSetVerses(pool);

      final result = provider.getRandomMemorizedVerses(
        2,
        includeVerseOfWeek: true,
      );

      expect(result.length, 2);
      expect(result.any((v) => v.id == 'vow'), isFalse);
    });

    test(
        'includeVerseOfWeek false excludes verse-of-week even at full-pool count',
        () {
      final provider = VerseProvider(DatabaseHelper());
      final vow = _verse('vow', isVerseOfWeek: true);
      final pool = [vow, _verse('a'), _verse('b')];
      provider.debugSetVerses(pool);

      final result = provider.getRandomMemorizedVerses(3);

      expect(result.length, 2);
      expect(result.any((v) => v.id == 'vow'), isFalse);
    });

    group('boundary', () {
      test('count=0 returns empty list regardless of verse-of-week', () {
        final provider = VerseProvider(DatabaseHelper());
        final vow = _verse('vow', isVerseOfWeek: true);
        final pool = [vow, _verse('a'), _verse('b')];
        provider.debugSetVerses(pool);

        final result =
            provider.getRandomMemorizedVerses(0, includeVerseOfWeek: true);

        expect(result, isEmpty);
      });

      test('count=1 returns exactly one verse', () {
        final provider = VerseProvider(DatabaseHelper());
        final pool = [_verse('a'), _verse('b'), _verse('c')];
        provider.debugSetVerses(pool);

        final result = provider.getRandomMemorizedVerses(1);

        expect(result.length, 1);
      });

      test('count=1 with includeVerseOfWeek returns VoW as the single verse',
          () {
        final provider = VerseProvider(DatabaseHelper());
        final vow = _verse('vow', isVerseOfWeek: true);
        final pool = [vow, _verse('a'), _verse('b')];
        provider.debugSetVerses(pool);

        final result = provider.getRandomMemorizedVerses(
          1,
          includeVerseOfWeek: true,
        );

        expect(result.length, 1);
        expect(result.first.isVerseOfWeek, isTrue);
      });
    });
  });
}
