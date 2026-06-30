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
  List<Verse> _queue = [];
  int _currentIndex = 0;

  // Incremented on every playQueue()/playVerse()/stop() call. Captured by
  // _playCurrent() at invocation time so that if stop() fires while
  // _playCurrent() is suspended awaiting the notification, the resumed call
  // can detect the generation mismatch and bail out instead of resurrecting
  // a stale verse.
  int _generation = 0;

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

  /// Number of verses in the current playback queue (0 when idle, 1 for
  /// single-verse playback).
  int get queueLength => _queue.length;

  /// Verses in the current playback queue, read-only.
  List<Verse> get queue => List.unmodifiable(_queue);

  /// Index of the verse currently playing within the queue.
  int get currentQueueIndex => _currentIndex;

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
  ///
  /// Modeled internally as a one-element queue.
  Future<void> playVerse(Verse verse) => playQueue([verse]);

  /// Begins TTS playback of [verses] in order, auto-advancing to the next
  /// verse when each one completes. Shows the persistent playback notification.
  Future<void> playQueue(List<Verse> verses) async {
    _generation++;
    _queue = verses;
    _currentIndex = 0;
    await _playCurrent(_generation);
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
    _generation++;
    await _audio.stop();
    await _notifications.cancelNotification();
    _isPlaying = false;
    _currentVerse = null;
    _queue = [];
    _currentIndex = 0;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  Future<void> _playCurrent(int gen) async {
    if (_currentIndex >= _queue.length) return;
    final verse = _queue[_currentIndex];
    _currentVerse = verse;
    _isPlaying = true;
    notifyListeners();
    await _notifications.showPlaybackNotification();
    // stop() (or a newer playQueue/playVerse call) fired while we were
    // suspended above — do not resurrect a stale verse.
    if (_generation != gen) return;
    // Playback state stream drives subsequent UI updates.
    unawaited(_audio.playVerse(verse));
  }

  void _onPlaybackState(AudioPlaybackState state) {
    _playbackState = state;
    switch (state) {
      case AudioPlaybackState.speakingReference:
      case AudioPlaybackState.pausing:
      case AudioPlaybackState.speakingText:
        _isPlaying = true;
      case AudioPlaybackState.completed:
        if (_currentIndex + 1 < _queue.length) {
          _currentIndex++;
          unawaited(_playCurrent(_generation));
          return;
        }
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
