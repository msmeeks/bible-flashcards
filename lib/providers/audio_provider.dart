import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/verse.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';

/// State provider for TTS audio playback.
///
/// Consumers observe [isPlaying], [currentVerse], [playbackState], and
/// [playbackStateLabel] to drive UI.
class AudioProvider extends ChangeNotifier {
  AudioProvider({
    required NotificationService notificationService,
    AudioService? audioService,
  })  : _audio = audioService ?? AudioService(),
        _notifications = notificationService {
    _stateSubscription = _audio.playbackStateStream.listen(_onPlaybackState);
  }

  final AudioService _audio;
  final NotificationService _notifications;
  late final StreamSubscription<AudioPlaybackState> _stateSubscription;

  bool _isPlaying = false;
  Verse? _currentVerse;
  AudioPlaybackState _playbackState = AudioPlaybackState.idle;

  // Position/duration are retained for widget API compatibility.
  // TTS does not expose real elapsed time.
  final Duration _position = Duration.zero;
  final Duration _duration = Duration.zero;

  bool get isPlaying => _isPlaying;
  bool get isCompleted => _playbackState == AudioPlaybackState.completed;
  Verse? get currentVerse => _currentVerse;
  Duration get position => _position;
  Duration get duration => _duration;
  AudioPlaybackState get playbackState => _playbackState;

  /// Human-readable label for the current playback phase, shown in the player bar.
  String get playbackStateLabel => switch (_playbackState) {
        AudioPlaybackState.speakingReference => 'Speaking reference…',
        AudioPlaybackState.pausing => 'Pausing…',
        AudioPlaybackState.speakingText => 'Speaking text…',
        AudioPlaybackState.completed => 'Completed',
        AudioPlaybackState.error => 'Error',
        AudioPlaybackState.idle => '',
      };

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Begins TTS playback of [verse] and shows the persistent playback notification.
  Future<void> playVerse(Verse verse) async {
    _currentVerse = verse;
    _isPlaying = true;
    notifyListeners();
    await _notifications.showPlaybackNotification(verse);
    // Playback state stream drives subsequent UI updates.
    unawaited(_audio.playVerse(verse));
  }

  /// Pauses TTS (stops the current utterance; resumes from current phase).
  Future<void> pause() async {
    await _audio.pause();
    _isPlaying = false;
    notifyListeners();
  }

  /// Resumes from the paused phase.
  Future<void> resume() async {
    if (_currentVerse == null || isCompleted) return;
    _isPlaying = true;
    notifyListeners();
    unawaited(_audio.resume());
  }

  /// Seek is not supported for TTS — kept for API compatibility.
  Future<void> seek(Duration position) async {}

  /// Stops all playback and dismisses the persistent notification.
  Future<void> stop() async {
    await _audio.stop();
    await _notifications.cancelNotification();
    _isPlaying = false;
    _currentVerse = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  void _onPlaybackState(AudioPlaybackState state) {
    _playbackState = state;
    switch (state) {
      case AudioPlaybackState.speakingReference:
      case AudioPlaybackState.pausing:
      case AudioPlaybackState.speakingText:
        _isPlaying = true;
      case AudioPlaybackState.completed:
        _isPlaying = false;
        // Keep _currentVerse so bar stays visible with disabled play button.
        unawaited(_notifications.cancelNotification());
      case AudioPlaybackState.error:
        _isPlaying = false;
        unawaited(_notifications.cancelNotification());
      case AudioPlaybackState.idle:
        _isPlaying = false;
        _currentVerse = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _stateSubscription.cancel();
    _audio.dispose();
    super.dispose();
  }
}
