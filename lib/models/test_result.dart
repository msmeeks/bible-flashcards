class VerseTestResult {
  final String verseId;
  final double accuracy; // 0.0 – 1.0
  final String testMode; // "verse_of_week" | "review"
  final String testFormat; // "type" | "recite" | "fill_blank"
  final DateTime testedAt;
  // NOTE: typed input is intentionally NOT stored here — discard after scoring.

  const VerseTestResult({
    required this.verseId,
    required this.accuracy,
    required this.testMode,
    required this.testFormat,
    required this.testedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'verse_id': verseId,
      'accuracy': accuracy,
      'test_mode': testMode,
      'test_format': testFormat,
      'tested_at': testedAt.toIso8601String(),
    };
  }

  factory VerseTestResult.fromMap(Map<String, dynamic> map) {
    return VerseTestResult(
      verseId: map['verse_id'] as String,
      accuracy: (map['accuracy'] as num).toDouble(),
      testMode: map['test_mode'] as String,
      testFormat: map['test_format'] as String,
      testedAt: DateTime.parse(map['tested_at'] as String),
    );
  }
}

class TestSessionResult {
  final List<VerseTestResult> verseResults;
  final DateTime sessionAt;

  const TestSessionResult({
    required this.verseResults,
    required this.sessionAt,
  });

  double get averageAccuracy {
    if (verseResults.isEmpty) return 0.0;
    final total = verseResults.fold<double>(
      0.0,
      (sum, r) => sum + r.accuracy,
    );
    return total / verseResults.length;
  }
}
