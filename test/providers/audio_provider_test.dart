import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:bible_flashcards/providers/audio_provider.dart';
import 'package:bible_flashcards/services/audio_service.dart';
import 'package:bible_flashcards/services/notification_service.dart';

import '../helpers/fake_audio_service.dart';
import '../helpers/verse_factory.dart';

/// A [NotificationService] whose [showPlaybackNotification] suspends until
/// the test explicitly completes [gate] — used to land inside the await
/// window in `AudioProvider._playCurrent()` and exercise the race with
/// `stop()`.
class _DeferredNotificationService extends NotificationService {
  _DeferredNotificationService(this.gate);

  final Future<void> gate;
  int cancelCalls = 0;

  @override
  Future<void> showPlaybackNotification() => gate;

  @override
  Future<void> cancelNotification() async {
    cancelCalls++;
  }
}

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
      final verse = makeVerse('a');

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

      await provider.playVerse(makeVerse('a'));

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
      final verses = [makeVerse('a'), makeVerse('b'), makeVerse('c')];

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
      final verses = [makeVerse('a'), makeVerse('b'), makeVerse('c')];

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
      final verses = [makeVerse('a'), makeVerse('b')];

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
      final verses = [makeVerse('a'), makeVerse('b'), makeVerse('c')];

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

    test(
        'stop() during the notification await prevents the stale verse from playing',
        () async {
      final audio = FakeAudioService();
      final gate = Completer<void>();
      final notifications = _DeferredNotificationService(gate.future);
      final provider = AudioProvider(
        notificationService: notifications,
        audioService: audio,
      );
      final verse = makeVerse('a');

      // playQueue's await suspends inside _playCurrent at the notification
      // await — it does not complete until we finish the gate below.
      final playFuture = provider.playQueue([verse]);
      await _flush();

      // stop() fires while _playCurrent is still suspended awaiting the
      // notification.
      await provider.stop();

      // Now let the suspended notification await resolve.
      gate.complete();
      await playFuture;
      await _flush();

      // The stale verse must never reach the audio service.
      expect(audio.playedVerses, isEmpty);
      expect(provider.currentVerse, isNull);
    });
  });

  group('AudioProvider playback state labels', () {
    test('speakingReference sets isPlaying and the matching label', () async {
      final audio = FakeAudioService();
      final notifications = FakeNotificationService();
      final provider = AudioProvider(
        notificationService: notifications,
        audioService: audio,
      );
      await provider.playVerse(makeVerse('a'));

      audio.emit(AudioPlaybackState.speakingReference);
      await _flush();

      expect(provider.isPlaying, isTrue);
      expect(provider.playbackStateLabel, 'Speaking reference…');
    });

    test('pausing sets isPlaying and the matching label', () async {
      final audio = FakeAudioService();
      final notifications = FakeNotificationService();
      final provider = AudioProvider(
        notificationService: notifications,
        audioService: audio,
      );
      await provider.playVerse(makeVerse('a'));

      audio.emit(AudioPlaybackState.pausing);
      await _flush();

      expect(provider.isPlaying, isTrue);
      expect(provider.playbackStateLabel, 'Pausing…');
    });

    test('speakingText sets isPlaying and the matching label', () async {
      final audio = FakeAudioService();
      final notifications = FakeNotificationService();
      final provider = AudioProvider(
        notificationService: notifications,
        audioService: audio,
      );
      await provider.playVerse(makeVerse('a'));

      audio.emit(AudioPlaybackState.speakingText);
      await _flush();

      expect(provider.isPlaying, isTrue);
      expect(provider.playbackStateLabel, 'Speaking text…');
    });

    test('error state clears isPlaying and cancels the notification',
        () async {
      final audio = FakeAudioService();
      final notifications = FakeNotificationService();
      final provider = AudioProvider(
        notificationService: notifications,
        audioService: audio,
      );
      await provider.playVerse(makeVerse('a'));

      audio.emit(AudioPlaybackState.error);
      await _flush();

      expect(provider.isPlaying, isFalse);
      expect(provider.playbackStateLabel, 'Error');
      expect(notifications.cancelCalls, 1);
    });
  });

  group('AudioProvider.resume early returns', () {
    test('resume() on a fresh provider with no verse queued is a no-op',
        () async {
      final audio = FakeAudioService();
      final notifications = FakeNotificationService();
      final provider = AudioProvider(
        notificationService: notifications,
        audioService: audio,
      );

      await provider.resume();

      expect(provider.isPlaying, isFalse);
      expect(audio.resumeCalls, 0);
    });

    test('resume() after playback has completed is a no-op', () async {
      final audio = FakeAudioService();
      final notifications = FakeNotificationService();
      final provider = AudioProvider(
        notificationService: notifications,
        audioService: audio,
      );
      await provider.playVerse(makeVerse('a'));
      audio.emit(AudioPlaybackState.completed);
      await _flush();
      expect(provider.isCompleted, isTrue);

      await provider.resume();

      expect(provider.isPlaying, isFalse);
      expect(audio.resumeCalls, 0);
    });
  });
}
