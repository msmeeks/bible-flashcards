import 'dart:math';

import 'book_name_variants.dart' show bookNameToUsfm;

/// Matches "Book Chapter:Verse" or "Book Chapter:Verse-Verse" strings,
/// capturing the book-name span separately from the chapter:verse span.
/// The range separator accepts a hyphen, en dash, or em dash — some bundled
/// verse packs store ranges with a Unicode dash instead of an ASCII hyphen.
final RegExp referenceSplitPattern =
    RegExp(r'^(.+?)\s+(\d+:\d+(?:[-–—]\d+)?)\s*$');

/// Normalizes natural separator/range variants in a typed reference so they
/// match the canonical "Book Chapter:Verse" form before [referenceSplitPattern]
/// runs. Order matters: range connectors must resolve before the bare-space
/// rule, or "16 to 17" would become "16:to" before "to" is replaced.
String normalizeReferenceInput(String s) {
  s = s.replaceAll(RegExp(r'\s*\bcolon\b\s*', caseSensitive: false), ':');
  s = s.replaceAll(RegExp(r'\s*\bdot\b\s*', caseSensitive: false), '.');
  s = s.replaceAll(RegExp(r'\s*\bdash\b\s*', caseSensitive: false), '-');
  s = s.replaceAllMapped(
      RegExp(r'(\d+)\s+(?:to|through)\s+(\d+)', caseSensitive: false),
      (m) => '${m.group(1)}-${m.group(2)}');
  s = s.replaceAllMapped(
      RegExp(r'(\d+:\d+)\s+and\s+(\d+)(?!\s*\w)', caseSensitive: false),
      (m) => '${m.group(1)}-${m.group(2)}');
  s = s.replaceAllMapped(
      RegExp(r'(\d+)\.(\d+)'), (m) => '${m.group(1)}:${m.group(2)}');
  s = s.replaceAllMapped(
      RegExp(r'(\d+) (\d+)'), (m) => '${m.group(1)}:${m.group(2)}');
  return s;
}

/// Computes a 0.0–1.0 similarity score for a reference-answer (book chapter:verse).
///
/// Before running the usual word-level LCS, the book-name portion of [typed]
/// and [correct] is resolved against the book-name-variant table (built-in
/// plus [customVariants]). If both resolve to the same book, [typed]'s book
/// name is rewritten to match [correct]'s wording exactly, so abbreviations
/// and longhand variants ("1 Pt", "First Peter", "The Gospel of Mark") score
/// identically to the canonical form instead of being penalized for
/// word-choice. If either side's book name is unrecognized, or they resolve
/// to different books, scoring falls through to plain [computeScore].
///
/// `test_session_screen.dart` composes [canonicalizeReferenceAnswer] and
/// [computeScore] itself rather than calling this, because it needs the
/// canonical text for the diff too and must not canonicalize twice. This
/// stays as the module's reference-scoring entry point and is defined in
/// terms of those same two pieces, so the two paths cannot diverge.
double computeReferenceScore(
  String typed,
  String correct, {
  Map<String, String> customVariants = const {},
}) =>
    computeScore(
      canonicalizeReferenceAnswer(typed, correct,
          customVariants: customVariants),
      correct,
    );

/// Rewrites [typed]'s book name to match [correct]'s wording when both
/// resolve to the same book, returning the text that should actually be
/// compared against [correct]. Returns [typed] unchanged when either side
/// isn't reference-shaped, either book name is unrecognized, or the two name
/// different books — so a wrong-book answer never gets a silent pass.
///
/// Exposed so the score and the rendered diff (#162) can be derived from the
/// same comparable text: scoring the canonical form while diffing the raw
/// input would show "1 Thess" as an extra word beside a 100% score.
String canonicalizeReferenceAnswer(
  String typed,
  String correct, {
  Map<String, String> customVariants = const {},
}) {
  final typedMatch =
      referenceSplitPattern.firstMatch(normalizeReferenceInput(typed.trim()));
  final correctMatch = referenceSplitPattern.firstMatch(correct.trim());
  if (typedMatch == null || correctMatch == null) return typed;

  final typedBook = typedMatch.group(1)!;
  final correctBook = correctMatch.group(1)!;
  final typedUsfm = bookNameToUsfm(typedBook, customVariants: customVariants);
  final correctUsfm =
      bookNameToUsfm(correctBook, customVariants: customVariants);

  if (typedUsfm == null || correctUsfm == null || typedUsfm != correctUsfm) {
    return typed;
  }
  return '$correctBook ${typedMatch.group(2)}';
}

