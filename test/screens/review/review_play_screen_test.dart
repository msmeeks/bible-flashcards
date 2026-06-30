import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bible_flashcards/providers/audio_provider.dart';
import 'package:bible_flashcards/screens/review/review_play_screen.dart';
import 'package:bible_flashcards/services/audio_service.dart';

import '../../helpers/fake_audio_service.dart';
import '../../helpers/verse_factory.dart';

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
      notificationService: FakeNotificationService(),
      audioService: FakeAudioService(),
    );
    await provider.playQueue([makeVerse('a'), makeVerse('b'), makeVerse('c')]);

    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    expect(find.text('Ref a'), findsOneWidget);
    expect(find.text('Playing 1 of 3'), findsOneWidget);
  });

  testWidgets('pause button pauses, resume button resumes', (tester) async {
    final provider = AudioProvider(
      notificationService: FakeNotificationService(),
      audioService: FakeAudioService(),
    );
    await provider.playQueue([makeVerse('a')]);

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
      notificationService: FakeNotificationService(),
      audioService: FakeAudioService(),
    );
    await provider.playQueue([makeVerse('a')]);

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

  testWidgets('disables the play/pause button when playback is completed',
      (tester) async {
    final audio = FakeAudioService();
    final provider = AudioProvider(
      notificationService: FakeNotificationService(),
      audioService: audio,
    );
    await provider.playVerse(makeVerse('a'));
    audio.emit(AudioPlaybackState.completed);
    await Future<void>.value();
    expect(provider.isCompleted, isTrue);

    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets(
      'Stop and Pause controls each expose a single actionable semantics '
      'node with the visible label, not a separate unlabeled descendant node',
      (tester) async {
    final provider = AudioProvider(
      notificationService: FakeNotificationService(),
      audioService: FakeAudioService(),
    );
    await provider.playQueue([makeVerse('a')]);

    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    final stopData = tester.getSemantics(find.byTooltip('Stop')).getSemanticsData();
    expect(stopData.label, 'Stop playback');
    expect(stopData.hasAction(SemanticsAction.tap), isTrue);

    final pauseData =
        tester.getSemantics(find.byTooltip('Pause')).getSemanticsData();
    expect(pauseData.label, 'Pause');
    expect(pauseData.hasAction(SemanticsAction.tap), isTrue);

    handle.dispose();
  });

  testWidgets(
      'pops the screen when currentVerse becomes null after a stop event',
      (tester) async {
    final audio = FakeAudioService();
    final provider = AudioProvider(
      notificationService: FakeNotificationService(),
      audioService: audio,
    );
    await provider.playQueue([makeVerse('a')]);

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

    // Simulate the queue idling out (currentVerse -> null) without the user
    // tapping Stop directly on this screen.
    audio.emit(AudioPlaybackState.idle);
    await tester.pumpAndSettle();

    expect(find.byType(ReviewPlayScreen), findsNothing);
  });
}
