import 'dart:async';
import 'dart:math';

import '../models/verse.dart';
import 'audio_service.dart';

/// Manages the continuous audio review loop: plays a shuffled sequence of
/// verses via [AudioService], with a short pause between each verse.
class AudioReviewService {
  AudioReviewService(this._audioService);

  final AudioService _audioService;

  bool _active = false;
  StreamSubscription<AudioPlaybackState>? _stateSubscription;
  List<Verse> _verses = [];
  final _rng = Random();

  bool get isReviewActive => _active;

  /// Starts the review loop using [verses].
  ///
  /// [verseOfWeekId] is reserved for future prioritisation (e.g., ensuring the
  /// verse-of-week appears first). Currently the pool is randomly shuffled.
  void startReview(
    List<Verse> verses, {
    required String verseOfWeekId,
  }) {
    if (_active) return;
    if (verses.isEmpty) return;

    _active = true;
    _verses = List<Verse>.from(verses);
    _runLoop();
  }

  /// Stops the review loop and any current playback.
  Future<void> stopReview() async {
    _active = false;
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    await _audioService.stop();
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  Future<void> _runLoop() async {
    if (_verses.isEmpty) return;
    final pool = List<Verse>.from(_verses)..shuffle(_rng);
    var index = 0;

    while (_active) {
      final verse = pool[index % pool.length];
      index++;

      await _audioService.playVerse(verse);

      if (!_active) break;

      // Brief inter-verse pause.
      await Future<void>.delayed(const Duration(seconds: 3));

      if (!_active) break;

      // Reshuffle when we cycle through the full pool.
      if (index % pool.length == 0) pool.shuffle(_rng);
    }
  }
}
