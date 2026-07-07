import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';

/// Dark-theme confidence badges render outlined (no fill) rather than
/// filled containers — chosen for better legibility against the dark
/// surface than the filled MD3 container tokens. Colors picked by hand
/// against the app's dark surface (#1C1917); see docs/features for the
/// prototype this was selected from.
const Map<String, Color> _darkOutlineColors = {
  'Pending': Color(0xFF9AA6A9),
  'Weak': Color(0xFFDF6961),
  'Learning': Color(0xFFDFA84D),
  'Strong': Color(0xFF4ABE80),
};

class ConfidenceBadge extends StatelessWidget {
  final double? accuracy;
  final String verseRef;

  const ConfidenceBadge({super.key, required this.accuracy, required this.verseRef});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

    final outlineColor = _darkOutlineColors[tier]!;
    final effectiveFg = isDark ? outlineColor : fg;
    final effectiveBg = isDark ? Colors.transparent : bg;

    return Semantics(
      label: 'Confidence: $tier — $verseRef',
      excludeSemantics: true,
      child: Chip(
        avatar: Icon(icon, color: effectiveFg, size: 16),
        backgroundColor: effectiveBg,
        shape: isDark
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: outlineColor, width: 1.3),
              )
            : null,
        label: Text(tier, style: tt.labelSmall?.copyWith(color: effectiveFg)),
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
