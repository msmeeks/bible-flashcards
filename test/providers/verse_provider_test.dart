import 'package:flutter_test/flutter_test.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/models/settings.dart';
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

  group('VerseProvider.pickVerseForAutoAdvance', () {
    final sunday = DateTime(2026, 6, 21); // confirmed Sunday
    final monday = DateTime(2026, 6, 22);

    test('returns null when autoAdvanceVerseOfWeek is disabled', () {
      final provider = VerseProvider(DatabaseHelper());
      provider.debugSetVerses([_verse('a'), _verse('b')]);
      const settings = AppSettings(autoAdvanceVerseOfWeek: false);

      expect(provider.pickVerseForAutoAdvance(settings, sunday), isNull);
    });

    test('returns null when today is not Sunday', () {
      final provider = VerseProvider(DatabaseHelper());
      provider.debugSetVerses([_verse('a'), _verse('b')]);
      const settings = AppSettings(autoAdvanceVerseOfWeek: true);

      expect(provider.pickVerseForAutoAdvance(settings, monday), isNull);
    });

    test('returns null when already advanced this ISO week', () {
      final provider = VerseProvider(DatabaseHelper());
      provider.debugSetVerses([_verse('a'), _verse('b')]);
      final settings = AppSettings(
        autoAdvanceVerseOfWeek: true,
        lastVerseAdvanceDate: sunday,
      );

      expect(provider.pickVerseForAutoAdvance(settings, sunday), isNull);
    });

    test('picks a non-current verse on Sunday when not yet advanced', () {
      final provider = VerseProvider(DatabaseHelper());
      final vow = _verse('vow', isVerseOfWeek: true);
      provider.debugSetVerses([vow, _verse('a'), _verse('b')]);
      const settings = AppSettings(autoAdvanceVerseOfWeek: true);

      final picked = provider.pickVerseForAutoAdvance(settings, sunday);

      expect(picked, isNotNull);
      expect(picked!.id, isNot('vow'));
    });

    test('returns null when there is no non-current verse candidate', () {
      final provider = VerseProvider(DatabaseHelper());
      provider.debugSetVerses([_verse('vow', isVerseOfWeek: true)]);
      const settings = AppSettings(autoAdvanceVerseOfWeek: true);

      expect(provider.pickVerseForAutoAdvance(settings, sunday), isNull);
    });

    test('treats Dec-28 (prior ISO week) advance as stale on next Sunday',
        () {
      final provider = VerseProvider(DatabaseHelper());
      provider.debugSetVerses([_verse('a'), _verse('b')]);
      // last advance was the Sunday before New Year's Eve week (ISO 2025-W52);
      // the following Sunday lands in ISO 2026-W1 — must advance again.
      final settings = AppSettings(
        autoAdvanceVerseOfWeek: true,
        lastVerseAdvanceDate: DateTime(2025, 12, 28),
      );

      final picked =
          provider.pickVerseForAutoAdvance(settings, DateTime(2026, 1, 4));

      expect(picked, isNotNull);
    });

    test('treats Dec-29 advance and Jan-4 Sunday as same ISO week', () {
      final provider = VerseProvider(DatabaseHelper());
      provider.debugSetVerses([_verse('a'), _verse('b')]);
      // 2025-12-29 (Mon) and 2026-01-04 (Sun) both fall in ISO week 2026-W1.
      final settings = AppSettings(
        autoAdvanceVerseOfWeek: true,
        lastVerseAdvanceDate: DateTime(2025, 12, 29),
      );

      final picked =
          provider.pickVerseForAutoAdvance(settings, DateTime(2026, 1, 4));

      expect(picked, isNull);
    });
  });
}