/// Splits [s] into normalized comparison words: lowercased, stripped of all
/// punctuation (apostrophes included, so "don't", "dont" and "don’t" all
/// compare equal — #161), and collapsed on whitespace. Punctuation is
/// removed rather than replaced with a space, so a contraction stays a
/// single token instead of splitting into two.
List<String> normalizeWords(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^\w\s]'), '')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ')
    .split(' ')
    .where((w) => w.isNotEmpty)
    .toList();

/// What a [DiffToken] represents in an answer-vs-source alignment.
enum DiffOp {
  /// Present in both the answer and the source.
  match,

  /// A source word the answer omitted.
  delete,

  /// An answer word the source doesn't contain.
  insert,
}

/// One word of a [diffWords] alignment, carrying the word as originally
/// written (source casing/punctuation for [DiffOp.match]/[DiffOp.delete],
/// the user's own for [DiffOp.insert]) so callers can render it verbatim
/// even though the alignment itself ran on normalized text.
class DiffToken {
  const DiffToken(this.word, this.op);

  final String word;
  final DiffOp op;

  @override
  String toString() => '${op.name}:$word';
}

/// Pairs each whitespace-separated word of [s] with its normalized
/// comparison form, dropping words that normalize away to nothing (a bare
/// em dash, say). Keeping both halves together is what lets [diffWords]
/// align on normalized text but render the original.
List<({String original, String normalized})> _alignableWords(String s) => [
      for (final word in s.trim().split(RegExp(r'\s+')))
        if (normalizeWords(word).join() case final normalized
            when normalized.isNotEmpty)
          (original: word, normalized: normalized),
    ];

/// Aligns a [typed] answer against the [correct] source word-by-word,
/// returning the LCS alignment in source order: matched words, source words
/// the answer missed ([DiffOp.delete]), and words the answer added
/// ([DiffOp.insert]).
///
/// Comparison uses [normalizeWords], so case and punctuation — apostrophes
/// included (#161) — never produce a spurious mismatch. This is the same
/// alignment [computeScore] scores, so a rendered diff can never contradict
/// the percentage shown beside it.
List<DiffToken> diffWords(String typed, String correct) {
  final typedWords = _alignableWords(typed);
  final correctWords = _alignableWords(correct);

  final m = typedWords.length;
  final n = correctWords.length;
  final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      if (typedWords[i - 1].normalized == correctWords[j - 1].normalized) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else {
        dp[i][j] = max(dp[i - 1][j], dp[i][j - 1]);
      }
    }
  }

  // Walk the table backwards, then reverse: emitting in source order keeps
  // the rendered diff readable as the verse rather than as the answer.
  final tokens = <DiffToken>[];
  var i = m;
  var j = n;
  while (i > 0 || j > 0) {
    if (i > 0 &&
        j > 0 &&
        typedWords[i - 1].normalized == correctWords[j - 1].normalized) {
      tokens.add(DiffToken(correctWords[j - 1].original, DiffOp.match));
      i--;
      j--;
    } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
      tokens.add(DiffToken(correctWords[j - 1].original, DiffOp.delete));
      j--;
    } else {
      tokens.add(DiffToken(typedWords[i - 1].original, DiffOp.insert));
      i--;
    }
  }
  return tokens.reversed.toList();
}

/// Computes a 0.0–1.0 similarity score using word-level LCS.
/// Both-empty inputs return 1.0; either-empty returns 0.0.
double computeScore(String typed, String correct) {
  final typedWords = normalizeWords(typed);
  final correctWords = normalizeWords(correct);

  if (typedWords.isEmpty && correctWords.isEmpty) return 1.0;
  if (typedWords.isEmpty || correctWords.isEmpty) return 0.0;

  final tokens = diffWords(typed, correct);
  final lcs = tokens.where((t) => t.op == DiffOp.match).length;
  return lcs / max(typedWords.length, correctWords.length);
}

