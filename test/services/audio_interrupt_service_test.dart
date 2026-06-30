import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:bible_flashcards/models/verse.dart';
import 'package:bible_flashcards/services/audio_interrupt_service.dart';

import '../helpers/fake_audio_service.dart';
import '../helpers/verse_factory.dart';

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

  group('AudioInterruptService instance behavior', () {
    late FakeAudioService audio;
    late FakeNotificationService notifications;
    late AudioInterruptService service;
    late Verse vow;

    setUp(() {
      audio = FakeAudioService();
      notifications = FakeNotificationService();
      service = AudioInterruptService(
        audioService: audio,
        notificationService: notifications,
      );
      vow = makeVerse('vow', isVerseOfWeek: true);
    });

    tearDown(() => service.stopTracking());

    test('isTracking is false before startTracking is called', () {
      expect(service.isTracking, isFalse);
    });

    test('startTracking sets isTracking to true', () {
      service.startTracking(
        threshold: const Duration(hours: 1),
        interruptProbability: 0.5,
        memorizedVerses: const [],
        verseOfWeek: vow,
      );
      expect(service.isTracking, isTrue);
    });

    test('stopTracking sets isTracking to false', () {
      service.startTracking(
        threshold: const Duration(hours: 1),
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
        threshold: const Duration(hours: 1),
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
        threshold: const Duration(hours: 1),
        interruptProbability: 0.5,
        memorizedVerses: const [],
        verseOfWeek: vow,
      );
      service.pauseTracking();
      service.resumeTracking();
      expect(service.isTracking, isTrue);
    });

    test(
        'debugCheckThreshold with a zero threshold triggers stop, '
        'notification, and playVerse with the picked verse', () {
      service.startTracking(
        threshold: Duration.zero,
        interruptProbability: 1.0,
        memorizedVerses: const [],
        verseOfWeek: vow,
      );

      service.debugCheckThreshold();

      expect(audio.stopCalls, 1);
      expect(notifications.showInterruptCalls, 1);
      expect(audio.playedVerses, [vow]);
    });

    test('debugCheckThreshold below threshold does not trigger an interrupt',
        () {
      service.startTracking(
        threshold: const Duration(hours: 1),
        interruptProbability: 1.0,
        memorizedVerses: const [],
        verseOfWeek: vow,
      );

      service.debugCheckThreshold();

      expect(audio.stopCalls, 0);
      expect(notifications.showInterruptCalls, 0);
      expect(audio.playedVerses, isEmpty);
    });

    test('debugCheckThreshold after stopTracking does nothing', () {
      service.startTracking(
        threshold: Duration.zero,
        interruptProbability: 1.0,
        memorizedVerses: const [],
        verseOfWeek: vow,
      );
      service.stopTracking();

      service.debugCheckThreshold();

      expect(audio.stopCalls, 0);
      expect(notifications.showInterruptCalls, 0);
      expect(audio.playedVerses, isEmpty);
    });
  });
}
