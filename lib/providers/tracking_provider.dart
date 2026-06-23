import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';

class TrackingProvider extends ChangeNotifier {
  final DatabaseHelper _db;

  int _streak = 0;
  int _totalVersesReviewed = 0;
  List<MapEntry<String, int>> _last7DaysCounts = [];
  List<double> _last30DaysTestScores = [];

  TrackingProvider(this._db);

  int get streak => _streak;
  int get totalVersesReviewed => _totalVersesReviewed;
  List<MapEntry<String, int>> get last7DaysCounts => _last7DaysCounts;
  List<double> get last30DaysTestScores => _last30DaysTestScores;

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

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Exposed for testing.
  @visibleForTesting
  static int computeStreak(List<Map<String, Object?>> rows) {
    final activeDays = rows.map((r) => r['date'] as String).toSet();
    // If today has no activity yet, start from yesterday so a live streak
    // doesn't reset every morning before the first tap.
    final today = _dateKey(DateTime.now());
    var day = activeDays.contains(today)
        ? DateTime.now()
        : DateTime.now().subtract(const Duration(days: 1));

    var streak = 0;
    while (activeDays.contains(_dateKey(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Exposed for testing.
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
      result.add(MapEntry(_dateKey(day), counts[_dateKey(day)] ?? 0));
    }
    return result;
  }

  /// Exposed for testing. Returns scores sorted oldest-first for correct chart X-axis.
  @visibleForTesting
  static List<double> computeLast30DaysScores(List<Map<String, Object?>> rows) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final filtered = rows.where((r) {
      final testedAt = DateTime.tryParse(r['tested_at'] as String? ?? '');
      return testedAt != null && testedAt.isAfter(cutoff);
    }).toList()
      ..sort((a, b) {
        final ta = DateTime.parse(a['tested_at'] as String);
        final tb = DateTime.parse(b['tested_at'] as String);
        return ta.compareTo(tb);
      });
    return filtered.map((r) => (r['accuracy'] as num).toDouble()).toList();
  }
}
