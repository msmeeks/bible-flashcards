import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:bible_flashcards/models/settings.dart';
import 'package:bible_flashcards/models/verse.dart';
import 'package:bible_flashcards/services/audio_interrupt_service.dart';

import '../helpers/fake_audio_service.dart';
import '../helpers/verse_factory.dart';

/// A fake whose `playVerse` stays pending until [finishPlayback], standing in
/// for a verse that is still speaking when the next poll arrives.
class BlockingAudioService extends FakeAudioService {
  final Completer<void> _playing = Completer<void>();

  @override
  Future<void> playVerse(Verse verse) async {
    playedVerses.add(verse);
    await _playing.future;
  }

  void finishPlayback() => _playing.complete();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pickVerseForInterrupt', () {
    test('verseOfWeek null with non-empty memorizedVerses picks from the list',
        () {
      final other = makeVerse('other');
      final picked = pickVerseForInterrupt(
        random: Random(),
        probability: 1.0,
        verseOfWeek: null,
        memorizedVerses: [other],
      );
      expect(picked?.id, 'other');
    });

    test('verseOfWeek null with empty memorizedVerses returns null', () {
      final picked = pickVerseForInterrupt(
        random: Random(),
        probability: 1.0,
        verseOfWeek: null,
        memorizedVerses: [],
      );
      expect(picked, isNull);
    });

    test('memorizedVerses empty with a verse-of-week falls back to it', () {
      final vow = makeVerse('vow', isVerseOfWeek: true);
      final picked = pickVerseForInterrupt(
        random: Random(),
        probability: 0.0,
        verseOfWeek: vow,
        memorizedVerses: [],
      );
      expect(picked?.id, 'vow');
    });

    test('probability 1.0 always selects the verse-of-week', () {
      final vow = makeVerse('vow', isVerseOfWeek: true);
      final other = makeVerse('other');
      final random = Random();

      for (var i = 0; i < 100; i++) {
        final picked = pickVerseForInterrupt(
          random: random,
          probability: 1.0,
          verseOfWeek: vow,
          memorizedVerses: [other],
        );
        expect(picked?.id, vow.id);
      }
    });

    test('probability 0.0 never selects the verse-of-week', () {
      final vow = makeVerse('vow', isVerseOfWeek: true);
      final other = makeVerse('other');
      final random = Random();

      for (var i = 0; i < 100; i++) {
        final picked = pickVerseForInterrupt(
          random: random,
          probability: 0.0,
          verseOfWeek: vow,
          memorizedVerses: [other],
        );
        expect(picked?.id, other.id);
      }
    });

