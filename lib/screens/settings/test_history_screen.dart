import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../models/test_result.dart';
import '../../theme/app_colors.dart';

/// Formats a [DateTime] as "Mon, Jan 6, 2025" using only stdlib.
String _formatDay(DateTime dt) {
  const weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  // dt.weekday: 1=Monday … 7=Sunday
  final wd = weekdays[dt.weekday - 1];
  final mo = months[dt.month - 1];
  return '$wd, $mo ${dt.day}, ${dt.year}';
}

/// Formats a [DateTime] as "3:45 PM".
String _formatTime(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $period';
}

/// ISO-format date key "yyyy-MM-dd" from a [DateTime].
String _dayKey(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final mo = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$mo-$d';
}

class TestHistoryScreen extends StatefulWidget {
  const TestHistoryScreen({super.key});

  @override
  State<TestHistoryScreen> createState() => _TestHistoryScreenState();
}

class _TestHistoryScreenState extends State<TestHistoryScreen> {
  late Future<List<VerseTestResult>> _resultsFuture;
  final DatabaseHelper _db = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  void _loadResults() {
    _resultsFuture = _db.getTestResults();
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('Clear Test History'),
          content: const Text(
            'This will permanently delete all past test results. '
            'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await _db.clearTestHistory();
      setState(_loadResults);
    }
  }

  /// Groups results by calendar day key.
  Map<String, List<VerseTestResult>> _groupByDay(
      List<VerseTestResult> results) {
    final map = <String, List<VerseTestResult>>{};
    for (final r in results) {
      final key = _dayKey(r.testedAt);
      map.putIfAbsent(key, () => []).add(r);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test History')),
      body: FutureBuilder<List<VerseTestResult>>(
        future: _resultsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final results = snapshot.data ?? [];

          if (results.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No test history yet.\nComplete a test to see results here.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final grouped = _groupByDay(results);
          final days = grouped.keys.toList();

          // Build a flat list of items: header + entries per day
          final items = <_ListItem>[];
          for (final day in days) {
            items.add(_ListItem.header(day));
            for (final r in grouped[day]!) {
              items.add(_ListItem.result(r));
            }
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item.isHeader) {
                      return _DayHeader(dateKey: item.header!);
                    }
                    return _HistoryResultCard(result: item.result!);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor:
                        Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Clear History'),
                  onPressed: _confirmClearHistory,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Internal helper to represent either a date-header or a result row.
class _ListItem {
  const _ListItem._({this.header, this.result});

  final String? header;
  final VerseTestResult? result;

  bool get isHeader => header != null;

  factory _ListItem.header(String day) => _ListItem._(header: day);
  factory _ListItem.result(VerseTestResult r) => _ListItem._(result: r);
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.dateKey});

  final String dateKey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final date = DateTime.parse(dateKey);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 6),
      child: Text(
        _formatDay(date),
        style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}

class _HistoryResultCard extends StatelessWidget {
  const _HistoryResultCard({required this.result});

  final VerseTestResult result;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pct = (result.accuracy * 100).round();

    final Color badgeBg;
    final Color badgeFg;
    final IconData badgeIcon;

    if (result.accuracy >= 0.9) {
      badgeBg = cs.successContainer;
      badgeFg = cs.onSuccessContainer;
      badgeIcon = Icons.check_circle_outline_rounded;
    } else if (result.accuracy >= 0.7) {
      badgeBg = cs.warningContainer;
      badgeFg = cs.onWarningContainer;
      badgeIcon = Icons.warning_amber_rounded;
    } else {
      badgeBg = cs.errorContainer;
      badgeFg = cs.onErrorContainer;
      badgeIcon = Icons.cancel_outlined;
    }

    final formatLabel = switch (result.testFormat) {
      'recite' => 'Recite',
      'type' => 'Type',
      'fill_blank' => 'Fill Blanks',
      _ => result.testFormat,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.verseId, style: tt.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    '$formatLabel · ${_formatTime(result.testedAt)}',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Chip(
              avatar: Icon(badgeIcon, size: 16, color: badgeFg),
              label: Text(
                '$pct%',
                style: tt.labelMedium?.copyWith(color: badgeFg),
              ),
              backgroundColor: badgeBg,
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          ],
        ),
      ),
    );
  }
}
