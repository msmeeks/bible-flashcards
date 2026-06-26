import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import 'package:bible_flashcards/providers/audio_provider.dart';
import 'package:bible_flashcards/services/audio_service.dart';
import 'package:bible_flashcards/widgets/audio_player_bar.dart';

import '../helpers/fake_audio_service.dart';
import '../helpers/verse_factory.dart';

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
      notificationService: FakeNotificationService(),
      audioService: FakeAudioService(),
    );
    await provider.playVerse(makeVerse('a'));

    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    expect(find.textContaining('Playing'), findsNothing);
  });

  testWidgets('shows "Playing X of N" when the queue has more than one verse',
      (tester) async {
    final provider = AudioProvider(
      notificationService: FakeNotificationService(),
      audioService: FakeAudioService(),
    );
    await provider.playQueue([makeVerse('a'), makeVerse('b'), makeVerse('c')]);

    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    expect(find.text('Playing 1 of 3'), findsOneWidget);
  });

  testWidgets('renders nothing when no verse is queued', (tester) async {
    final provider = AudioProvider(
      notificationService: FakeNotificationService(),
      audioService: FakeAudioService(),
    );

    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    expect(find.byType(Dismissible), findsNothing);
  });

  testWidgets('tapping the stop icon calls provider.stop()', (tester) async {
    final audioService = FakeAudioService();
    final provider = AudioProvider(
      notificationService: FakeNotificationService(),
      audioService: audioService,
    );
    await provider.playVerse(makeVerse('a'));

    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    await tester.tap(find.byIcon(Symbols.stop_rounded));
    await tester.pump();

    expect(audioService.stopCalls, 1);
  });

  testWidgets('disables the play button when playback is completed',
      (tester) async {
    final audioService = FakeAudioService();
    final provider = AudioProvider(
      notificationService: FakeNotificationService(),
      audioService: audioService,
    );
    await provider.playVerse(makeVerse('a'));
    audioService.emit(AudioPlaybackState.completed);
    await tester.pump();

    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}
