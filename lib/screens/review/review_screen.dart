import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../providers/audio_provider.dart';
import '../../providers/verse_provider.dart';
import '../../widgets/review_count_controls.dart';
import 'review_play_screen.dart';
import 'review_show_screen.dart';

enum _ReviewFormat { show, play }

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _reviewCount = 5;
  bool _includeVerseOfWeek = true;
  _ReviewFormat _format = _ReviewFormat.show;

  void _start(VerseProvider provider) {
    final verses = provider.getRandomMemorizedVerses(
      _reviewCount,
      includeVerseOfWeek: _includeVerseOfWeek,
    );

    if (_format == _ReviewFormat.play) {
      context.read<AudioProvider>().playQueue(verses);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const ReviewPlayScreen(),
          fullscreenDialog: true,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewShowScreen(verses: verses),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: Consumer<VerseProvider>(
        builder: (context, provider, _) {
          final memorizedCount = provider.memorizedVerses.length;

          if (memorizedCount == 0) {
            return const _EmptyReviewState();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ReviewCountControls(
                  count: _reviewCount,
                  memorizedCount: memorizedCount,
                  includeVerseOfWeek: _includeVerseOfWeek,
                  onCountChanged: (value) =>
                      setState(() => _reviewCount = value),
                  onVowChanged: (value) =>
                      setState(() => _includeVerseOfWeek = value),
                ),
                const SizedBox(height: 24),
                const SectionLabel('Format'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Show'),
                      selected: _format == _ReviewFormat.show,
                      onSelected: (_) =>
                          setState(() => _format = _ReviewFormat.show),
                    ),
                    ChoiceChip(
                      label: const Text('Play'),
                      selected: _format == _ReviewFormat.play,
                      onSelected: (_) =>
                          setState(() => _format = _ReviewFormat.play),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => _start(provider),
                    icon: const Icon(Symbols.play_arrow_rounded),
                    label: const Text('Start'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyReviewState extends StatelessWidget {
  const _EmptyReviewState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.menu_book_rounded,
              size: 64,
              color: cs.onSurfaceVariant,
              semanticLabel: '',
            ),
            const SizedBox(height: 16),
            Text(
              'No memorized verses yet',
              style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
