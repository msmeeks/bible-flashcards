import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';

enum BannerSeverity { error, warning }

/// Inline error/warning banner used by forms to surface validation and
/// network failures. Always present in the tree (with an empty live-region
/// label) so screen readers announce the transition when [message] changes,
/// matching the pattern used elsewhere for transient form status text.
class InlineStatusBanner extends StatelessWidget {
  const InlineStatusBanner({
    super.key,
    required this.severity,
    required this.message,
    this.filled = true,
  });

  final BannerSeverity severity;
  final String? message;

  /// Whether the message renders on a colored [Card] surface. Set false to
  /// match a banner that previously rendered as plain inline text.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isError = severity == BannerSeverity.error;
    final icon = isError ? Symbols.error_rounded : Symbols.warning_rounded;
    // Unfilled banners sit directly on the scaffold background, so they use
    // the plain error color; filled banners sit on a tinted Card surface, so
    // they use the matching "on container" color for contrast.
    final foreground = isError
        ? (filled ? cs.onErrorContainer : cs.error)
        : cs.onWarningContainer;

    final content = message == null
        ? const SizedBox.shrink()
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  message!,
                  style: tt.bodyMedium?.copyWith(color: foreground),
                ),
              ),
            ],
          );

    return Semantics(
      liveRegion: true,
      label: message ?? '',
      child: message == null
          ? const SizedBox.shrink()
          : filled
              ? Card(
                  color: isError ? cs.errorContainer : cs.warningContainer,
                  margin: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: content,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: content,
                ),
    );
  }
}
