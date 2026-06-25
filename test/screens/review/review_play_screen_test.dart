import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bible_flashcards/models/verse.dart';
import 'package:bible_flashcards/providers/audio_provider.dart';
import 'package:bible_flashcards/screens/review/review_play_screen.dart';
import 'package:bible_flashcards/services/audio_service.dart';
import 'package:bible_flashcards/services/notification_service.dart';

class _FakeAudioService extends AudioService {
  final StreamController<AudioPlaybackState> _controller =
      StreamController<AudioPlaybackState>.broadcast();

  @override
  Stream<AudioPlaybackState> get playbackStateStream => _controller.stream;

  @override
  Future<void> playVerse(Verse verse) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async => _controller.add(AudioPlaybackState.idle);

  void emit(AudioPlaybackState state) => _controller.add(state);

  @override
  void dispose() {
    unawaited(_controller.close());
  }
}

class _FakeNotificationService extends NotificationService {
  @override
  Future<void> showPlaybackNotification() async {}

  @override
  Future<void> cancelNotification() async {}
}

Verse _verse(String id) => Verse(
      id: id,
      reference: 'Ref $id',
      text: 'Text $id',
      translation: 'ESV',
      packId: 'pack',
      addedAt: DateTime(2026, 1, 1),
    );

Widget _wrap(AudioProvider provider) {
  return ChangeNotifierProvider<AudioProvider>.value(
    value: provider,
    child: const MaterialApp(home: ReviewPlayScreen()),
  );
}

void main() {
  testWidgets('shows reference, state label, and "Playing X of N"',
      (tester) async {
    final provider = AudioProvider(
      notificationService: _FakeNotificationService(),
      audioService: _FakeAudioService(),
    );
    await provider.playQueue([_verse('a'), _verse('b'), _verse('c')]);

    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    expect(find.text('Ref a'), findsOneWidget);
    expect(find.text('Playing 1 of 3'), findsOneWidget);
  });

  testWidgets('pause button pauses, resume button resumes', (tester) async {
    final provider = AudioProvider(
      notificationService: _FakeNotificationService(),
      audioService: _FakeAudioService(),
    );
    await provider.playQueue([_verse('a')]);

    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    expect(provider.isPlaying, isTrue);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(provider.isPlaying, isFalse);

    await tester.tap(find.byTooltip('Resume'));
    await tester.pump();
    expect(provider.isPlaying, isTrue);
  });

  testWidgets('stop button stops playback and pops the screen',
      (tester) async {
    final provider = AudioProvider(
      notificationService: _FakeNotificationService(),
      audioService: _FakeAudioService(),
    );
    await provider.playQueue([_verse('a')]);

    await tester.pumpWidget(
      ChangeNotifierProvider<AudioProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const ReviewPlayScreen()),
              ),
              child: const Text('open'),
            );
          }),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(ReviewPlayScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Stop'));
    await tester.pumpAndSettle();

    expect(find.byType(ReviewPlayScreen), findsNothing);
  });
}
