import 'dart:math';

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

/// Returns the word indices that should be blanked in a fill-blank question,
/// selecting approximately every 3rd–5th word (step cycles 3→4→5→3→…).
List<int> blankIndices(List<String> words) {
  final indices = <int>[];
  var step = 3;
  var nextBlank = step - 1;
  for (var i = 0; i < words.length; i++) {
    if (i == nextBlank) {
      indices.add(i);
      step = 3 + (indices.length % 3);
      nextBlank = i + step;
    }
  }
  return indices;
}
