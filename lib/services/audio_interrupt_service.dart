import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/settings.dart';
import '../models/verse.dart';
import 'audio_service.dart';
import 'notification_service.dart';
import 'system_audio_service.dart';

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

/// Periodically inserts a memorized verse into the user's listening.
///
/// Every [interval] of elapsed tracked time the service considers playing a
/// verse. Under [AudioTriggerMode.whileOtherAudioPlaying] it only does so while
/// another app is actually playing audio, so a verse lands inside an audiobook
/// or podcast rather than out of silence. Playback holds transient audio focus
/// so that app ducks and then resumes.
///
/// Does not auto-start; the caller must invoke [startTracking] and
/// [stopTracking] explicitly.
class AudioInterruptService {
  AudioInterruptService({
    required AudioService audioService,
    required NotificationService notificationService,
    SystemAudioService? systemAudioService,
    Duration debounceDelay = const Duration(milliseconds: 300),
    int debounceSamples = 3,
  })  : _audio = audioService,
        _notifications = notificationService,
        _systemAudio = systemAudioService ?? SystemAudioService(),
        _debounceDelay = debounceDelay,
        _debounceSamples = debounceSamples;

  final AudioService _audio;
  final NotificationService _notifications;
  final SystemAudioService _systemAudio;

  /// Gap between `isMusicActive` samples, covering the brief silence between
  /// tracks or chapters so it does not read as "nothing is playing".
  final Duration _debounceDelay;
  final int _debounceSamples;

  bool _tracking = false;
  bool _firing = false;
  Duration _accumulated = Duration.zero;
  DateTime? _tickStart;
  Timer? _timer;
  Duration _interval = const Duration(hours: 1);
  AudioTriggerMode _triggerMode = AudioTriggerMode.whileOtherAudioPlaying;
  double _interruptProbability = 0.5;
  List<Verse> _memorizedVerses = [];
  Verse? _verseOfWeek;
  final _rng = Random();

  bool get isTracking => _tracking;

  /// Runs an immediate interval check without waiting for the periodic
  /// timer — lets tests exercise a firing deterministically.
  @visibleForTesting
  Future<void> debugFireInterval() => _checkInterval();

  /// Begins interval tracking. Call when the feature is enabled.
  void startTracking({
    required Duration interval,
    required AudioTriggerMode triggerMode,
    required double interruptProbability,
    required List<Verse> memorizedVerses,
    required Verse verseOfWeek,
  }) {
    _interval = interval;
    _triggerMode = triggerMode;
    _interruptProbability = interruptProbability;
    _memorizedVerses = List<Verse>.from(memorizedVerses);
    _verseOfWeek = verseOfWeek;
    _tracking = true;
    _accumulated = Duration.zero;
    _tickStart = DateTime.now();
    // Check every 10 seconds while tracking.
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_checkInterval()),
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

  Future<void> _checkInterval() async {
    if (!_tracking || _firing) return;

    final now = DateTime.now();
    final liveElapsed =
        _tickStart != null ? now.difference(_tickStart!) : Duration.zero;
    final total = _accumulated + liveElapsed;

    if (total < _interval) return;

    // Restart the clock up front: whether this interval plays or is skipped,
    // the next one is measured from here.
    _resetAccumulator();

    final verse = _pickVerse();
    if (verse == null) return;

    _firing = true;
    try {
      if (_triggerMode == AudioTriggerMode.whileOtherAudioPlaying &&
          !await _isOtherAudioActive()) {
        return;
      }
      // Tracking may have been switched off while we were sampling.
      if (!_tracking) return;
      await _playWithFocus(verse);
    } finally {
      _firing = false;
    }
  }

  /// Samples `isMusicActive` up to [_debounceSamples] times, returning true on
  /// the first positive so a momentary gap between tracks does not skip the
  /// interval.
  Future<bool> _isOtherAudioActive() async {
    for (var attempt = 0; attempt < _debounceSamples; attempt++) {
      if (await _systemAudio.isMusicActive()) return true;
      if (!_tracking) return false;
      if (attempt < _debounceSamples - 1) await Future.delayed(_debounceDelay);
    }
    return false;
  }

  /// Ducks other audio for the length of the verse, then restores it.
  Future<void> _playWithFocus(Verse verse) async {
    // A denial means something with a stronger claim holds focus (a call, for
    // instance) — stay silent rather than talk over it.
    if (!await _systemAudio.requestTransientFocus()) return;
    try {
      await _audio.stop();
      await _notifications.showVerseInterruptNotification();
      // playVerse resolves only once the reference→pause→text sequence has
      // finished, so focus is held for the whole verse.
      await _audio.playVerse(verse);
    } finally {
      await _systemAudio.abandonFocus();
    }
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
