import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../providers/audio_provider.dart';

/// Fullscreen "Now Playing" presentation for a queued review session.
///
/// Pops itself once the queue finishes or the user stops playback.
class ReviewPlayScreen extends StatefulWidget {
  const ReviewPlayScreen({super.key});

  @override
  State<ReviewPlayScreen> createState() => _ReviewPlayScreenState();
}

class _ReviewPlayScreenState extends State<ReviewPlayScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing')),
      body: Consumer<AudioProvider>(
        builder: (context, audio, _) {
          if (audio.currentVerse == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).pop();
            });
            return const SizedBox.shrink();
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    audio.currentVerse!.reference,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (audio.playbackStateLabel.isNotEmpty)
                    Text(
                      audio.playbackStateLabel,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  if (audio.queueLength > 1)
                    Text(
                      'Playing ${audio.currentQueueIndex + 1} of ${audio.queueLength}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Semantics(
                        label: audio.isCompleted
                            ? 'Playback completed'
                            : (audio.isPlaying ? 'Pause' : 'Resume'),
                        enabled: !audio.isCompleted,
                        button: true,
                        child: Tooltip(
                          message: audio.isPlaying ? 'Pause' : 'Resume',
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                shape: const CircleBorder(),
                              ),
                              onPressed: audio.isCompleted
                                  ? null
                                  : (audio.isPlaying
                                      ? audio.pause
                                      : audio.resume),
                              child: Icon(
                                audio.isPlaying
                                    ? Symbols.pause_rounded
                                    : Symbols.play_arrow_rounded,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Semantics(
                        label: 'Stop playback',
                        button: true,
                        child: IconButton.filledTonal(
                          iconSize: 32,
                          icon: const Icon(Symbols.stop_rounded),
                          tooltip: 'Stop',
                          onPressed: audio.stop,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
