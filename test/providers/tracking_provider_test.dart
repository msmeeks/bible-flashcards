import 'package:flutter_test/flutter_test.dart';

import 'package:bible_flashcards/providers/tracking_provider.dart';
import 'package:bible_flashcards/utils/date_format.dart';

String _dateKey(DateTime d) => isoDateKey(d);

void main() {
  // ---------------------------------------------------------------------------
  // computeStreak
  // ---------------------------------------------------------------------------
  group('TrackingProvider.computeStreak', () {
    test('empty rows → 0', () {
      expect(TrackingProvider.computeStreak([]), 0);
    });

    test('today only → 1', () {
      final rows = [
        {'date': _dateKey(DateTime.now()), 'event_type': 'flashcard_tap', 'count': 1},
      ];
      expect(TrackingProvider.computeStreak(rows), 1);
    });

    test('yesterday + day before, no today → 2 (grace period)', () {
      final rows = [
        {'date': _dateKey(DateTime.now().subtract(const Duration(days: 1))), 'event_type': 'flashcard_tap', 'count': 1},
        {'date': _dateKey(DateTime.now().subtract(const Duration(days: 2))), 'event_type': 'flashcard_tap', 'count': 1},
      ];
      expect(TrackingProvider.computeStreak(rows), 2);
    });

    test('today + yesterday → 2', () {
      final rows = [
        {'date': _dateKey(DateTime.now()), 'event_type': 'flashcard_tap', 'count': 1},
        {'date': _dateKey(DateTime.now().subtract(const Duration(days: 1))), 'event_type': 'flashcard_tap', 'count': 1},
      ];
      expect(TrackingProvider.computeStreak(rows), 2);
    });

    test('today + 2 days ago, no yesterday → 1 (gap stops streak)', () {
      final rows = [
        {'date': _dateKey(DateTime.now()), 'event_type': 'flashcard_tap', 'count': 1},
        {'date': _dateKey(DateTime.now().subtract(const Duration(days: 2))), 'event_type': 'flashcard_tap', 'count': 1},
      ];
      expect(TrackingProvider.computeStreak(rows), 1);
    });

    test('only 8 days ago → 0', () {
      final rows = [
        {'date': _dateKey(DateTime.now().subtract(const Duration(days: 8))), 'event_type': 'flashcard_tap', 'count': 1},
      ];
      expect(TrackingProvider.computeStreak(rows), 0);
    });

    test('multiple event types same day count as one active day', () {
      final today = _dateKey(DateTime.now());
      final rows = [
        {'date': today, 'event_type': 'flashcard_tap', 'count': 3},
        {'date': today, 'event_type': 'test_complete', 'count': 1},
      ];
      expect(TrackingProvider.computeStreak(rows), 1);
    });
  });

  // ---------------------------------------------------------------------------
  // computeLast7Days
  // ---------------------------------------------------------------------------
  group('TrackingProvider.computeLast7Days', () {
    test('empty rows → 7 entries all 0', () {
      final result = TrackingProvider.computeLast7Days([]);
      expect(result.length, 7);
      expect(result.every((e) => e.value == 0), isTrue);
    });

    test('multiple event types same day summed', () {
      final today = _dateKey(DateTime.now());
      final rows = [
        {'date': today, 'event_type': 'flashcard_tap', 'count': 3},
        {'date': today, 'event_type': 'test_complete', 'count': 2},
      ];
      final result = TrackingProvider.computeLast7Days(rows);
      expect(result.last.value, 5);
    });

    test('row 8+ days ago excluded', () {
      final old = _dateKey(DateTime.now().subtract(const Duration(days: 8)));
      final rows = [
        {'date': old, 'event_type': 'flashcard_tap', 'count': 10},
      ];
      final result = TrackingProvider.computeLast7Days(rows);
      expect(result.every((e) => e.value == 0), isTrue);
    });

    test('row exactly 6 days ago appears at index 0', () {
      final sixDaysAgo = _dateKey(DateTime.now().subtract(const Duration(days: 6)));
      final rows = [
        {'date': sixDaysAgo, 'event_type': 'flashcard_tap', 'count': 5},
      ];
      final result = TrackingProvider.computeLast7Days(rows);
      expect(result.first.value, 5);
    });

    test('today appears at index 6', () {
      final today = _dateKey(DateTime.now());
      final rows = [
        {'date': today, 'event_type': 'flashcard_tap', 'count': 7},
      ];
      final result = TrackingProvider.computeLast7Days(rows);
      expect(result.last.value, 7);
    });
  });

  // ---------------------------------------------------------------------------
  // computeLast30DaysScores
  // ---------------------------------------------------------------------------
  group('TrackingProvider.computeLast30DaysScores', () {
    test('empty rows → empty', () {
      expect(TrackingProvider.computeLast30DaysScores([]), isEmpty);
    });

    test('exactly at cutoff excluded (strict isAfter)', () {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final rows = [
        {'tested_at': cutoff.toIso8601String(), 'accuracy': 0.9},
      ];
      expect(TrackingProvider.computeLast30DaysScores(rows), isEmpty);
    });

    test('1 second after cutoff included', () {
      final justAfter = DateTime.now()
          .subtract(const Duration(days: 30))
          .add(const Duration(seconds: 1));
      final rows = [
        {'tested_at': justAfter.toIso8601String(), 'accuracy': 0.9},
      ];
      final result = TrackingProvider.computeLast30DaysScores(rows);
      expect(result, hasLength(1));
      expect(result.first.value, closeTo(0.9, 0.001));
    });

    test('31 days ago excluded', () {
      final old = DateTime.now().subtract(const Duration(days: 31));
      final rows = [
        {'tested_at': old.toIso8601String(), 'accuracy': 0.9},
      ];
      expect(TrackingProvider.computeLast30DaysScores(rows), isEmpty);
    });

    test('invalid tested_at silently dropped', () {
      final rows = [
        {'tested_at': 'not-a-date', 'accuracy': 0.9},
      ];
      expect(TrackingProvider.computeLast30DaysScores(rows), isEmpty);
    });

    test('results sorted oldest-first for correct chart X-axis', () {
      final now = DateTime.now();
      final rows = [
        {'tested_at': now.subtract(const Duration(days: 1)).toIso8601String(), 'accuracy': 0.8},
        {'tested_at': now.subtract(const Duration(days: 5)).toIso8601String(), 'accuracy': 0.6},
        {'tested_at': now.subtract(const Duration(days: 3)).toIso8601String(), 'accuracy': 0.7},
      ];
      final result = TrackingProvider.computeLast30DaysScores(rows);
      expect(result[0].value, closeTo(0.6, 0.001));
      expect(result[1].value, closeTo(0.7, 0.001));
      expect(result[2].value, closeTo(0.8, 0.001));
    });

    test('29 days ago included (safely inside the window)', () {
      final old = DateTime.now().subtract(const Duration(days: 29));
      final rows = [
        {'tested_at': old.toIso8601String(), 'accuracy': 0.75},
      ];
      final result = TrackingProvider.computeLast30DaysScores(rows);
      expect(result, hasLength(1));
    });

    test('valid rows kept when mixed with invalid tested_at rows', () {
      final valid = DateTime.now().subtract(const Duration(days: 1));
      final rows = [
        {'tested_at': valid.toIso8601String(), 'accuracy': 0.75},
        {'tested_at': 'not-a-date', 'accuracy': 0.5},
      ];
      final result = TrackingProvider.computeLast30DaysScores(rows);
      expect(result, hasLength(1));
      expect(result.first.value, closeTo(0.75, 0.001));
    });

    test('multiple same-day tests average correctly', () {
      final today = DateTime.now().subtract(const Duration(hours: 1));
      final rows = [
        {'tested_at': today.toIso8601String(), 'accuracy': 0.6},
        {'tested_at': today.add(const Duration(minutes: 5)).toIso8601String(), 'accuracy': 1.0},
      ];
      final result = TrackingProvider.computeLast30DaysScores(rows);
      expect(result, hasLength(1));
      expect(result.first.value, closeTo(0.8, 0.001));
      expect(
        result.first.key,
        DateTime(today.year, today.month, today.day),
      );
    });

    test('one test on a day passes through unchanged', () {
      final day = DateTime.now().subtract(const Duration(days: 2));
      final rows = [
        {'tested_at': day.toIso8601String(), 'accuracy': 0.55},
      ];
      final result = TrackingProvider.computeLast30DaysScores(rows);
      expect(result, hasLength(1));
      expect(result.first.value, closeTo(0.55, 0.001));
      expect(result.first.key, DateTime(day.year, day.month, day.day));
    });

    test('two different days produce two entries sorted ascending', () {
      final now = DateTime.now();
      final dayMinus1 = now.subtract(const Duration(days: 1));
      final dayMinus2 = now.subtract(const Duration(days: 2));
      final rows = [
        {'tested_at': dayMinus1.toIso8601String(), 'accuracy': 0.9},
        {'tested_at': dayMinus2.toIso8601String(), 'accuracy': 0.5},
      ];
      final result = TrackingProvider.computeLast30DaysScores(rows);
      expect(result, hasLength(2));
      expect(result[0].value, closeTo(0.5, 0.001));
      expect(
        result[0].key,
        DateTime(dayMinus2.year, dayMinus2.month, dayMinus2.day),
      );
      expect(result[1].value, closeTo(0.9, 0.001));
      expect(
        result[1].key,
        DateTime(dayMinus1.year, dayMinus1.month, dayMinus1.day),
      );
    });

    test('records straddling midnight do not merge into one day', () {
      final midnightTonight = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      final justBeforeMidnight =
          midnightTonight.subtract(const Duration(minutes: 1));
      final justAfterMidnight =
          midnightTonight.add(const Duration(minutes: 1));
      final rows = [
        {'tested_at': justBeforeMidnight.toIso8601String(), 'accuracy': 0.2},
        {'tested_at': justAfterMidnight.toIso8601String(), 'accuracy': 0.8},
      ];
      final result = TrackingProvider.computeLast30DaysScores(rows);
      expect(result, hasLength(2));
      expect(
        result[0].key,
        DateTime(
          justBeforeMidnight.year,
          justBeforeMidnight.month,
          justBeforeMidnight.day,
        ),
      );
      expect(result[0].value, closeTo(0.2, 0.001));
      expect(result[1].key, midnightTonight);
      expect(result[1].value, closeTo(0.8, 0.001));
    });

    test('multiple days each with multiple tests average independently', () {
      final noonToday = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        12,
      );
      final dayA = noonToday.subtract(const Duration(days: 1));
      final dayB = noonToday.subtract(const Duration(days: 3));
      final rows = [
        {'tested_at': dayA.toIso8601String(), 'accuracy': 0.4},
        {'tested_at': dayA.add(const Duration(hours: 2)).toIso8601String(), 'accuracy': 1.0},
        {'tested_at': dayB.toIso8601String(), 'accuracy': 0.2},
        {'tested_at': dayB.add(const Duration(hours: 1)).toIso8601String(), 'accuracy': 0.4},
        {'tested_at': dayB.add(const Duration(hours: 2)).toIso8601String(), 'accuracy': 0.6},
      ];
      final result = TrackingProvider.computeLast30DaysScores(rows);
      expect(result, hasLength(2));
      expect(result[0].value, closeTo(0.4, 0.001)); // dayB average: (0.2+0.4+0.6)/3
      expect(result[1].value, closeTo(0.7, 0.001)); // dayA average: (0.4+1.0)/2
    });

    test('groups by local calendar day, not by 24h offset from now', () {
      final midnightTonight = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      final lateTonight = midnightTonight.add(const Duration(hours: 23, minutes: 59));
      final earlyToday = midnightTonight.add(const Duration(minutes: 1));
      final rows = [
        {'tested_at': earlyToday.toIso8601String(), 'accuracy': 0.2},
        {'tested_at': lateTonight.toIso8601String(), 'accuracy': 0.8},
      ];
      final result = TrackingProvider.computeLast30DaysScores(rows);
      expect(result, hasLength(1));
      expect(result.first.value, closeTo(0.5, 0.001));
    });
  });
}
