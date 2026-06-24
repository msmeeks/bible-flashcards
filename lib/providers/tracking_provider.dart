import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../utils/date_format.dart';

class TrackingProvider extends ChangeNotifier {
  final DatabaseHelper _db;

  int _streak = 0;
  int _totalVersesReviewed = 0;
  List<MapEntry<String, int>> _last7DaysCounts = [];
  List<MapEntry<DateTime, double>> _last30DaysTestScores = [];

  TrackingProvider(this._db);

  int get streak => _streak;
  int get totalVersesReviewed => _totalVersesReviewed;
  List<MapEntry<String, int>> get last7DaysCounts => _last7DaysCounts;
  List<MapEntry<DateTime, double>> get last30DaysTestScores =>
      _last30DaysTestScores;

  Future<void> load() async {
    final rows = await _db.getEngagementLog();
    final testRows = await _db.getTestResultsRaw();

    _totalVersesReviewed = rows
        .where((r) => r['event_type'] == 'flashcard_tap')
        .fold(0, (sum, r) => sum + (r['count'] as int));

    _streak = computeStreak(rows);
    _last7DaysCounts = computeLast7Days(rows);
    _last30DaysTestScores = computeLast30DaysScores(testRows);

    notifyListeners();
  }

  @visibleForTesting
  static int computeStreak(List<Map<String, Object?>> rows) {
    final activeDays = rows.map((r) => r['date'] as String).toSet();
    // If today has no activity yet, start from yesterday so a live streak
    // doesn't reset every morning before the first tap.
    final today = isoDateKey(DateTime.now());
    var day = activeDays.contains(today)
        ? DateTime.now()
        : DateTime.now().subtract(const Duration(days: 1));

    var streak = 0;
    while (activeDays.contains(isoDateKey(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @visibleForTesting
  static List<MapEntry<String, int>> computeLast7Days(
    List<Map<String, Object?>> rows,
  ) {
    final counts = <String, int>{};
    for (final r in rows) {
      final date = r['date'] as String;
      final count = r['count'] as int;
      counts[date] = (counts[date] ?? 0) + count;
    }

    final result = <MapEntry<String, int>>[];
    for (var i = 6; i >= 0; i--) {
      final day = DateTime.now().subtract(Duration(days: i));
      result.add(MapEntry(isoDateKey(day), counts[isoDateKey(day)] ?? 0));
    }
    return result;
  }

  /// Returns one averaged entry per local day, sorted oldest-first for
  /// correct chart X-axis. Relies on `tested_at` being stored as a local
  /// (non-UTC) ISO timestamp — see DatabaseHelper.logTestResult.
  @visibleForTesting
  static List<MapEntry<DateTime, double>> computeLast30DaysScores(
    List<Map<String, Object?>> rows,
  ) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final filtered = rows.where((r) {
      final testedAt = DateTime.tryParse(r['tested_at'] as String? ?? '');
      return testedAt != null && testedAt.isAfter(cutoff);
    });

    final sums = <String, double>{};
    final counts = <String, int>{};
    final dayDates = <String, DateTime>{};
    for (final r in filtered) {
      final testedAt = DateTime.parse(r['tested_at'] as String);
      final key = isoDateKey(testedAt);
      final accuracy = (r['accuracy'] as num).toDouble();
      sums[key] = (sums[key] ?? 0) + accuracy;
      counts[key] = (counts[key] ?? 0) + 1;
      dayDates[key] = DateTime(testedAt.year, testedAt.month, testedAt.day);
    }

    final result = sums.keys
        .map((key) => MapEntry(dayDates[key]!, sums[key]! / counts[key]!))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return result;
  }
}
