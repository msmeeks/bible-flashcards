import 'package:flutter/material.dart';

import '../models/verse.dart';
import '../theme/app_colors.dart';

/// Displays a [Verse] with colour-coded status and correct theme tokens.
///
/// Background:
/// - Verse-of-week  → tertiaryContainer
/// - Memorized      → surfaceVariant
/// - Available      → secondaryContainer
class VerseCard extends StatelessWidget {
  final Verse verse;
  final VoidCallback? onTap;

  const VerseCard({super.key, required this.verse, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    final backgroundColor = verse.isVerseOfWeek
        ? cs.tertiaryContainer
        : verse.isMemorized
            ? cs.surfaceVariant
            : cs.secondaryContainer;

    final (chipLabel, chipIcon, chipColor, chipTextColor) = _statusChip(cs);

    return Semantics(
      label: '${verse.reference}. ${verse.text}. '
          '${verse.isVerseOfWeek ? 'Verse of the week.' : ''}'
          '${verse.isMemorized ? 'Memorized.' : 'Available.'}',
      button: onTap != null,
      child: Card(
        color: backgroundColor,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        verse.reference,
                        style: tt.titleSmall,
                      ),
                    ),
                    _StatusChip(
                      label: chipLabel,
                      icon: chipIcon,
                      color: chipColor,
                      textColor: chipTextColor,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  verse.text,
                  style: tt.bodyLarge,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  verse.translation,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (String, IconData, Color, Color) _statusChip(ColorScheme cs) {
    if (verse.isVerseOfWeek) {
      return (
        'This Week',
        Icons.star_rounded,
        cs.tertiaryContainer,
        cs.onTertiaryContainer,
      );
    }
    if (verse.isMemorized) {
      return (
        'Memorized',
        Icons.check_circle_rounded,
        cs.successContainer,
        cs.onSuccessContainer,
      );
    }
    return (
      'Available',
      Icons.circle_outlined,
      cs.outline,
      cs.onSurface,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;

  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: tt.labelMedium?.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}
