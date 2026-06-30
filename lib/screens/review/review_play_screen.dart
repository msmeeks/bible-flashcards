import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../providers/audio_provider.dart';
import '../../widgets/esv_copyright_footer.dart';
import '../settings/settings_screen.dart';

/// Fullscreen "Now Playing" presentation for a queued review session.
///
/// Pops itself once the queue finishes or the user stops playback.
class ReviewPlayScreen extends StatefulWidget {
  const ReviewPlayScreen({super.key});

  @override
  State<ReviewPlayScreen> createState() => _ReviewPlayScreenState();
}

class _ReviewPlayScreenState extends State<ReviewPlayScreen> {
  AudioProvider? _audioProvider;
  bool _popping = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<AudioProvider>();
    if (provider != _audioProvider) {
      _audioProvider?.removeListener(_onAudioChanged);
      _audioProvider = provider;
      provider.addListener(_onAudioChanged);
    }
  }

  void _onAudioChanged() {
    if (!mounted || _popping) return;
    if (_audioProvider?.currentVerse == null) {
      _popping = true;
      Navigator.of(context).pop();
    }
  }

  void _stop(AudioProvider audio) {
    _popping = true;
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => audio.stop());
  }

  @override
  void dispose() {
    _audioProvider?.removeListener(_onAudioChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing')),
      body: Consumer<AudioProvider>(
        builder: (context, audio, _) {
          if (audio.currentVerse == null) {
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
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (audio.playbackStateLabel.isNotEmpty)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        audio.playbackStateLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if (audio.queueLength > 1)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        'Playing ${audio.currentQueueIndex + 1} of ${audio.queueLength}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
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
                        excludeSemantics: true,
                        onTap: audio.isCompleted
                            ? null
                            : (audio.isPlaying ? audio.pause : audio.resume),
                        child: Tooltip(
                          message: audio.isPlaying ? 'Pause' : 'Resume',
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                shape: const CircleBorder(),
                                padding: EdgeInsets.zero,
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
                        excludeSemantics: true,
                        onTap: () => _stop(audio),
                        child: IconButton.filledTonal(
                          iconSize: 32,
                          icon: const Icon(Symbols.stop_rounded),
                          tooltip: 'Stop',
                          onPressed: () => _stop(audio),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  EsvCopyrightFooter(
                    hasEsvContent:
                        audio.queue.any((v) => v.translation == 'ESV'),
                    onViewFullTerms: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
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
