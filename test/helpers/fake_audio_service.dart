import 'dart:async';

import 'package:bible_flashcards/models/verse.dart';
import 'package:bible_flashcards/services/audio_service.dart';
import 'package:bible_flashcards/services/notification_service.dart';
import 'package:bible_flashcards/services/system_audio_service.dart';

class FakeAudioService extends AudioService {
  final StreamController<AudioPlaybackState> _controller =
      StreamController<AudioPlaybackState>.broadcast();
  final List<Verse> playedVerses = [];
  int stopCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;

  @override
  Stream<AudioPlaybackState> get playbackStateStream => _controller.stream;

  @override
  Future<void> playVerse(Verse verse) async {
    playedVerses.add(verse);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _controller.add(AudioPlaybackState.idle);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
  }

  void emit(AudioPlaybackState state) => _controller.add(state);

  @override
  void dispose() {
    unawaited(_controller.close());
  }
}

/// Stands in for the Android system-audio channel.
///
/// [musicActiveResults] is consumed one entry per `isMusicActive` call so a
/// test can script a debounce sequence (e.g. `[false, true]`); once exhausted
/// the last value repeats.
class FakeSystemAudioService extends SystemAudioService {
  FakeSystemAudioService({
    List<bool> musicActiveResults = const [false],
    this.focusGranted = true,
  }) : musicActiveResults = List<bool>.from(musicActiveResults);

  final List<bool> musicActiveResults;
  bool focusGranted;

  int isMusicActiveCalls = 0;
  int requestFocusCalls = 0;
  int abandonFocusCalls = 0;

  /// Method names in call order, so tests can assert focus brackets playback.
  final List<String> calls = [];

  @override
  Future<bool> isMusicActive() async {
    calls.add('isMusicActive');
    final index = isMusicActiveCalls < musicActiveResults.length
        ? isMusicActiveCalls
        : musicActiveResults.length - 1;
    isMusicActiveCalls++;
    return musicActiveResults[index];
  }

  @override
  Future<bool> requestTransientFocus() async {
    calls.add('requestTransientFocus');
    requestFocusCalls++;
    return focusGranted;
  }

  @override
  Future<void> abandonFocus() async {
    calls.add('abandonFocus');
    abandonFocusCalls++;
  }
}

class FakeNotificationService extends NotificationService {
  int showCalls = 0;
  int cancelCalls = 0;
  int showInterruptCalls = 0;

  @override
  Future<void> showPlaybackNotification() async {
    showCalls++;
  }

  @override
  Future<void> cancelNotification() async {
    cancelCalls++;
  }

  @override
  Future<void> showVerseInterruptNotification() async {
    showInterruptCalls++;
  }
}
