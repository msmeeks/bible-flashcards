import 'dart:async';

import 'package:bible_flashcards/models/verse.dart';
import 'package:bible_flashcards/services/audio_service.dart';
import 'package:bible_flashcards/services/notification_service.dart';

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

class FakeNotificationService extends NotificationService {
  int showCalls = 0;
  int cancelCalls = 0;

  @override
  Future<void> showPlaybackNotification() async {
    showCalls++;
  }

  @override
  Future<void> cancelNotification() async {
    cancelCalls++;
  }
}
