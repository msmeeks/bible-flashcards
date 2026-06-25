import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import 'package:bible_flashcards/models/verse.dart';
import 'package:bible_flashcards/providers/audio_provider.dart';
import 'package:bible_flashcards/services/audio_service.dart';
import 'package:bible_flashcards/services/notification_service.dart';
import 'package:bible_flashcards/widgets/audio_player_bar.dart';

class _FakeAudioService extends AudioService {
  final StreamController<AudioPlaybackState> _controller =
      StreamController<AudioPlaybackState>.broadcast();
  int stopCalls = 0;

  @override
  Stream<AudioPlaybackState> get playbackStateStream => _controller.stream;

  @override
  Future<void> playVerse(Verse verse) async {}

  @override
  Future<void> stop() async {
    stopCalls++;
    _controller.add(AudioPlaybackState.idle);
  }

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
    child: const MaterialApp(
      home: Scaffold(
          body: Align(
              alignment: Alignment.bottomCenter, child: AudioPlayerBar())),
    ),
  );
}

void main() {
  testWidgets('hides the queue label for single-verse playback',
      (tester) async {
    final provider = AudioProvider(
      notificationService: _FakeNotificationService(),
      audioService: _FakeAudioService(),
    );
    await provider.playVerse(_verse('a'));

    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    expect(find.textContaining('Playing'), findsNothing);
  });

  testWidgets('shows "Playing X of N" when the queue has more than one verse',
      (tester) async {
    final provider = AudioProvider(
      notificationService: _FakeNotificationService(),
      audioService: _FakeAudioService(),
    );
    await provider.playQueue([_verse('a'), _verse('b'), _verse('c')]);

    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    expect(find.text('Playing 1 of 3'), findsOneWidget);
  });

  testWidgets('renders nothing when no verse is queued', (tester) async {
    final provider = AudioProvider(
      notificationService: _FakeNotificationService(),
      audioService: _FakeAudioService(),
    );

    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    expect(find.byType(Dismissible), findsNothing);
  });

  testWidgets('tapping the stop icon calls provider.stop()', (tester) async {
    final audioService = _FakeAudioService();
    final provider = AudioProvider(
      notificationService: _FakeNotificationService(),
      audioService: audioService,
    );
    await provider.playVerse(_verse('a'));

    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    await tester.tap(find.byIcon(Symbols.stop_rounded));
    await tester.pump();

    expect(audioService.stopCalls, 1);
  });

  testWidgets('disables the play button when playback is completed',
      (tester) async {
    final audioService = _FakeAudioService();
    final provider = AudioProvider(
      notificationService: _FakeNotificationService(),
      audioService: audioService,
    );
    await provider.playVerse(_verse('a'));
    audioService.emit(AudioPlaybackState.completed);
    await tester.pump();

    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}
