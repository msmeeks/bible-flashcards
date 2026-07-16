import 'dart:math';

import 'package:bible_flashcards/utils/scoring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('diffWords', () {
    // Renders the alignment compactly so a failure reads as the diff itself
    // rather than a wall of object identities.
    String render(List<DiffToken> tokens) => tokens
        .map((t) => switch (t.op) {
              DiffOp.match => t.word,
              DiffOp.delete => '-${t.word}',
              DiffOp.insert => '+${t.word}',
            })
        .join(' ');

    test('an exact answer is all matches', () {
      expect(
        render(diffWords('for God so loved', 'for God so loved')),
        'for God so loved',
      );
    });

    test('preserves the source casing and punctuation of matched words', () {
      final tokens = diffWords('for god so loved', 'For God so loved,');
      expect(tokens.every((t) => t.op == DiffOp.match), isTrue);
      expect(render(tokens), 'For God so loved,');
    });

    test('a word missing from the answer is a deletion', () {
      expect(
        render(diffWords('for so loved', 'for God so loved')),
        'for -God so loved',
      );
    });

    test('a word not in the source is an insertion', () {
      expect(
        render(diffWords('for God truly so loved', 'for God so loved')),
        'for God +truly so loved',
      );
    });

    test('a substituted word is a deletion plus an insertion', () {
      final tokens = diffWords('for God so hated', 'for God so loved');
      expect(tokens.where((t) => t.op == DiffOp.delete).single.word, 'loved');
      expect(tokens.where((t) => t.op == DiffOp.insert).single.word, 'hated');
    });

    test('an empty answer makes every source word a deletion', () {
      final tokens = diffWords('', 'for God so loved');
      expect(tokens.every((t) => t.op == DiffOp.delete), isTrue);
      expect(render(tokens), '-for -God -so -loved');
    });

    test('two empty inputs produce no tokens', () {
      expect(diffWords('', ''), isEmpty);
    });

    // #161's normalization must drive the alignment, or a contraction the
    // score already forgave would still render as a mismatch.
    test('an apostrophe difference aligns as a match', () {
      final tokens = diffWords('the Lords servant', "the Lord's servant");
      expect(tokens.every((t) => t.op == DiffOp.match), isTrue);
      expect(render(tokens), "the Lord's servant");
    });

    // The helper is shared with computeScore (#162), so the two can never
    // disagree about what matched.
    test('match count is consistent with computeScore', () {
      const typed = 'for God so truly hated the world';
      const correct = 'for God so loved the world';
      final tokens = diffWords(typed, correct);
      final matches = tokens.where((t) => t.op == DiffOp.match).length;
      final typedLen = tokens
          .where((t) => t.op == DiffOp.match || t.op == DiffOp.insert)
          .length;
      final correctLen = tokens
          .where((t) => t.op == DiffOp.match || t.op == DiffOp.delete)
          .length;
      expect(
        computeScore(typed, correct),
        matches / max(typedLen, correctLen),
      );
    });
  });

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
      expect(
          computeScore(
              'for God so loved the world', 'for God so loved the world'),
          1.0);
    });

    test('case-insensitive matching', () {
      expect(
          computeScore(
              'FOR GOD SO LOVED THE WORLD', 'for God so loved the world'),
          1.0);
    });

    test('punctuation stripped — commas and periods ignored', () {
      expect(
          computeScore(
              'for, God so loved the world.', 'for God so loved the world'),
          1.0);
    });

    // #161: apostrophes are stripped like all other punctuation, so a
    // contraction scores the same however the user's keyboard typed it.
    test('identical contractions still score a full match', () {
      expect(computeScore("don't", "don't"), 1.0);
    });

    test('an omitted apostrophe scores a full match', () {
      expect(computeScore('dont', "don't"), 1.0);
    });

    test('a curly apostrophe scores a full match against a straight one', () {
      expect(computeScore('don’t', "don't"), 1.0);
    });

    test('apostrophe insensitivity holds across a full phrase', () {
      expect(
        computeScore('I am the Lords servant', "I am the Lord's servant"),
        1.0,
      );
    });

    // Stripping the apostrophe must not silently weld neighbouring words
    // together — "dont" and "do nt" are different answers.
    test('stripping an apostrophe does not merge distinct words', () {
      expect(computeScore('do nt', "don't"), lessThan(1.0));
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

  group('blankCountForPercentage', () {
    test('20% floors at 1 blank even when the percentage math rounds to 0', () {
      expect(blankCountForPercentage(2, 20), 1);
    });

    test(
        '30/50/75% floor at 2 blanks even when the percentage math rounds lower',
        () {
      expect(blankCountForPercentage(2, 30), 2);
      expect(blankCountForPercentage(2, 50), 2);
      expect(blankCountForPercentage(2, 75), 2);
    });

    test('rounds to nearest whole blank count for larger word counts', () {
      // 20% of 10 = 2 exactly
      expect(blankCountForPercentage(10, 20), 2);
      // 30% of 10 = 3 exactly
      expect(blankCountForPercentage(10, 30), 3);
      // 50% of 11 = 5.5 → rounds to 6
      expect(blankCountForPercentage(11, 50), 6);
      // 75% of 9 = 6.75 → rounds to 7
      expect(blankCountForPercentage(9, 75), 7);
    });
  });

  group('blankIndices', () {
    test('empty list → empty result', () {
      expect(blankIndices([], 3), isEmpty);
    });

    test('count of 0 → empty result', () {
      expect(blankIndices(['for', 'God', 'so'], 0), isEmpty);
    });

    test('single word, count 1 → blanks that word', () {
      expect(blankIndices(['grace'], 1), [0]);
    });

    test('count exceeds available candidate words → blanks all of them', () {
      final words = ['for', 'God', 'so'];
      expect(blankIndices(words, 10), [0, 1, 2]);
    });

    test('colon tokens are never selected as candidates', () {
      final words = ['John', '3', ':', '16'];
      final indices = blankIndices(words, 3);
      expect(indices, isNot(contains(2)));
      expect(indices, [0, 1, 3]);
    });

    test('returns exactly the requested count when enough candidates exist',
        () {
      final words = List.generate(20, (i) => 'w$i');
      final indices = blankIndices(words, 5, random: Random(42));
      expect(indices.length, 5);
    });

    test('all returned indices are unique and within bounds', () {
      final words = List.generate(20, (i) => 'w$i');
      final indices = blankIndices(words, 5, random: Random(1));
      expect(indices.toSet().length, indices.length);
      for (final idx in indices) {
        expect(idx, greaterThanOrEqualTo(0));
        expect(idx, lessThan(words.length));
      }
    });

    test('result is sorted ascending to match word order', () {
      final words = List.generate(20, (i) => 'w$i');
      final indices = blankIndices(words, 5, random: Random(7));
      final sorted = [...indices]..sort();
      expect(indices, sorted);
    });

    test('same seed produces the same positions (deterministic given RNG)', () {
      final words = List.generate(20, (i) => 'w$i');
      final a = blankIndices(words, 5, random: Random(99));
      final b = blankIndices(words, 5, random: Random(99));
      expect(a, b);
    });

    test('different RNG state can produce different position sets', () {
      final words = List.generate(30, (i) => 'w$i');
      final a = blankIndices(words, 5, random: Random(1));
      final b = blankIndices(words, 5, random: Random(2));
      expect(a, isNot(b));
    });
  });

  group('splitAnswerTokens', () {
    test('empty string returns empty list', () {
      expect(splitAnswerTokens(''), isEmpty);
    });

    test('plain verse text splits on whitespace only', () {
      expect(
          splitAnswerTokens('for God so loved'), ['for', 'God', 'so', 'loved']);
    });

    test('two-token reference splits chapter:verse on the colon', () {
      expect(splitAnswerTokens('John 3:16'), ['John', '3', ':', '16']);
    });

    test('numbered-book reference splits chapter:verse on the colon', () {
      expect(splitAnswerTokens('1 John 1:12'), ['1', 'John', '1', ':', '12']);
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
        computeReferenceScore('The Gospel According to Mark 4:9', 'Mark 4:9'),
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

    test('unrecognized book name falls through to plain LCS, no false credit',
        () {
      final score = computeReferenceScore('Frodo 3:16', '1 Peter 3:16');
      expect(score, computeScore('Frodo 3:16', '1 Peter 3:16'));
      expect(score, lessThan(1.0));
    });

    test('recognized but different book scores via plain LCS', () {
      final score = computeReferenceScore('Mark 4:9', 'Luke 4:9');
      expect(score, computeScore('Mark 4:9', 'Luke 4:9'));
      expect(score, lessThan(1.0));
    });

    test('typed side unrecognized, correct side recognized → falls through',
        () {
      final score = computeReferenceScore('Frodo 4:9', 'Mark 4:9');
      expect(score, computeScore('Frodo 4:9', 'Mark 4:9'));
    });

    test('typed side recognized, correct side unrecognized → falls through',
        () {
      final score = computeReferenceScore('Mark 4:9', 'Frodo 4:9');
      expect(score, computeScore('Mark 4:9', 'Frodo 4:9'));
    });

    test('period separator normalized to colon', () {
      expect(computeReferenceScore('Phil 4.13', 'Phil 4:13'), 1.0);
    });

    test('bare space between chapter and verse normalized to colon', () {
      expect(computeReferenceScore('Phil 4 13', 'Phil 4:13'), 1.0);
    });

    test('word-form "colon" and "dot" separators normalized', () {
      expect(computeReferenceScore('Phil 4 colon 13', 'Phil 4:13'), 1.0);
      expect(computeReferenceScore('Phil 4 dot 13', 'Phil 4:13'), 1.0);
    });

    test('"to" and "through" range connectors normalized to a dash', () {
      expect(computeReferenceScore('John 3:16 to 17', 'John 3:16-17'), 1.0);
      expect(
          computeReferenceScore('John 3:16 through 17', 'John 3:16-17'), 1.0);
    });

    test('word-form "dash" range connector normalized', () {
      expect(computeReferenceScore('John 3:16 dash 17', 'John 3:16-17'), 1.0);
    });

    test('"and" after a chapter:verse token normalized to a range dash', () {
      expect(computeReferenceScore('John 3:16 and 17', 'John 3:16-17'), 1.0);
    });

    test('"and" joining book-number prefixes is not mangled', () {
      final score =
          computeReferenceScore('1 and 2 Thessalonians 1:1', '1 Peter 3:16');
      expect(score, computeScore('1 and 2 Thessalonians 1:1', '1 Peter 3:16'));
    });

    test('normalization completes quickly on a long digit/space fuzz string',
        () {
      final fuzz = ('12 ' * 350).trim();
      final stopwatch = Stopwatch()..start();
      computeReferenceScore(fuzz, 'Phil 4:13');
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('non-reference input falls through to plain computeScore', () {
      expect(
        computeReferenceScore('for God so loved', 'for God so loved'),
        1.0,
      );
    });

    test('verse-range form (chapter:verse-verse) matches across book variants',
        () {
      expect(
        computeReferenceScore('1 Pt 3:16-18', '1 Peter 3:16-18'),
        1.0,
      );
    });

    test(
        'en dash and em dash range separators on the correct side still resolve the book span',
        () {
      expect(
          computeReferenceScore('1 cor 15:3-4', '1 Corinthians 15:3–4'), 1.0);
      expect(
          computeReferenceScore('1 cor 15:3-4', '1 Corinthians 15:3—4'), 1.0);
    });

    test('custom variant resolves to its mapped book', () {
      final score = computeReferenceScore(
        'JPet 3:16',
        '1 Peter 3:16',
        customVariants: {'jpet': '1PE'},
      );
      expect(score, 1.0);
    });

    test(
        'bare-space verse + trailing "and" range does not fully normalize '
        '(range connector resolves before the bare-space colon insertion)', () {
      // Documents the ordering tradeoff called out in
      // _normalizeReferenceInput: "16 and 17" only becomes a range once a
      // colon already precedes it, but "3 16" hasn't been colonized yet
      // when the "and" rule runs, so this falls through to plain LCS.
      final score = computeReferenceScore('John 3 16 and 17', 'John 3:16-17');
      expect(score, computeScore('John 3 16 and 17', 'John 3:16-17'));
      expect(score, lessThan(1.0));
    });

    test('"to" range connector combined with bare-space chapter:verse matches',
        () {
      expect(
        computeReferenceScore('Phil 4 13 to 14', 'Phil 4:13-14'),
        1.0,
      );
    });

    test('both empty → falls through to computeScore, scores 1.0', () {
      expect(computeReferenceScore('', ''), 1.0);
    });

    test('both whitespace-only → falls through to computeScore, scores 1.0',
        () {
      expect(computeReferenceScore('   ', '   '), 1.0);
    });

    test('typed non-empty, correct empty → 0.0', () {
      expect(computeReferenceScore('John 3:16', ''), 0.0);
    });

    test('typed empty, correct non-empty → 0.0', () {
      expect(computeReferenceScore('', 'John 3:16'), 0.0);
    });
  });

  group('scoreBlankedBookNameTokens', () {
    test('single-token book name blanked with a recognized abbreviation', () {
      final tokens = splitAnswerTokens('Mark 4:9');
      final result = scoreBlankedBookNameTokens(
        'Mark 4:9',
        tokens,
        {0: 'Mrk'},
      );
      expect(result, {0: true});
    });

    test(
        'multi-token book name, only the name word blanked with an '
        'abbreviation, numeral supplied from the unblanked token', () {
      final tokens = splitAnswerTokens('1 Thessalonians 5:19');
      final result = scoreBlankedBookNameTokens(
        '1 Thessalonians 5:19',
        tokens,
        {1: 'Thess'},
      );
      expect(result, {1: true});
    });

    test(
        'multi-token book name, only the numeral blanked with the wrong '
        'numeral scores incorrect', () {
      final tokens = splitAnswerTokens('1 Thessalonians 5:19');
      final result = scoreBlankedBookNameTokens(
        '1 Thessalonians 5:19',
        tokens,
        {0: '2'},
      );
      expect(result, {0: false});
    });

    test('multi-token book name, both tokens blanked correctly', () {
      final tokens = splitAnswerTokens('1 Thessalonians 5:19');
      final result = scoreBlankedBookNameTokens(
        '1 Thessalonians 5:19',
        tokens,
        {0: '1', 1: 'Th'},
      );
      expect(result, {0: true, 1: true});
    });

    test('multi-token book name, both tokens blanked incorrectly', () {
      final tokens = splitAnswerTokens('1 Thessalonians 5:19');
      final result = scoreBlankedBookNameTokens(
        '1 Thessalonians 5:19',
        tokens,
        {0: '2', 1: 'Peter'},
      );
      expect(result, {0: false, 1: false});
    });

    test('typed value that does not resolve to any book stays incorrect', () {
      final tokens = splitAnswerTokens('Mark 4:9');
      final result = scoreBlankedBookNameTokens(
        'Mark 4:9',
        tokens,
        {0: 'Frodo'},
      );
      expect(result, {0: false});
    });

    test('custom variants are respected', () {
      final tokens = splitAnswerTokens('1 Peter 3:16');
      final result = scoreBlankedBookNameTokens(
        '1 Peter 3:16',
        tokens,
        {0: 'J', 1: 'Pet'},
        customVariants: {'jpet': '1PE'},
      );
      expect(result, {0: true, 1: true});
    });

    test('blanks outside the book-name span are not scored (chapter number)',
        () {
      final tokens = splitAnswerTokens('Mark 4:9');
      final result = scoreBlankedBookNameTokens(
        'Mark 4:9',
        tokens,
        {1: '4'},
      );
      expect(result, isEmpty);
    });

    test('non-reference correct answer returns no lenient scoring', () {
      final tokens = splitAnswerTokens('for God so loved');
      final result = scoreBlankedBookNameTokens(
        'for God so loved',
        tokens,
        {0: 'for'},
      );
      expect(result, isEmpty);
    });

    test(
        'en-dash verse range (as stored by some bundled packs) still resolves the book-name span',
        () {
      const ref = '1 Corinthians 15:3–4';
      final tokens = splitAnswerTokens(ref);
      final result = scoreBlankedBookNameTokens(
        ref,
        tokens,
        {0: '1', 1: 'cor'},
      );
      expect(result, {0: true, 1: true});
    });
  });
}
