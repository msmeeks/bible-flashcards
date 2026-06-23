import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/verse.dart';
import '../theme/app_colors.dart';

enum FlashcardState { referenceOnly, textOnly, both }

class VerseCard extends StatefulWidget {
  final Verse verse;
  final FlashcardState initialState;

  const VerseCard({
    super.key,
    required this.verse,
    this.initialState = FlashcardState.referenceOnly,
  });

  @override
  State<VerseCard> createState() => _VerseCardState();
}

class _VerseCardState extends State<VerseCard> {
  late FlashcardState _state;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
  }

  void _cycleState() {
    setState(() {
      _state = switch (_state) {
        FlashcardState.referenceOnly => FlashcardState.textOnly,
        FlashcardState.textOnly => FlashcardState.both,
        FlashcardState.both => FlashcardState.referenceOnly,
      };
    });
  }

  String _semanticLabel() {
    final verse = widget.verse;
    final status = verse.isVerseOfWeek
        ? 'This Week'
        : verse.isMemorized
            ? 'Memorized'
            : 'Available';
    return switch (_state) {
      FlashcardState.referenceOnly =>
        '$status. Reference: ${verse.reference}. Tap to reveal text.',
      FlashcardState.textOnly =>
        '$status. Text: ${verse.text}. Tap to show reference and text.',
      FlashcardState.both =>
        '$status. ${verse.reference}. ${verse.text}. Tap to return to reference only.',
    };
  }

  Widget _buildContent(
    Verse verse,
    ColorScheme cs,
    TextTheme tt,
    bool showReference,
    bool showText,
    String chipLabel,
    IconData chipIcon,
    Color chipBg,
    Color chipBorder,
    Color chipTextColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showReference)
          Row(
            children: [
              Expanded(
                child: Text(verse.reference, style: tt.titleSmall),
              ),
              _StatusChip(
                label: chipLabel,
                icon: chipIcon,
                backgroundColor: chipBg,
                borderColor: chipBorder,
                textColor: chipTextColor,
              ),
            ],
          ),
        if (showText) ...[
          if (showReference) const SizedBox(height: 8),
          ExcludeSemantics(
            excluding: !showText,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
        ],
        // Expand icon excluded from AT — card label already guides user
        if (_state != FlashcardState.both)
          ExcludeSemantics(
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Symbols.expand_more_rounded),
                padding: const EdgeInsets.all(12),
                onPressed: () =>
                    setState(() => _state = FlashcardState.both),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final reducedMotion = MediaQuery.of(context).disableAnimations;

    final verse = widget.verse;

    final backgroundColor = verse.isVerseOfWeek
        ? cs.tertiaryContainer
        : verse.isMemorized
            ? cs.surfaceContainerHighest
            : cs.secondaryContainer;

    final (chipLabel, chipIcon, chipBg, chipBorder, chipTextColor) =
        _statusChip(cs);

    final showReference = _state != FlashcardState.textOnly;
    final showText = _state != FlashcardState.referenceOnly;

    final label = _semanticLabel();
    final content = _buildContent(
        verse, cs, tt, showReference, showText,
        chipLabel, chipIcon, chipBg, chipBorder, chipTextColor);

    return Semantics(
      button: true,
      label: label,
      child: Card(
        color: backgroundColor,
        margin: EdgeInsets.zero,
        child: Stack(
          children: [
            // Hidden live-region node announces state changes to AT separately
            // from the button role so TalkBack reads a clean label.
            Semantics(
              liveRegion: true,
              label: label,
              child: const SizedBox.shrink(),
            ),
            InkWell(
              onTap: _cycleState,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                // Skip AnimatedSize when animations disabled — Flutter's
                // RenderAnimatedSize triggers a layout assertion in test mode
                // when content size changes during performLayout.
                child: reducedMotion
                    ? content
                    : AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        alignment: Alignment.topCenter,
                        child: content,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, IconData, Color, Color, Color) _statusChip(ColorScheme cs) {
    if (widget.verse.isVerseOfWeek) {
      return (
        'This Week',
        Icons.star_rounded,
        cs.tertiary,
        cs.tertiary,
        cs.onTertiary,
      );
    }
    if (widget.verse.isMemorized) {
      return (
        'Memorized',
        Icons.check_circle_rounded,
        cs.successContainer,
        cs.success,
        cs.onSuccessContainer,
      );
    }
    return (
      'Available',
      Icons.circle_outlined,
      cs.surface,
      cs.outline,
      cs.onSurface,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  const _StatusChip({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          border: Border.all(color: borderColor),
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
      ),
    );
  }
}
