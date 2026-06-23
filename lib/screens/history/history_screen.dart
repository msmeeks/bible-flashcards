import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/tracking_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _showAsTable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TrackingProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Activity History')),
      body: Consumer<TrackingProvider>(
        builder: (context, tracking, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StreakCard(streak: tracking.streak, tt: tt, cs: cs),
              const SizedBox(height: 16),
              _WeeklyChart(
                counts: tracking.last7DaysCounts,
                showAsTable: _showAsTable,
                onToggleTable: () =>
                    setState(() => _showAsTable = !_showAsTable),
                tt: tt,
                cs: cs,
              ),
              const SizedBox(height: 16),
              _TestScoreChart(
                scores: tracking.last30DaysTestScores,
                showAsTable: _showAsTable,
                onToggleTable: () =>
                    setState(() => _showAsTable = !_showAsTable),
                tt: tt,
                cs: cs,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Streak card
// ---------------------------------------------------------------------------

class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.streak,
    required this.tt,
    required this.cs,
  });

  final int streak;
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$streak day streak',
      child: Card(
        color: cs.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              Text(
                '$streak',
                style: tt.displaySmall?.copyWith(color: cs.tertiary),
              ),
              const SizedBox(height: 4),
              Text(
                'day streak',
                style: tt.labelMedium?.copyWith(color: cs.tertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weekly bar chart
// ---------------------------------------------------------------------------

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({
    required this.counts,
    required this.showAsTable,
    required this.onToggleTable,
    required this.tt,
    required this.cs,
  });

  final List<MapEntry<String, int>> counts;
  final bool showAsTable;
  final VoidCallback onToggleTable;
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final total = counts.fold(0, (s, e) => s + e.value);
    final perDay = counts.map((e) => '${e.key}: ${e.value}').join(', ');
    final summaryLabel = 'Verses reviewed this week by day — $perDay. Total: $total';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Last 7 Days', style: tt.titleMedium),
                ),
                Semantics(
                  label: showAsTable
                      ? 'Currently showing table. Switch to chart view'
                      : 'Currently showing chart. Switch to table view',
                  button: true,
                  excludeSemantics: true,
                  child: TextButton(
                    onPressed: onToggleTable,
                    child: Text(showAsTable ? 'Show chart' : 'Show as table'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (showAsTable)
              _WeeklyTable(counts: counts, tt: tt, cs: cs)
            else
              Semantics(
                label: summaryLabel,
                excludeSemantics: true,
                child: SizedBox(height: 160, child: _buildBarChart()),
              ),
          ],
        ),
      ),
    );
  }

  BarChart _buildBarChart() {
    final maxY = counts.isEmpty
        ? 1.0
        : counts
              .map((e) => e.value.toDouble())
              .reduce((a, b) => a > b ? a : b)
              .clamp(1.0, double.infinity);

    return BarChart(
      BarChartData(
        maxY: maxY + 1,
        barGroups: counts.asMap().entries.map((entry) {
          final idx = entry.key;
          final count = entry.value.value.toDouble();
          return BarChartGroupData(
            x: idx,
            barRods: [
              BarChartRodData(
                toY: count,
                color: cs.primary,
                width: 16,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= counts.length) {
                  return const SizedBox.shrink();
                }
                final date = counts[idx].key;
                final parts = date.split('-');
                final label = parts.length == 3
                    ? '${parts[1]}/${parts[2]}'
                    : date;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label,
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: cs.outline.withValues(alpha: 0.2),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _WeeklyTable extends StatelessWidget {
  const _WeeklyTable({
    required this.counts,
    required this.tt,
    required this.cs,
  });

  final List<MapEntry<String, int>> counts;
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Reviews'), numeric: true),
      ],
      rows: counts
          .map(
            (e) => DataRow(
              cells: [
                DataCell(Text(e.key)),
                DataCell(Text('${e.value}')),
              ],
            ),
          )
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// 30-day test score chart
// ---------------------------------------------------------------------------

class _TestScoreChart extends StatelessWidget {
  const _TestScoreChart({
    required this.scores,
    required this.showAsTable,
    required this.onToggleTable,
    required this.tt,
    required this.cs,
  });

  final List<double> scores;
  final bool showAsTable;
  final VoidCallback onToggleTable;
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Test Scores (30 days)', style: tt.titleMedium),
              const SizedBox(height: 12),
              Text(
                'No test results yet.',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final avg = scores.reduce((a, b) => a + b) / scores.length;
    final perScore = scores
        .asMap()
        .entries
        .map((e) => 'Test ${e.key + 1}: ${(e.value * 100).round()}%')
        .join(', ');
    final summaryLabel =
        'Test scores over 30 days — $perScore. Average: ${(avg * 100).round()}%';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Test Scores (30 days)', style: tt.titleMedium),
                ),
                Semantics(
                  label: showAsTable
                      ? 'Currently showing table. Switch to chart view'
                      : 'Currently showing chart. Switch to table view',
                  button: true,
                  excludeSemantics: true,
                  child: TextButton(
                    onPressed: onToggleTable,
                    child:
                        Text(showAsTable ? 'Show chart' : 'Show as table'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (showAsTable)
              _ScoreTable(scores: scores, tt: tt, cs: cs)
            else
              Semantics(
                label: summaryLabel,
                excludeSemantics: true,
                child: SizedBox(height: 160, child: _buildLineChart()),
              ),
          ],
        ),
      ),
    );
  }

  LineChart _buildLineChart() {
    final spots = scores
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value * 100))
        .toList();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: cs.primary,
            barWidth: 2,
            dotData: FlDotData(
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 3,
                    color: cs.primary,
                    strokeColor: cs.surface,
                    strokeWidth: 1,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: cs.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}%',
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: cs.outline.withValues(alpha: 0.2),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _ScoreTable extends StatelessWidget {
  const _ScoreTable({required this.scores, required this.tt, required this.cs});

  final List<double> scores;
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Test #'), numeric: true),
        DataColumn(label: Text('Score'), numeric: true),
      ],
      rows: scores
          .asMap()
          .entries
          .map(
            (e) => DataRow(
              cells: [
                DataCell(Text('${e.key + 1}')),
                DataCell(Text('${(e.value * 100).round()}%')),
              ],
            ),
          )
          .toList(),
    );
  }
}
