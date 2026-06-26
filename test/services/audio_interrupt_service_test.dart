import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:bible_flashcards/services/audio_interrupt_service.dart';

import '../helpers/verse_factory.dart';

void main() {
  group('pickVerseForInterrupt', () {
    test('probability 1.0 always selects the verse-of-week', () {
      final vow = makeVerse('vow', isVerseOfWeek: true);
      final other = makeVerse('other');
      final random = Random();

      for (var i = 0; i < 100; i++) {
        final picked = pickVerseForInterrupt(
          random: random,
          probability: 1.0,
          verseOfWeek: vow,
          memorizedVerses: [other],
        );
        expect(picked?.id, vow.id);
      }
    });

    test('probability 0.0 never selects the verse-of-week', () {
      final vow = makeVerse('vow', isVerseOfWeek: true);
      final other = makeVerse('other');
      final random = Random();

      for (var i = 0; i < 100; i++) {
        final picked = pickVerseForInterrupt(
          random: random,
          probability: 0.0,
          verseOfWeek: vow,
          memorizedVerses: [other],
        );
        expect(picked?.id, other.id);
      }
    });

    test(
        'probability 0.5 selects both the verse-of-week and a random verse '
        'across many calls', () {
      final vow = makeVerse('vow', isVerseOfWeek: true);
      final other = makeVerse('other');
      final random = Random();

      var vowCount = 0;
      var otherCount = 0;
      for (var i = 0; i < 100; i++) {
        final picked = pickVerseForInterrupt(
          random: random,
          probability: 0.5,
          verseOfWeek: vow,
          memorizedVerses: [other],
        );
        if (picked?.id == vow.id) {
          vowCount++;
        } else if (picked?.id == other.id) {
          otherCount++;
        }
      }

      expect(vowCount, greaterThan(0));
      expect(otherCount, greaterThan(0));
    });
  });
}
