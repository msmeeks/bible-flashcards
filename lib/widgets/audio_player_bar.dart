import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/audio_provider.dart';

/// Persistent mini-player bar shown above the NavigationBar.
/// Only visible when [AudioProvider.currentVerse] is non-null.
/// Full implementation by the audio feature agent.
class AudioPlayerBar extends StatelessWidget {
  const AudioPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audio, _) {
        if (audio.currentVerse == null) return const SizedBox.shrink();

        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;

        return Container(
          decoration: BoxDecoration(
            color: cs.inverseSurface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  audio.currentVerse!.reference,
                  style: tt.titleSmall?.copyWith(color: cs.onInverseSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // TODO(audio-agent): add seek-back-5s, seek-forward-5s controls
              Semantics(
                label: audio.isPlaying ? 'Pause' : 'Play',
                child: IconButton(
                  icon: Icon(
                    audio.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: cs.onInverseSurface,
                  ),
                  tooltip: audio.isPlaying ? 'Pause' : 'Play',
                  onPressed: audio.isPlaying ? audio.pause : audio.resume,
                ),
              ),
              Semantics(
                label: 'Stop playback',
                child: IconButton(
                  icon: Icon(Icons.close_rounded, color: cs.onInverseSurface),
                  tooltip: 'Stop',
                  onPressed: audio.stop,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
