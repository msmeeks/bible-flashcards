import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../database/database_helper.dart';
import '../../models/verse.dart';
import '../../providers/audio_provider.dart';
import '../../providers/verse_provider.dart';

class VerseDetailScreen extends StatefulWidget {
  const VerseDetailScreen({super.key});

  @override
  State<VerseDetailScreen> createState() => _VerseDetailScreenState();
}

class _VerseDetailScreenState extends State<VerseDetailScreen> {
  /// Currently displayed translation segment — UI-only for now.
  String _selectedTranslation = 'ESV';

  @override
  void initState() {
    super.initState();
    DatabaseHelper().logEngagement('flashcard_tap');
  }

  @override
  Widget build(BuildContext context) {
    final verseId = ModalRoute.of(context)!.settings.arguments as String;

    return Consumer<VerseProvider>(
      builder: (context, provider, _) {
        final allVerses = [
          ...provider.memorizedVerses,
          ...provider.availableVerses,
        ];

        Verse? verse;
        for (final v in allVerses) {
          if (v.id == verseId) {
            verse = v;
            break;
          }
        }

        if (verse == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Verse')),
            body: const Center(child: Text('Verse not found')),
          );
        }

        final tt = Theme.of(context).textTheme;

        return Scaffold(
          appBar: AppBar(
            title: Text(verse.reference),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Verse text — headlineLarge Lora
              Text(
                verse.text,
                style: tt.headlineLarge,
              ),
              const SizedBox(height: 20),

              // Translation selector
              _TranslationSelector(
                selected: _selectedTranslation,
                onChanged: (t) => setState(() => _selectedTranslation = t),
              ),
              const SizedBox(height: 20),

              // Metadata card
              _MetadataCard(verse: verse),
              const SizedBox(height: 32),

              // Primary action
              FilledButton(
                onPressed: () async {
                  await context
                      .read<VerseProvider>()
                      .setVerseOfWeek(verse!.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Set as Verse of the Week')),
                    );
                  }
                },
                child: const Text('Set as Verse of Week'),
              ),
              const SizedBox(height: 12),

              FilledButton.tonal(
                onPressed: () {
                  context.read<AudioProvider>().playVerse(verse!);
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Symbols.volume_up_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Play Audio'),
                  ],
                ),
              ),

              if (verse.isMemorized) ...[
                const SizedBox(height: 12),
                _RemoveMemorizedButton(verseId: verse.id),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Remove Memorized button — separated to keep the build method readable
// ---------------------------------------------------------------------------

class _RemoveMemorizedButton extends StatelessWidget {
  final String verseId;

  const _RemoveMemorizedButton({required this.verseId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      hint: 'Verse will move back to the available list',
      child: OutlinedButton(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Remove from memorized?'),
              content: const Text(
                  'This verse will move back to the Available list and all test history for it will be permanently deleted.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: TextButton.styleFrom(foregroundColor: cs.error),
                  child: const Text('Remove'),
                ),
              ],
            ),
          );
          if (confirmed == true && context.mounted) {
            await context.read<VerseProvider>().unmarkMemorized(verseId);
            if (context.mounted) {
              unawaited(SemanticsService.sendAnnouncement(
                View.of(context),
                'Verse removed from memorized',
                TextDirection.ltr,
              ));
              // Delay pop one frame so TalkBack can process the announcement before focus jumps.
              await Future<void>.delayed(Duration.zero);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Verse removed from memorized')),
                );
                Navigator.of(context).pop();
              }
            }
          }
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.error,
          side: BorderSide(color: cs.error),
        ),
        child: const Text('Remove from Memorized'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Translation selector
// ---------------------------------------------------------------------------

class _TranslationSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _TranslationSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Translation',
          style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'ESV', label: Text('ESV')),
            ButtonSegment(value: 'CSB', label: Text('CSB')),
            ButtonSegment(value: 'NLT', label: Text('NLT')),
          ],
          selected: {selected},
          onSelectionChanged: (values) {
            if (values.isNotEmpty) onChanged(values.first);
          },
        ),
        if (selected != 'ESV')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'TODO: CSB/NLT text not yet loaded',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Metadata card
// ---------------------------------------------------------------------------

class _MetadataCard extends StatelessWidget {
  final Verse verse;

  const _MetadataCard({required this.verse});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: cs.surfaceContainerLowest,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MetaRow(label: 'Pack', value: verse.packId),
            const SizedBox(height: 8),
            _MetaRow(label: 'Translation', value: verse.translation),
            if (verse.memorizedAt != null) ...[
              const SizedBox(height: 8),
              _MetaRow(
                label: 'Memorized',
                value: _formatDate(verse.memorizedAt!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(value, style: tt.bodyMedium),
        ),
      ],
    );
  }
}
