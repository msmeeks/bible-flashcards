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
  // Incremented on each start so stale loop iterations self-terminate.
  int _generation = 0;
  List<Verse> _verses = [];
  final _rng = Random();

  bool get isReviewActive => _active;

  /// Starts the review loop using [verses].
  ///
  /// [verseOfWeekId] is reserved for future prioritisation.
  void startReview(
    List<Verse> verses, {
    required String verseOfWeekId,
  }) {
    if (_active) return;
    if (verses.isEmpty) return;

    _active = true;
    _generation++;
    _verses = List<Verse>.from(verses);
    _runLoop(_generation);
  }

  /// Stops the review loop and any current playback.
  Future<void> stopReview() async {
    _active = false;
    _generation++; // invalidates any in-flight loop iteration
    await _audioService.stop();
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  Future<void> _runLoop(int generation) async {
    if (_verses.isEmpty) return;
    final pool = List<Verse>.from(_verses)..shuffle(_rng);
    var index = 0;

    while (_active && _generation == generation) {
      final verse = pool[index % pool.length];
      index++;

      await _audioService.playVerse(verse);

      if (!_active || _generation != generation) break;

      // Brief inter-verse pause.
      await Future<void>.delayed(const Duration(seconds: 3));

      if (!_active || _generation != generation) break;

      // Reshuffle when we cycle through the full pool.
      if (index % pool.length == 0) pool.shuffle(_rng);
    }
  }
}
