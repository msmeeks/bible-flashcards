import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/providers/audio_provider.dart';
import 'package:bible_flashcards/providers/verse_provider.dart';
import 'package:bible_flashcards/screens/review/review_play_screen.dart';
import 'package:bible_flashcards/screens/review/review_screen.dart';
import 'package:bible_flashcards/screens/review/review_show_screen.dart';

import '../../helpers/fake_audio_service.dart';
import '../../helpers/verse_factory.dart';

Widget _wrap(VerseProvider provider, {AudioProvider? audioProvider}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<VerseProvider>.value(value: provider),
      ChangeNotifierProvider<AudioProvider>.value(
        value: audioProvider ??
            AudioProvider(
              notificationService: FakeNotificationService(),
              audioService: FakeAudioService(),
            ),
      ),
    ],
    child: const MaterialApp(home: ReviewScreen()),
  );
}

void main() {
  testWidgets('shows empty state when there are no memorized verses',
      (tester) async {
    final provider = VerseProvider(DatabaseHelper());
    provider.debugSetVerses([]);

    await tester.pumpWidget(_wrap(provider));

    expect(find.text('No memorized verses yet'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('empty-state icon is decorative, not double-announced',
      (tester) async {
    final provider = VerseProvider(DatabaseHelper());
    provider.debugSetVerses([]);

    await tester.pumpWidget(_wrap(provider));

    final icon = tester.widget<Icon>(find.byIcon(Symbols.menu_book_rounded));
    expect(icon.semanticLabel, '');
  });

  testWidgets('count chip presets are grouped under a single Semantics label',
      (tester) async {
    final provider = VerseProvider(DatabaseHelper());
    provider.debugSetVerses(List.generate(7, (i) => makeVerse('v$i')));

    await tester.pumpWidget(_wrap(provider));

    expect(
      find.bySemanticsLabel('Number of verses — select a preset'),
      findsOneWidget,
    );
  });

  testWidgets('Start button uses the Symbols icon set, not legacy Icons',
      (tester) async {
    final provider = VerseProvider(DatabaseHelper());
    provider.debugSetVerses(List.generate(7, (i) => makeVerse('v$i')));

    await tester.pumpWidget(_wrap(provider));

    expect(find.byIcon(Symbols.play_arrow_rounded), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
  });

  testWidgets('shows count slider, verse-of-week toggle, and format selector',
      (tester) async {
    final provider = VerseProvider(DatabaseHelper());
    provider.debugSetVerses(List.generate(7, (i) => makeVerse('v$i')));

    await tester.pumpWidget(_wrap(provider));

    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Include verse of the week'), findsOneWidget);
    expect(find.text('Show'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('Start pushes ReviewShowScreen with the drawn verse list',
      (tester) async {
    final provider = VerseProvider(DatabaseHelper());
    provider.debugSetVerses(List.generate(7, (i) => makeVerse('v$i')));

    await tester.pumpWidget(_wrap(provider));

    await tester.tap(find.widgetWithText(FilterChip, '5'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    final show = tester.widget<ReviewShowScreen>(find.byType(ReviewShowScreen));
    expect(show.verses.length, 5);
  });

  testWidgets('Start with Play selected queues playback and pushes ReviewPlayScreen',
      (tester) async {
    final provider = VerseProvider(DatabaseHelper());
    provider.debugSetVerses(List.generate(7, (i) => makeVerse('v$i')));
    final audioProvider = AudioProvider(
      notificationService: FakeNotificationService(),
      audioService: FakeAudioService(),
    );

    await tester.pumpWidget(_wrap(provider, audioProvider: audioProvider));

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.byType(ReviewPlayScreen), findsOneWidget);
    expect(audioProvider.queueLength, 5);
  });
}
