import 'package:flutter/material.dart';

/// Preset chip values shown alongside the count slider.
const List<int> reviewCountChips = [5, 10, 20];

/// Section header row — uppercase-styled label used to group form controls.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

/// Count slider + preset chips + verse-of-week toggle.
///
/// Caller owns [count] and [includeVerseOfWeek] state and passes
/// [onCountChanged] / [onVowChanged] callbacks.
class ReviewCountControls extends StatelessWidget {
  const ReviewCountControls({
    super.key,
    required this.count,
    required this.memorizedCount,
    required this.includeVerseOfWeek,
    required this.onCountChanged,
    required this.onVowChanged,
  });

  final int count;
  final int memorizedCount;
  final bool includeVerseOfWeek;
  final ValueChanged<int> onCountChanged;
  final ValueChanged<bool> onVowChanged;

  @override
  Widget build(BuildContext context) {
    if (memorizedCount == 0) {
      return const SectionLabel('No memorized verses yet');
    }

    final clampedCount = count.clamp(1, memorizedCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Number of verses'),
        Slider(
          min: 1,
          max: memorizedCount.toDouble(),
          divisions: memorizedCount > 1 ? memorizedCount - 1 : null,
          value: clampedCount.toDouble(),
          label: '$clampedCount',
          onChanged: (value) => onCountChanged(value.round()),
        ),
        Semantics(
          label: 'Number of verses — select a preset',
          explicitChildNodes: true,
          child: Wrap(
            spacing: 8,
            children: [
              for (final chipCount in reviewCountChips)
                if (chipCount <= memorizedCount)
                  FilterChip(
                    label: Text('$chipCount'),
                    selected: clampedCount == chipCount,
                    onSelected: (_) => onCountChanged(chipCount),
                  ),
              FilterChip(
                label: const Text('All'),
                selected: clampedCount == memorizedCount,
                onSelected: (_) => onCountChanged(memorizedCount),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include verse of the week'),
          value: includeVerseOfWeek,
          onChanged: onVowChanged,
        ),
      ],
    );
  }
}