    test(
        'probability 0.5 selects both the verse-of-week and a random verse '
        'across many calls', () {
      final vow = makeVerse('vow', isVerseOfWeek: true);
      final other = makeVerse('other');
      final random = Random();

      var vowCount = 0;
      var otherCount = 0;
      for (var i = 0; i < 100; i++) {
        final picked = pickVerseForInterrupt(
          random: random,
          probability: 0.5,
          verseOfWeek: vow,
          memorizedVerses: [other],
        );
        if (picked?.id == vow.id) {
          vowCount++;
        } else if (picked?.id == other.id) {
          otherCount++;
        }
      }

      expect(vowCount, greaterThan(0));
      expect(otherCount, greaterThan(0));
    });
  });

  group('AudioInterruptService trigger-mode gating', () {
    late FakeAudioService audio;
    late FakeNotificationService notifications;
    late FakeSystemAudioService systemAudio;
    late Verse vow;

    AudioInterruptService buildService() => AudioInterruptService(
          audioService: audio,
          notificationService: notifications,
          systemAudioService: systemAudio,
          // No real waiting between debounce samples in tests.
          debounceDelay: Duration.zero,
        );

    setUp(() {
      audio = FakeAudioService();
      notifications = FakeNotificationService();
      vow = makeVerse('vow', isVerseOfWeek: true);
    });

    test(
        'whileOtherAudioPlaying skips the interval when no other audio is '
        'playing', () async {
      systemAudio = FakeSystemAudioService(musicActiveResults: const [false]);
      final service = buildService();
      addTearDown(service.stopTracking);

      service.startTracking(
        interval: Duration.zero,
        triggerMode: AudioTriggerMode.whileOtherAudioPlaying,
        interruptProbability: 1.0,
        memorizedVerses: const [],
        verseOfWeek: vow,
      );

      await service.debugFireInterval();

      expect(audio.playedVerses, isEmpty);
      expect(notifications.showInterruptCalls, 0);
      expect(systemAudio.requestFocusCalls, 0);
    });

    test('whileOtherAudioPlaying plays when other audio is active', () async {
      systemAudio = FakeSystemAudioService(musicActiveResults: const [true]);
      final service = buildService();
      addTearDown(service.stopTracking);

      service.startTracking(
        interval: Duration.zero,
        triggerMode: AudioTriggerMode.whileOtherAudioPlaying,
        interruptProbability: 1.0,
        memorizedVerses: const [],
        verseOfWeek: vow,
      );

      await service.debugFireInterval();

      expect(audio.playedVerses, [vow]);
    });

    test('always mode plays without consulting other-app audio', () async {
      systemAudio = FakeSystemAudioService(musicActiveResults: const [false]);
      final service = buildService();
      addTearDown(service.stopTracking);

      service.startTracking(
        interval: Duration.zero,
        triggerMode: AudioTriggerMode.always,
        interruptProbability: 1.0,
        memorizedVerses: const [],
        verseOfWeek: vow,
      );

      await service.debugFireInterval();

      expect(audio.playedVerses, [vow]);
      expect(systemAudio.isMusicActiveCalls, 0);
    });

    test('focus is held across the verse and released afterwards', () async {
      systemAudio = FakeSystemAudioService(musicActiveResults: const [true]);
      final service = buildService();
      addTearDown(service.stopTracking);

      service.startTracking(
        interval: Duration.zero,
        triggerMode: AudioTriggerMode.always,
        interruptProbability: 1.0,
        memorizedVerses: const [],
        verseOfWeek: vow,
      );

      await service.debugFireInterval();

      expect(systemAudio.calls, ['requestTransientFocus', 'abandonFocus']);
      expect(systemAudio.abandonFocusCalls, 1);
    });

    test('a focus denial keeps the verse silent', () async {
      systemAudio = FakeSystemAudioService(
        musicActiveResults: const [true],
        focusGranted: false,
      );
      final service = buildService();
      addTearDown(service.stopTracking);

      service.startTracking(
        interval: Duration.zero,
        triggerMode: AudioTriggerMode.always,
        interruptProbability: 1.0,
        memorizedVerses: const [],
        verseOfWeek: vow,
      );

      await service.debugFireInterval();

      expect(audio.playedVerses, isEmpty);
      expect(notifications.showInterruptCalls, 0);
    });

    test(
        'a momentary gap between tracks is debounced rather than skipping the '
        'interval', () async {
      // Silent on the first sample (track change), playing on the second.
      systemAudio =
          FakeSystemAudioService(musicActiveResults: const [false, true]);
      final service = buildService();
      addTearDown(service.stopTracking);

      service.startTracking(
        interval: Duration.zero,
        triggerMode: AudioTriggerMode.whileOtherAudioPlaying,
        interruptProbability: 1.0,
        memorizedVerses: const [],
        verseOfWeek: vow,
      );

      await service.debugFireInterval();

      expect(systemAudio.isMusicActiveCalls, 2);
      expect(audio.playedVerses, [vow]);
    });

    test('gives up after the debounce samples are exhausted', () async {
      systemAudio = FakeSystemAudioService(
          musicActiveResults: const [false, false, false]);
      final service = buildService();
      addTearDown(service.stopTracking);

      service.startTracking(
        interval: Duration.zero,
        triggerMode: AudioTriggerMode.whileOtherAudioPlaying,
        interruptProbability: 1.0,
        memorizedVerses: const [],
        verseOfWeek: vow,
      );

      await service.debugFireInterval();

      expect(systemAudio.isMusicActiveCalls, 3);
      expect(audio.playedVerses, isEmpty);
    });

    test('playback recurs on each interval rather than firing only once',
        () async {
      systemAudio = FakeSystemAudioService(musicActiveResults: const [true]);
      final service = buildService();
      addTearDown(service.stopTracking);

      service.startTracking(
        interval: Duration.zero,
        triggerMode: AudioTriggerMode.whileOtherAudioPlaying,
        interruptProbability: 1.0,
        memorizedVerses: const [],
        verseOfWeek: vow,
      );

      await service.debugFireInterval();
      await service.debugFireInterval();
      await service.debugFireInterval();

      expect(audio.playedVerses, [vow, vow, vow]);
      expect(systemAudio.abandonFocusCalls, 3);
    });

    test('a skipped interval does not suppress the next one', () async {
      // Silent for the first interval's samples, then playing.
      systemAudio = FakeSystemAudioService(
          musicActiveResults: const [false, false, false, true]);
      final service = buildService();
      addTearDown(service.stopTracking);

      service.startTracking(
        interval: Duration.zero,
        triggerMode: AudioTriggerMode.whileOtherAudioPlaying,
        interruptProbability: 1.0,
        memorizedVerses: const [],
        verseOfWeek: vow,
      );

      await service.debugFireInterval();
      expect(audio.playedVerses, isEmpty);

      await service.debugFireInterval();
      expect(audio.playedVerses, [vow]);
    });

    test('an interval arriving mid-verse does not start a second playback',
        () async {
      // The 10s poll keeps ticking while a verse (tens of seconds) plays.
      final blocking = BlockingAudioService();
      audio = blocking;
      systemAudio = FakeSystemAudioService(musicActiveResults: const [true]);
      final service = buildService();
      addTearDown(service.stopTracking);

      service.startTracking(
        interval: Duration.zero,
        triggerMode: AudioTriggerMode.always,
        interruptProbability: 1.0,
        memorizedVerses: const [],
        verseOfWeek: vow,
      );

      final first = service.debugFireInterval();
      await pumpEventQueue();
      // Second interval lands while the first verse is still speaking.
      await service.debugFireInterval();

      expect(blocking.playedVerses, [vow]);

      blocking.finishPlayback();
      await first;

      expect(blocking.playedVerses, [vow]);
      expect(systemAudio.abandonFocusCalls, 1);
    });
  });

  group('AudioInterruptService instance behavior', () {
    late FakeAudioService audio;
    late FakeNotificationService notifications;
    late FakeSystemAudioService systemAudio;
    late AudioInterruptService service;
    late Verse vow;

    setUp(() {
      audio = FakeAudioService();
      notifications = FakeNotificationService();
      systemAudio = FakeSystemAudioService(musicActiveResults: const [true]);
      service = AudioInterruptService(
        audioService: audio,
        notificationService: notifications,
        systemAudioService: systemAudio,
      );
      vow = makeVerse('vow', isVerseOfWeek: true);
    });

    tearDown(() => service.stopTracking());

    test('isTracking is false before startTracking is called', () {
      expect(service.isTracking, isFalse);
    });

    test('startTracking sets isTracking to true', () {
      service.startTracking(
        interval: const Duration(hours: 1),
        triggerMode: AudioTriggerMode.always,
        interruptProbability: 0.5,
        memorizedVerses: const [],
        verseOfWeek: vow,
      );
      expect(service.isTracking, isTrue);
    });

    test('stopTracking sets isTracking to false', () {
      service.startTracking(
        interval: const Duration(hours: 1),
        triggerMode: AudioTriggerMode.always,
        interruptProbability: 0.5,
        memorizedVerses: const [],
        verseOfWeek: vow,
      );
      service.stopTracking();
      expect(service.isTracking, isFalse);
    });

    test('pauseTracking before startTracking is a safe no-op', () {
      service.pauseTracking();
      expect(service.isTracking, isFalse);
    });

    test('resumeTracking before startTracking is a safe no-op', () {
      service.resumeTracking();
      expect(service.isTracking, isFalse);
    });

    test('pauseTracking called twice in a row is a safe no-op', () {
      service.startTracking(
        interval: const Duration(hours: 1),
        triggerMode: AudioTriggerMode.always,
        interruptProbability: 0.5,
        memorizedVerses: const [],
        verseOfWeek: vow,
      );
      service.pauseTracking();
      service.pauseTracking();
      expect(service.isTracking, isTrue);
    });

    test('resumeTracking after pauseTracking keeps tracking active', () {
      service.startTracking(
        interval: const Duration(hours: 1),
        triggerMode: AudioTriggerMode.always,
        interruptProbability: 0.5,
        memorizedVerses: const [],
        verseOfWeek: vow,
      );
      service.pauseTracking();
      service.resumeTracking();
      expect(service.isTracking, isTrue);
    });

    test(
        'debugFireInterval with a zero interval triggers stop, '
        'notification, and playVerse with the picked verse', () async {
      service.startTracking(
        interval: Duration.zero,
        triggerMode: AudioTriggerMode.always,
        interruptProbability: 1.0,
        memorizedVerses: const [],
        verseOfWeek: vow,
      );

      await service.debugFireInterval();

      expect(audio.stopCalls, 1);
      expect(notifications.showInterruptCalls, 1);
      expect(audio.playedVerses, [vow]);
    });

    test('debugFireInterval below the interval does not trigger an interrupt',
        () async {
      service.startTracking(
        interval: const Duration(hours: 1),
        triggerMode: AudioTriggerMode.always,
        interruptProbability: 1.0,
        memorizedVerses: const [],
        verseOfWeek: vow,
      );

      await service.debugFireInterval();

      expect(audio.stopCalls, 0);
      expect(notifications.showInterruptCalls, 0);
      expect(audio.playedVerses, isEmpty);
    });

    test('debugFireInterval after stopTracking does nothing', () async {
      service.startTracking(
        interval: Duration.zero,
        triggerMode: AudioTriggerMode.always,
        interruptProbability: 1.0,
        memorizedVerses: const [],
        verseOfWeek: vow,
      );
      service.stopTracking();

      await service.debugFireInterval();

      expect(audio.stopCalls, 0);
      expect(notifications.showInterruptCalls, 0);
      expect(audio.playedVerses, isEmpty);
    });
  });
}
