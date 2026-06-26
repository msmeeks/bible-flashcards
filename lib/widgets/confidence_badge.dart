import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';

class ConfidenceBadge extends StatelessWidget {
  final double? accuracy;
  final String verseRef;

  const ConfidenceBadge({super.key, required this.accuracy, required this.verseRef});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final String tier;
    final Color bg;
    final Color fg;
    final IconData icon;

    if (accuracy == null) {
      tier = 'Pending';
      bg = cs.surfaceContainerHighest;
      fg = cs.onSurfaceVariant;
      icon = Symbols.schedule_rounded;
    } else if (accuracy! < 0.7) {
      tier = 'Weak';
      bg = cs.errorContainer;
      fg = cs.onErrorContainer;
      icon = Symbols.cancel_rounded;
    } else if (accuracy! < 0.9) {
      tier = 'Learning';
      bg = cs.warningContainer;
      fg = cs.onWarningContainer;
      icon = Symbols.warning_rounded;
    } else {
      tier = 'Strong';
      bg = cs.successContainer;
      fg = cs.onSuccessContainer;
      icon = Symbols.check_circle_rounded;
    }

    return Semantics(
      label: 'Confidence: $tier — $verseRef',
      excludeSemantics: true,
      child: Chip(
        avatar: Icon(icon, color: fg, size: 16),
        backgroundColor: bg,
        label: Text(tier, style: tt.labelSmall?.copyWith(color: fg)),
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
