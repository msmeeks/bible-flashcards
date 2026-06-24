import 'package:bible_flashcards/utils/scoring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeScore', () {
    test('both empty → 1.0', () {
      expect(computeScore('', ''), 1.0);
    });

    test('typed empty, correct non-empty → 0.0', () {
      expect(computeScore('', 'for God so loved'), 0.0);
    });

    test('typed non-empty, correct empty → 0.0', () {
      expect(computeScore('for God so loved', ''), 0.0);
    });

    test('identical inputs → 1.0', () {
      expect(computeScore('for God so loved the world', 'for God so loved the world'), 1.0);
    });

    test('case-insensitive matching', () {
      expect(computeScore('FOR GOD SO LOVED THE WORLD', 'for God so loved the world'), 1.0);
    });

    test('punctuation stripped — commas and periods ignored', () {
      expect(computeScore('for, God so loved the world.', 'for God so loved the world'), 1.0);
    });

    test('apostrophes preserved — "don\'t" stays one token', () {
      expect(computeScore("don't", "don't"), 1.0);
    });

    test('completely different inputs → 0.0', () {
      expect(computeScore('hello world', 'foo bar baz'), 0.0);
    });

    test('partial match — typed subset scores proportionally', () {
      final score = computeScore('the world', 'for God so loved the world');
      expect(score, closeTo(2 / 6, 0.0001));
    });

    test('extra words typed — denominator uses longer length', () {
      final score = computeScore('for God so loved', 'for God');
      expect(score, closeTo(2 / 4, 0.0001));
    });

    test('single matching word → 1.0', () {
      expect(computeScore('grace', 'grace'), 1.0);
    });

    test('single word mismatch → 0.0', () {
      expect(computeScore('grace', 'truth'), 0.0);
    });

    test('score is between 0.0 and 1.0 for any non-trivial input', () {
      final score = computeScore(
        'For God so loved the world',
        'For God so loved the earth that he gave his only Son',
      );
      expect(score, greaterThanOrEqualTo(0.0));
      expect(score, lessThanOrEqualTo(1.0));
    });

    test('extra whitespace normalized', () {
      expect(computeScore('for  God   so', 'for God so'), 1.0);
    });

    test('leading and trailing whitespace normalized', () {
      expect(computeScore('  for God so  ', 'for God so'), 1.0);
    });
  });

  group('blankIndices', () {
    test('empty list → empty result', () {
      expect(blankIndices([]), isEmpty);
    });

    test('fewer than 3 words → no blanks', () {
      expect(blankIndices(['the', 'world']), isEmpty);
    });

    test('exactly 3 words → first blank at index 2', () {
      expect(blankIndices(['for', 'God', 'so']), [2]);
    });

    test('step cycle: 3→4→5→3 produces correct indices', () {
      // word 0..11 (12 words)
      // step=3 → blank at index 2
      // step=4 → blank at index 2+4=6
      // step=5 → blank at index 6+5=11
      final words = List.generate(12, (i) => 'w$i');
      expect(blankIndices(words), [2, 6, 11]);
    });

    test('fourth blank resets step to 3 (cycle repeats)', () {
      // after 3rd blank at index 11, step resets to 3 → nextBlank = 14
      final words = List.generate(15, (i) => 'w$i');
      expect(blankIndices(words), [2, 6, 11, 14]);
    });

    test('list ending before next blank produces no trailing blank', () {
      // 8 words: blank at 2 (step→4), blank at 6 (step→5), next would be 11 but only 8 words
      final words = List.generate(8, (i) => 'w$i');
      expect(blankIndices(words), [2, 6]);
    });

    test('no index out of bounds for a typical verse length', () {
      final words = 'For God so loved the world that he gave his only Son'.split(' ');
      final indices = blankIndices(words);
      for (final idx in indices) {
        expect(idx, lessThan(words.length));
        expect(idx, greaterThanOrEqualTo(0));
      }
    });

    test('all returned indices are unique', () {
      final words = List.generate(20, (i) => 'w$i');
      final indices = blankIndices(words);
      expect(indices.toSet().length, indices.length);
    });
  });

  group('computeReferenceScore', () {
    test('abbreviation matches canonical book name exactly', () {
      expect(computeReferenceScore('1 Pt 3:16', '1 Peter 3:16'), 1.0);
      expect(computeReferenceScore('1pt 3:16', '1 Peter 3:16'), 1.0);
      expect(computeReferenceScore('1 pet 3:16', '1 Peter 3:16'), 1.0);
    });

    test('spoken number-word forms match', () {
      expect(computeReferenceScore('First Peter 3:16', '1 Peter 3:16'), 1.0);
      expect(computeReferenceScore('one peter 3:16', '1 Peter 3:16'), 1.0);
    });

    test('longhand "Gospel of X" / "St X" forms match', () {
      expect(computeReferenceScore('The Gospel of Mark 4:9', 'Mark 4:9'), 1.0);
      expect(
        computeReferenceScore(
            'The Gospel According to Mark 4:9', 'Mark 4:9'),
        1.0,
      );
      expect(computeReferenceScore('St Mark 4:9', 'Mark 4:9'), 1.0);
    });

    test('"Acts" longhand forms match', () {
      expect(
        computeReferenceScore('The Acts of the Apostles 2:1', 'Acts 2:1'),
        1.0,
      );
      expect(computeReferenceScore('The Book of Acts 2:1', 'Acts 2:1'), 1.0);
    });

    test('unrecognized book name falls through to plain LCS, no false credit', () {
      final score = computeReferenceScore('Frodo 3:16', '1 Peter 3:16');
      expect(score, computeScore('Frodo 3:16', '1 Peter 3:16'));
      expect(score, lessThan(1.0));
    });

    test('recognized but different book scores via plain LCS', () {
      final score = computeReferenceScore('Mark 4:9', 'Luke 4:9');
      expect(score, computeScore('Mark 4:9', 'Luke 4:9'));
      expect(score, lessThan(1.0));
    });

    test('typed side unrecognized, correct side recognized → falls through', () {
      final score = computeReferenceScore('Frodo 4:9', 'Mark 4:9');
      expect(score, computeScore('Frodo 4:9', 'Mark 4:9'));
    });

    test('typed side recognized, correct side unrecognized → falls through', () {
      final score = computeReferenceScore('Mark 4:9', 'Frodo 4:9');
      expect(score, computeScore('Mark 4:9', 'Frodo 4:9'));
    });

    test('non-reference input falls through to plain computeScore', () {
      expect(
        computeReferenceScore('for God so loved', 'for God so loved'),
        1.0,
      );
    });

    test('verse-range form (chapter:verse-verse) matches across book variants', () {
      expect(
        computeReferenceScore('1 Pt 3:16-18', '1 Peter 3:16-18'),
        1.0,
      );
    });

    test('custom variant resolves to its mapped book', () {
      final score = computeReferenceScore(
        'JPet 3:16',
        '1 Peter 3:16',
        customVariants: {'jpet': '1PE'},
      );
      expect(score, 1.0);
    });
  });
}
