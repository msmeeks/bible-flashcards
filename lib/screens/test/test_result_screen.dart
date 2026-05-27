import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../models/test_result.dart';
import '../../theme/app_colors.dart';

class TestResultScreen extends StatefulWidget {
  const TestResultScreen({super.key, required this.sessionResult});

  final TestSessionResult sessionResult;

  @override
  State<TestResultScreen> createState() => _TestResultScreenState();
}

class _TestResultScreenState extends State<TestResultScreen> {
  @override
  void initState() {
    super.initState();
    _persistResults();
  }

  Future<void> _persistResults() async {
    final db = DatabaseHelper();
    for (final result in widget.sessionResult.verseResults) {
      await db.insertTestResult(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accuracy = widget.sessionResult.averageAccuracy;
    final pct = (accuracy * 100).round();

    final Color scoreColor;
    if (accuracy >= 0.9) {
      scoreColor = cs.success;
    } else if (accuracy >= 0.7) {
      scoreColor = cs.warning;
    } else {
      scoreColor = cs.error;
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            Semantics(
              label: 'Score: $pct%',
              child: Text(
                '$pct%',
                style: tt.headlineLarge?.copyWith(color: scoreColor),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Text(
                _scoreLabel(accuracy),
                style: tt.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.sessionResult.verseResults.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final result =
                      widget.sessionResult.verseResults[index];
                  return _VerseResultCard(result: result);
                },
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Test Again'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      // Pop back to root (main scaffold)
                      Navigator.of(context)
                          .popUntil((route) => route.isFirst);
                    },
                    child: const Text('Go Home'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _scoreLabel(double accuracy) {
    if (accuracy >= 0.9) return 'Excellent work!';
    if (accuracy >= 0.7) return 'Good progress — keep it up!';
    return 'Keep practicing — you\'ll get there.';
  }
}

class _VerseResultCard extends StatelessWidget {
  const _VerseResultCard({required this.result});

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
                    formatLabel,
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
