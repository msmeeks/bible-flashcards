import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/verse.dart';
import 'audio_service.dart';
import 'notification_service.dart';

/// Picks the verse for an interrupt: [verseOfWeek] with weight [probability],
/// otherwise a random pick from [memorizedVerses].
@visibleForTesting
Verse? pickVerseForInterrupt({
  required Random random,
  required double probability,
  required Verse? verseOfWeek,
  required List<Verse> memorizedVerses,
}) {
  if (verseOfWeek != null && random.nextDouble() < probability) {
    return verseOfWeek;
  }
  if (memorizedVerses.isEmpty) return verseOfWeek;
  return memorizedVerses[random.nextInt(memorizedVerses.length)];
}

/// Tracks cumulative audio playback and interrupts with a memorized verse
/// once the configured [threshold] is exceeded.
///
/// Only accumulates time while audio is actively playing.  Does not auto-start;
/// the caller must invoke [startTracking] and [stopTracking] explicitly.
class AudioInterruptService {
  AudioInterruptService({
    required AudioService audioService,
    required NotificationService notificationService,
  })  : _audio = audioService,
        _notifications = notificationService;

  final AudioService _audio;
  final NotificationService _notifications;

  bool _tracking = false;
  Duration _accumulated = Duration.zero;
  DateTime? _tickStart;
  Timer? _timer;
  Duration _threshold = const Duration(hours: 1);
  double _interruptProbability = 0.5;
  List<Verse> _memorizedVerses = [];
  Verse? _verseOfWeek;
  final _rng = Random();

  bool get isTracking => _tracking;

  /// Begins accumulation tracking.  Call when audio starts playing.
  void startTracking({
    required Duration threshold,
    required double interruptProbability,
    required List<Verse> memorizedVerses,
    required Verse verseOfWeek,
  }) {
    _threshold = threshold;
    _interruptProbability = interruptProbability;
    _memorizedVerses = List<Verse>.from(memorizedVerses);
    _verseOfWeek = verseOfWeek;
    _tracking = true;
    _accumulated = Duration.zero;
    _tickStart = DateTime.now();
    // Check every 10 seconds while tracking.
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkThreshold(),
    );
  }

  /// Records a playback pause — stops accumulating until [resumeTracking].
  void pauseTracking() {
    if (!_tracking || _tickStart == null) return;
    _accumulated += DateTime.now().difference(_tickStart!);
    _tickStart = null;
  }

  /// Resumes accumulation after a pause.
  void resumeTracking() {
    if (!_tracking) return;
    _tickStart = DateTime.now();
  }

  /// Stops tracking and resets all state.
  void stopTracking() {
    _tracking = false;
    _timer?.cancel();
    _timer = null;
    _tickStart = null;
    _accumulated = Duration.zero;
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  void _checkThreshold() {
    if (!_tracking) return;

    final now = DateTime.now();
    final liveElapsed =
        _tickStart != null ? now.difference(_tickStart!) : Duration.zero;
    final total = _accumulated + liveElapsed;

    if (total < _threshold) return;

    final verse = _pickVerse();
    if (verse == null) {
      _resetAccumulator();
      return;
    }

    _resetAccumulator();
    _triggerInterrupt(verse);
  }

  void _triggerInterrupt(Verse verse) {
    unawaited(_audio.stop());
    unawaited(_notifications.showVerseInterruptNotification());
    unawaited(_audio.playVerse(verse));
  }

  Verse? _pickVerse() {
    return pickVerseForInterrupt(
      random: _rng,
      probability: _interruptProbability,
      verseOfWeek: _verseOfWeek,
      memorizedVerses: _memorizedVerses,
    );
  }

  void _resetAccumulator() {
    _accumulated = Duration.zero;
    _tickStart = _tracking ? DateTime.now() : null;
  }
}
