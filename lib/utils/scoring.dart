import 'dart:math';

import 'book_name_variants.dart' show bookNameToUsfm;

/// Matches "Book Chapter:Verse" or "Book Chapter:Verse-Verse" strings,
/// capturing the book-name span separately from the chapter:verse span.
final RegExp _referenceSplitPattern =
    RegExp(r'^(.+?)\s+(\d+:\d+(?:-\d+)?)\s*$');

/// Normalizes natural separator/range variants in a typed reference so they
/// match the canonical "Book Chapter:Verse" form before [_referenceSplitPattern]
/// runs. Order matters: range connectors must resolve before the bare-space
/// rule, or "16 to 17" would become "16:to" before "to" is replaced.
String _normalizeReferenceInput(String s) {
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
double computeReferenceScore(
  String typed,
  String correct, {
  Map<String, String> customVariants = const {},
}) {
  final typedMatch =
      _referenceSplitPattern.firstMatch(_normalizeReferenceInput(typed.trim()));
  final correctMatch = _referenceSplitPattern.firstMatch(correct.trim());
  if (typedMatch == null || correctMatch == null) {
    return computeScore(typed, correct);
  }

  final typedBook = typedMatch.group(1)!;
  final correctBook = correctMatch.group(1)!;
  final typedUsfm = bookNameToUsfm(typedBook, customVariants: customVariants);
  final correctUsfm =
      bookNameToUsfm(correctBook, customVariants: customVariants);

  if (typedUsfm == null || correctUsfm == null || typedUsfm != correctUsfm) {
    return computeScore(typed, correct);
  }

  final canonicalizedTyped = '$correctBook ${typedMatch.group(2)}';
  return computeScore(canonicalizedTyped, correct);
}

/// Computes a 0.0–1.0 similarity score using word-level LCS.
/// Both-empty inputs return 1.0; either-empty returns 0.0.
double computeScore(String typed, String correct) {
  String normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r"[^\w\s']"), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  final typedWords =
      normalize(typed).split(' ').where((w) => w.isNotEmpty).toList();
  final correctWords =
      normalize(correct).split(' ').where((w) => w.isNotEmpty).toList();

  if (typedWords.isEmpty && correctWords.isEmpty) return 1.0;
  if (typedWords.isEmpty || correctWords.isEmpty) return 0.0;

  final m = typedWords.length;
  final n = correctWords.length;
  final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      if (typedWords[i - 1] == correctWords[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else {
        dp[i][j] = max(dp[i - 1][j], dp[i][j - 1]);
      }
    }
  }
  final lcs = dp[m][n];
  final maxLen = max(m, n);
  return lcs / maxLen;
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
    for (var i = 0; i < words.length; i++) if (words[i] != ':') i,
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
