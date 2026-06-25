import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:bible_flashcards/models/verse.dart';
import 'package:bible_flashcards/providers/audio_provider.dart';
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

Verse _verse(String id) => Verse(
      id: id,
      reference: 'Ref $id',
      text: 'Text $id',
      translation: 'ESV',
      packId: 'pack',
      addedAt: DateTime(2026, 1, 1),
    );

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioProvider.playVerse (queue-of-one parity)', () {
    test('playing a single verse sets currentVerse and isPlaying', () async {
      final audio = FakeAudioService();
      final notifications = FakeNotificationService();
      final provider = AudioProvider(
        notificationService: notifications,
        audioService: audio,
      );
      final verse = _verse('a');

      await provider.playVerse(verse);

      expect(provider.currentVerse, verse);
      expect(provider.isPlaying, isTrue);
      expect(audio.playedVerses, [verse]);
    });

    test('queueLength and currentQueueIndex reflect a queue of one', () async {
      final audio = FakeAudioService();
      final notifications = FakeNotificationService();
      final provider = AudioProvider(
        notificationService: notifications,
        audioService: audio,
      );

      await provider.playVerse(_verse('a'));

      expect(provider.queueLength, 1);
      expect(provider.currentQueueIndex, 0);
    });
  });

  group('AudioProvider.playQueue', () {
    test('plays the first verse and exposes queue position', () async {
      final audio = FakeAudioService();
      final notifications = FakeNotificationService();
      final provider = AudioProvider(
        notificationService: notifications,
        audioService: audio,
      );
      final verses = [_verse('a'), _verse('b'), _verse('c')];

      await provider.playQueue(verses);

      expect(provider.currentVerse, verses[0]);
      expect(provider.queueLength, 3);
      expect(provider.currentQueueIndex, 0);
      expect(audio.playedVerses, [verses[0]]);
    });

    test('auto-advances to the next verse when one completes', () async {
      final audio = FakeAudioService();
      final notifications = FakeNotificationService();
      final provider = AudioProvider(
        notificationService: notifications,
        audioService: audio,
      );
      final verses = [_verse('a'), _verse('b'), _verse('c')];

      await provider.playQueue(verses);
      audio.emit(AudioPlaybackState.completed);
      await _flush();

      expect(provider.currentQueueIndex, 1);
      expect(provider.currentVerse, verses[1]);
      expect(audio.playedVerses, [verses[0], verses[1]]);
      expect(provider.isPlaying, isTrue);
    });

    test('queue exhaustion stops without looping', () async {
      final audio = FakeAudioService();
      final notifications = FakeNotificationService();
      final provider = AudioProvider(
        notificationService: notifications,
        audioService: audio,
      );
      final verses = [_verse('a'), _verse('b')];

      await provider.playQueue(verses);
      audio.emit(AudioPlaybackState.completed);
      await _flush();
      audio.emit(AudioPlaybackState.completed);
      await _flush();

      expect(audio.playedVerses, [verses[0], verses[1]]);
      expect(provider.isPlaying, isFalse);
      expect(provider.isCompleted, isTrue);
      expect(provider.currentVerse, verses[1]);
      expect(provider.currentQueueIndex, 1);
    });

    test('stop mid-queue clears the queue entirely', () async {
      final audio = FakeAudioService();
      final notifications = FakeNotificationService();
      final provider = AudioProvider(
        notificationService: notifications,
        audioService: audio,
      );
      final verses = [_verse('a'), _verse('b'), _verse('c')];

      await provider.playQueue(verses);
      await provider.stop();

      expect(provider.currentVerse, isNull);
      expect(provider.queueLength, 0);
      expect(provider.currentQueueIndex, 0);

      // A completion event arriving after stop must not resurrect the queue.
      audio.emit(AudioPlaybackState.completed);
      await _flush();
      expect(provider.currentVerse, isNull);
    });
  });
}
