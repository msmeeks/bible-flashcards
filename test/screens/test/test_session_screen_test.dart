import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:bible_flashcards/models/verse.dart';
import 'package:bible_flashcards/screens/test/test_enums.dart';
import 'package:bible_flashcards/screens/test/test_session_screen.dart';
import 'package:bible_flashcards/services/speech_recognition_service.dart';

class _FakeSpeechService implements SpeechRecognitionService {
  int listenCalls = 0;

  @override
  bool get isListening => false;

  @override
  Future<MicPermissionResult> requestPermission() async =>
      MicPermissionResult.granted;

  @override
  Future<bool> listen({
    required void Function(String transcript, bool isFinal) onTranscript,
    required void Function() onStopped,
  }) async {
    listenCalls++;
    // Simulates the wedged plugin: "started" succeeds but neither
    // onTranscript nor onStopped is ever called.
    return true;
  }

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> cancel() async {}

  @override
  void dispose() {}
}

Verse _verse() => Verse(
      id: 'john_3_16',
      reference: 'John 3:16',
      text: 'For God so loved the world',
      translation: 'ESV',
      packId: 'pack_1',
      addedAt: DateTime(2024, 1, 1),
    );

Widget _wrap(SpeechRecognitionService speechService) => MaterialApp(
      home: TestSessionScreen(
        verses: [_verse()],
        testMode: TestMode.review,
        selectedFormats: const {TestFormat.recite},
        selectedDirections: const {PromptDirection.textToRef},
        speechService: speechService,
      ),
    );

void main() {
  testWidgets(
    'mic listening recovers on its own after the bounded timeout',
    (tester) async {
      await tester.pumpWidget(_wrap(_FakeSpeechService()));
      await tester.pump();

      await tester.tap(find.byIcon(Symbols.mic_none_rounded));
      await tester.pump();

      expect(find.text('Listening…'), findsOneWidget);

      await tester.pump(const Duration(seconds: 16));

      expect(find.text('Listening…'), findsNothing);
      expect(find.textContaining("Didn't catch that"), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the mic again after a timeout starts a fresh listen session',
    (tester) async {
      final fakeService = _FakeSpeechService();
      await tester.pumpWidget(_wrap(fakeService));
      await tester.pump();

      await tester.tap(find.byIcon(Symbols.mic_none_rounded));
      await tester.pump();
      await tester.pump(const Duration(seconds: 16));

      expect(fakeService.listenCalls, 1);

      await tester.tap(find.byIcon(Symbols.mic_none_rounded));
      await tester.pump();

      expect(fakeService.listenCalls, 2);
      expect(find.text('Listening…'), findsOneWidget);

      // The first timer must not fire again and clobber this new session.
      await tester.pump(const Duration(seconds: 16));
      expect(find.text('Listening…'), findsNothing);
    },
  );

  Widget wrapFillBlank(Verse verse) => MaterialApp(
        home: TestSessionScreen(
          verses: [verse],
          testMode: TestMode.review,
          selectedFormats: const {TestFormat.fillBlank},
          selectedDirections: const {PromptDirection.textToRef},
        ),
      );

  testWidgets(
    'fill-blank renders at least one real blank for a 2-token reference',
    (tester) async {
      await tester.pumpWidget(wrapFillBlank(_verse()));
      await tester.pump();

      expect(find.byType(TextField), findsAtLeastNWidgets(1));
    },
  );

  testWidgets(
    'fill-blank fields carry a numbered Blank N label for screen readers',
    (tester) async {
      await tester.pumpWidget(wrapFillBlank(_verse()));
      await tester.pump();

      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields, isNotEmpty);
      for (var i = 0; i < fields.length; i++) {
        expect(fields.elementAt(i).decoration?.labelText, 'Blank ${i + 1}');
      }
    },
  );

  testWidgets(
    'after checking, no "Correct" or "Incorrect —" text is shown',
    (tester) async {
      await tester.pumpWidget(wrapFillBlank(_verse()));
      await tester.pump();

      await tester.tap(find.text('Check Answer'));
      await tester.pump();

      expect(find.text('Correct'), findsNothing);
      expect(find.textContaining('Incorrect —'), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    },
  );
}
