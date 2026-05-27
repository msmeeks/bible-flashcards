import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../models/verse.dart';
import '../../providers/audio_provider.dart';
import '../../providers/verse_provider.dart';
import '../../widgets/verse_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure verse list is fresh when the screen is first shown.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VerseProvider>().loadVerses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VerseProvider>(
      builder: (context, verseProvider, _) {
        final verseOfWeek = verseProvider.verseOfWeek;
        final memorized = verseProvider.memorizedVerses;
        final recentMemorized = memorized.take(5).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Bible Flashcards'),
            actions: [
              Tooltip(
                message: 'Settings',
                child: Semantics(
                  label: 'Settings',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Symbols.settings_rounded),
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/settings'),
                  ),
                ),
              ),
            ],
          ),
          body: verseProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: verseProvider.loadVerses,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    children: [
                      _VerseOfWeekSection(verseOfWeek: verseOfWeek),
                      const SizedBox(height: 20),
                      _QuickActionsRow(verseOfWeek: verseOfWeek),
                      const SizedBox(height: 20),
                      _MemorizedCountChip(count: memorized.length),
                      if (recentMemorized.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _RecentMemorizedRow(verses: recentMemorized),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Verse of the Week section
// ---------------------------------------------------------------------------

class _VerseOfWeekSection extends StatelessWidget {
  final Verse? verseOfWeek;

  const _VerseOfWeekSection({required this.verseOfWeek});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    if (verseOfWeek == null) {
      return Card(
        color: cs.tertiaryContainer,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Verse of the Week',
                style: tt.titleMedium?.copyWith(color: cs.onTertiaryContainer),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: 'No verse of the week selected',
                child: Text(
                  'No verse selected',
                  style:
                      tt.bodyMedium?.copyWith(color: cs.onTertiaryContainer),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/verse-add'),
                child: const Text('Choose Verse'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verse of the Week',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        VerseCard(
          verse: verseOfWeek!,
          onTap: () => Navigator.of(context)
              .pushNamed('/verse-detail', arguments: verseOfWeek!.id),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Quick actions row
// ---------------------------------------------------------------------------

class _QuickActionsRow extends StatelessWidget {
  final Verse? verseOfWeek;

  const _QuickActionsRow({required this.verseOfWeek});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonal(
            onPressed: () => Navigator.of(context).pushNamed('/test'),
            child: const Text('Start Test'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.tonal(
            onPressed: verseOfWeek == null
                ? null
                : () => context.read<AudioProvider>().playVerse(verseOfWeek!),
            child: const Text('Play Audio'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Memorized count chip
// ---------------------------------------------------------------------------

class _MemorizedCountChip extends StatelessWidget {
  final int count;

  const _MemorizedCountChip({required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Chip(
          backgroundColor: cs.primaryContainer,
          avatar: Icon(
            Symbols.check_circle_rounded,
            size: 16,
            color: cs.onPrimaryContainer,
          ),
          label: Text(
            '$count memorized',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: cs.onPrimaryContainer),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Recent memorized verses horizontal row
// ---------------------------------------------------------------------------

class _RecentMemorizedRow extends StatelessWidget {
  final List<Verse> verses;

  const _RecentMemorizedRow({required this.verses});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: verses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final verse = verses[index];
          return InputChip(
            label: Text(verse.reference),
            onPressed: () => Navigator.of(context)
                .pushNamed('/verse-detail', arguments: verse.id),
          );
        },
      ),
    );
  }
}
