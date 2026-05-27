import 'package:bible_flashcards/models/test_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final testedAt = DateTime.utc(2024, 3, 10, 9, 0);

  VerseTestResult baseResult({double accuracy = 0.85}) => VerseTestResult(
        verseId: 'esv_john_3_16',
        accuracy: accuracy,
        testMode: 'review',
        testFormat: 'type',
        testedAt: testedAt,
      );

  group('VerseTestResult.toMap', () {
    test('all fields serialized correctly', () {
      final map = baseResult().toMap();
      expect(map['verse_id'], 'esv_john_3_16');
      expect(map['accuracy'], 0.85);
      expect(map['test_mode'], 'review');
      expect(map['test_format'], 'type');
      expect(map['tested_at'], testedAt.toIso8601String());
    });

    test('accuracy = 1.0 serialized as double', () {
      final map = baseResult(accuracy: 1.0).toMap();
      expect(map['accuracy'], 1.0);
    });

    test('accuracy = 0.0 serialized as double', () {
      final map = baseResult(accuracy: 0.0).toMap();
      expect(map['accuracy'], 0.0);
    });
  });

  group('VerseTestResult.fromMap', () {
    test('round-trip preserves all fields', () {
      final original = baseResult();
      final restored = VerseTestResult.fromMap(original.toMap());
      expect(restored.verseId, original.verseId);
      expect(restored.accuracy, original.accuracy);
      expect(restored.testMode, original.testMode);
      expect(restored.testFormat, original.testFormat);
      expect(restored.testedAt, original.testedAt);
    });

    test('accuracy as int (SQLite can return int for 1.0) converted to double', () {
      final map = baseResult().toMap();
      map['accuracy'] = 1; // int, not double
      final r = VerseTestResult.fromMap(map);
      expect(r.accuracy, 1.0);
      expect(r.accuracy, isA<double>());
    });

    test('accuracy as double preserved', () {
      final r = VerseTestResult.fromMap(baseResult(accuracy: 0.75).toMap());
      expect(r.accuracy, 0.75);
    });
  });

  group('TestSessionResult.averageAccuracy', () {
    test('empty results → 0.0 (no division by zero)', () {
      final session = TestSessionResult(verseResults: [], sessionAt: testedAt);
      expect(session.averageAccuracy, 0.0);
    });

    test('single result → returns that accuracy', () {
      final session = TestSessionResult(
        verseResults: [baseResult(accuracy: 0.6)],
        sessionAt: testedAt,
      );
      expect(session.averageAccuracy, closeTo(0.6, 0.0001));
    });

    test('all perfect scores → 1.0', () {
      final session = TestSessionResult(
        verseResults: [
          baseResult(accuracy: 1.0),
          baseResult(accuracy: 1.0),
          baseResult(accuracy: 1.0),
        ],
        sessionAt: testedAt,
      );
      expect(session.averageAccuracy, 1.0);
    });

    test('all zero scores → 0.0', () {
      final session = TestSessionResult(
        verseResults: [
          baseResult(accuracy: 0.0),
          baseResult(accuracy: 0.0),
        ],
        sessionAt: testedAt,
      );
      expect(session.averageAccuracy, 0.0);
    });

    test('arithmetic mean — mixed scores', () {
      final session = TestSessionResult(
        verseResults: [
          baseResult(accuracy: 1.0),
          baseResult(accuracy: 0.5),
          baseResult(accuracy: 0.0),
        ],
        sessionAt: testedAt,
      );
      expect(session.averageAccuracy, closeTo(0.5, 0.0001));
    });

    test('mean of two scores rounds correctly', () {
      final session = TestSessionResult(
        verseResults: [
          baseResult(accuracy: 0.8),
          baseResult(accuracy: 0.6),
        ],
        sessionAt: testedAt,
      );
      expect(session.averageAccuracy, closeTo(0.7, 0.0001));
    });
  });
}
