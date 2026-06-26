import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/verse.dart';
import '../theme/app_colors.dart';
import 'confidence_badge.dart';

enum FlashcardState { referenceOnly, textOnly, both }

class VerseCard extends StatefulWidget {
  final Verse verse;
  final FlashcardState initialState;
  final Future<double?>? confidenceFuture;

  const VerseCard({
    super.key,
    required this.verse,
    this.initialState = FlashcardState.referenceOnly,
    this.confidenceFuture,
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
    Widget chipWidget,
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
              chipWidget,
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

    final showReference = _state != FlashcardState.textOnly;
    final showText = _state != FlashcardState.referenceOnly;

    final Widget chipWidget = widget.confidenceFuture != null
        ? FutureBuilder<double?>(
            future: widget.confidenceFuture,
            builder: (_, snap) => ConfidenceBadge(
              accuracy: snap.data,
              verseRef: verse.reference,
            ),
          )
        : _buildStatusChip(cs);

    final label = _semanticLabel();
    final content = _buildContent(
        verse, cs, tt, showReference, showText, chipWidget);

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

  Widget _buildStatusChip(ColorScheme cs) {
    if (widget.verse.isVerseOfWeek) {
      return _StatusChip(
        label: 'This Week',
        icon: Icons.star_rounded,
        backgroundColor: cs.tertiary,
        borderColor: cs.tertiary,
        textColor: cs.onTertiary,
      );
    }
    if (widget.verse.isMemorized) {
      return _StatusChip(
        label: 'Memorized',
        icon: Icons.check_circle_rounded,
        backgroundColor: cs.successContainer,
        borderColor: cs.success,
        textColor: cs.onSuccessContainer,
      );
    }
    return _StatusChip(
      label: 'Available',
      icon: Icons.circle_outlined,
      backgroundColor: cs.surface,
      borderColor: cs.outline,
      textColor: cs.onSurface,
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