/// Computes how many words to blank for a given blank-density [percentage]
/// (e.g. 20, 30, 50, 75) applied to [candidateWordCount] candidate words.
///
/// Rounds `percentage% × candidateWordCount` to the nearest whole blank
/// count, then floors the result at 1 for the 20% density and 2 for the
/// denser 30/50/75% options, so short verses still get a meaningful number
/// of blanks instead of rounding down to zero.
int blankCountForPercentage(int candidateWordCount, int percentage) {
  final floor = percentage <= 20 ? 1 : 2;
  final computed = (percentage / 100 * candidateWordCount).round();
  return computed < floor ? floor : computed;
}

/// Returns [count] randomly-selected, duplicate-free word indices to blank
/// in a fill-blank question. Standalone ':' separator tokens (see
/// [splitAnswerTokens]) are never candidates. If [count] exceeds the number
/// of candidate words, all candidates are blanked. The result is sorted
/// ascending to match word order. [random] is injectable for deterministic
/// tests; production callers should omit it and get a real [Random].
List<int> blankIndices(List<String> words, int count, {Random? random}) {
  final candidatePositions = <int>[
    for (var i = 0; i < words.length; i++)
      if (words[i] != ':') i,
  ];
  if (candidatePositions.isEmpty || count <= 0) return [];

  if (count >= candidatePositions.length) {
    return candidatePositions;
  }

  final rng = random ?? Random();
  final pool = [...candidatePositions];
  final selected = <int>[];
  for (var i = 0; i < count; i++) {
    final pick = rng.nextInt(pool.length);
    selected.add(pool.removeAt(pick));
  }
  selected.sort();
  return selected;
}

/// Scores fill-blank tokens that fall within a reference answer's book-name
/// span leniently, the same way [computeReferenceScore] scores Type mode.
///
/// [correctAnswer] is the full "Book Chapter:Verse" reference; [answerTokens]
/// is its [splitAnswerTokens] output; [blankedTokenValues] maps the index of
/// each blanked token (in [answerTokens]) to what the user typed there. For
/// every blanked index that falls inside the book-name span, the span is
/// reconstructed (typed value at blanked positions, actual token elsewhere)
/// and resolved via [bookNameToUsfm]; if it matches the correct book, every
/// blanked index in the span is scored correct, otherwise incorrect. Returns
/// only entries for blanked indices inside the book-name span — callers
/// should fall back to exact-match scoring for every other blanked index.
/// If [correctAnswer] isn't reference-shaped, or its book name doesn't
/// resolve, returns an empty map (no lenient scoring applies).
Map<int, bool> scoreBlankedBookNameTokens(
  String correctAnswer,
  List<String> answerTokens,
  Map<int, String> blankedTokenValues, {
  Map<String, String> customVariants = const {},
}) {
  final match = referenceSplitPattern.firstMatch(correctAnswer.trim());
  if (match == null) return {};

  final correctBook = match.group(1)!;
  final correctUsfm =
      bookNameToUsfm(correctBook, customVariants: customVariants);
  if (correctUsfm == null) return {};

  final bookTokenCount = splitAnswerTokens(correctBook).length;
  final blankedInSpan = [
    for (final index in blankedTokenValues.keys)
      if (index < bookTokenCount) index,
  ];
  if (blankedInSpan.isEmpty) return {};

  final typedSpan = [
    for (var i = 0; i < bookTokenCount; i++)
      blankedTokenValues[i] ?? answerTokens[i],
  ].join(' ');
  final typedUsfm = bookNameToUsfm(typedSpan, customVariants: customVariants);
  final isCorrect = typedUsfm != null && typedUsfm == correctUsfm;

  return {for (final index in blankedInSpan) index: isCorrect};
}

/// Splits answer text into fill-blank tokens, treating ':' as its own
/// non-blankable separator token so "John 3:16" yields candidate words
/// "John", "3", "16" with the colon preserved for rendering.
List<String> splitAnswerTokens(String text) {
  final tokens = <String>[];
  for (final part in text.split(' ')) {
    if (part.isEmpty) continue;
    final segments = part.split(':');
    for (var i = 0; i < segments.length; i++) {
      if (segments[i].isNotEmpty) tokens.add(segments[i]);
      if (i < segments.length - 1) tokens.add(':');
    }
  }
  return tokens;
}
