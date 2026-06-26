import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../providers/audio_provider.dart';
import '../services/audio_service.dart';

/// Persistent mini-player bar shown above the [NavigationBar].
///
/// Only visible when [AudioProvider.currentVerse] is non-null.
/// Dismiss by swiping down — this stops playback.
class AudioPlayerBar extends StatelessWidget {
  const AudioPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audio, _) {
        if (audio.currentVerse == null) return const SizedBox.shrink();

        return Semantics(
          customSemanticsActions: {
            const CustomSemanticsAction(label: 'Dismiss player'): audio.stop,
          },
          child: Dismissible(
            key: const ValueKey('audio_player_bar'),
            direction: DismissDirection.down,
            onDismissed: (_) => audio.stop(),
            child: _AudioPlayerBarContent(audio: audio),
          ),
        );
      },
    );
  }
}

class _AudioPlayerBarContent extends StatelessWidget {
  const _AudioPlayerBarContent({required this.audio});

  final AudioProvider audio;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final progressValue = switch (audio.playbackState) {
      AudioPlaybackState.speakingReference => 0.2,
      AudioPlaybackState.pausing => 0.5,
      AudioPlaybackState.speakingText => 0.85,
      AudioPlaybackState.completed => 1.0,
      _ => 0.0,
    };

    return Container(
      decoration: BoxDecoration(
        color: cs.inverseSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress indicator — spans full width, 4dp height.
          SizedBox(
            height: 4,
            child: LinearProgressIndicator(
              value: progressValue,
              semanticsLabel: 'Playback progress',
              backgroundColor: cs.primaryContainer,
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
          ),
          // Verse reference + state label.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        audio.currentVerse!.reference,
                        style:
                            tt.titleSmall?.copyWith(color: cs.onInverseSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (audio.playbackStateLabel.isNotEmpty)
                        Text(
                          audio.playbackStateLabel,
                          style: tt.bodySmall?.copyWith(
                              color: cs.onInverseSurface.withAlpha(179)),
                        ),
                      if (audio.queueLength > 1)
                        Text(
                          'Playing ${audio.currentQueueIndex + 1} of ${audio.queueLength}',
                          style: tt.bodySmall?.copyWith(
                              color: cs.onInverseSurface.withAlpha(179)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Controls row.
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Previous verse — not implemented; disabled.
                const ExcludeSemantics(
                  child: Tooltip(
                    message: 'Previous',
                    child: IconButton(
                      icon: Icon(Symbols.skip_previous_rounded),
                      onPressed: null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Rewind — TTS has no real seek; disabled.
                const ExcludeSemantics(
                  child: Tooltip(
                    message: 'Rewind 5 seconds',
                    child: IconButton(
                      icon: Icon(Symbols.replay_5_rounded),
                      onPressed: null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Play / Pause — 48dp filled circle; disabled when completed.
                Semantics(
                  label: audio.isCompleted
                      ? 'Playback completed'
                      : (audio.isPlaying ? 'Pause' : 'Resume'),
                  enabled: !audio.isCompleted,
                  button: true,
                  child: Tooltip(
                    message: audio.isCompleted
                        ? 'Playback completed'
                        : (audio.isPlaying ? 'Pause' : 'Resume'),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: EdgeInsets.zero,
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          disabledBackgroundColor:
                              cs.onInverseSurface.withAlpha(31),
                          disabledForegroundColor:
                              cs.onInverseSurface.withAlpha(97),
                        ),
                        onPressed: audio.isCompleted
                            ? null
                            : (audio.isPlaying ? audio.pause : audio.resume),
                        child: Icon(
                          audio.isPlaying
                              ? Symbols.pause_rounded
                              : Symbols.play_arrow_rounded,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Forward — TTS has no real seek; disabled.
                const ExcludeSemantics(
                  child: Tooltip(
                    message: 'Forward 5 seconds',
                    child: IconButton(
                      icon: Icon(Symbols.forward_5_rounded),
                      onPressed: null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Stop.
                Semantics(
                  label: 'Stop playback',
                  child: Tooltip(
                    message: 'Stop playback',
                    child: IconButton(
                      icon: Icon(
                        Symbols.stop_rounded,
                        color: cs.onInverseSurface,
                      ),
                      onPressed: audio.stop,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
