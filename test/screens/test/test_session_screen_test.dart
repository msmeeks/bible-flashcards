import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:bible_flashcards/models/verse.dart';
import 'package:bible_flashcards/screens/test/test_enums.dart';
import 'package:bible_flashcards/screens/test/test_session_screen.dart';
import 'package:bible_flashcards/services/speech_recognition_service.dart';

class _FakeSpeechService implements SpeechRecognitionService {
  int listenCalls = 0;
  bool listenReturnsFalse = false;

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
    if (listenReturnsFalse) return false;
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

class _ControllableFakeSpeechService implements SpeechRecognitionService {
  _ControllableFakeSpeechService({this.finalTranscript = 'for god so loved'});

  final String finalTranscript;
  void Function(String transcript, bool isFinal)? _onTranscript;

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
    _onTranscript = onTranscript;
    return true;
  }

  // Mirrors the real plugin: stop() resolves immediately, but the final
  // recognition result arrives asynchronously afterward (a later event-loop
  // turn, not a microtask queued during this call).
  @override
  Future<void> stopListening() async {
    Future.delayed(
      Duration.zero,
      () => _onTranscript?.call(finalTranscript, true),
    );
  }

  @override
  Future<void> cancel() async {}

  @override
  void dispose() {}
}

class _TransientlyDeniedSpeechService implements SpeechRecognitionService {
  @override
  bool get isListening => false;

  @override
  Future<MicPermissionResult> requestPermission() async =>
      MicPermissionResult.denied;

  @override
  Future<bool> listen({
    required void Function(String transcript, bool isFinal) onTranscript,
    required void Function() onStopped,
  }) async =>
      false;

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> cancel() async {}

  @override
  void dispose() {}
}

class _PermanentlyDeniedSpeechService implements SpeechRecognitionService {
  @override
  bool get isListening => false;

  @override
  Future<MicPermissionResult> requestPermission() async =>
      MicPermissionResult.permanentlyDenied;

  @override
  Future<bool> listen({
    required void Function(String transcript, bool isFinal) onTranscript,
    required void Function() onStopped,
  }) async =>
      false;

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

  testWidgets(
    'the microphone permission dialog uses FilledButton for Open Settings '
    'and OutlinedButton for Cancel',
    (tester) async {
      await tester.pumpWidget(_wrap(_PermanentlyDeniedSpeechService()));
      await tester.pump();

      await tester.tap(find.byIcon(Symbols.mic_none_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Microphone access needed'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Open Settings'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Open Settings'), findsNothing);
    },
  );

  testWidgets(
    'a transient permission denial shows the announcement without opening '
    'the settings dialog',
    (tester) async {
      await tester.pumpWidget(_wrap(_TransientlyDeniedSpeechService()));
      await tester.pump();

      await tester.tap(find.byIcon(Symbols.mic_none_rounded));
      await tester.pumpAndSettle();

      expect(
        find.text(
            'Microphone permission denied. You can still self-rate below.'),
        findsOneWidget,
      );
      expect(find.text('Microphone access needed'), findsNothing);
    },
  );

  testWidgets(
    'listen() returning false shows the unavailable announcement and '
    'resets the listening state',
    (tester) async {
      await tester.pumpWidget(_wrap(_FakeSpeechService()..listenReturnsFalse = true));
      await tester.pump();

      await tester.tap(find.byIcon(Symbols.mic_none_rounded));
      await tester.pump();

      expect(find.text('Recite aloud'), findsOneWidget);
      expect(find.text('Listening…'), findsNothing);
      expect(
        find.text('On-device speech recognition is unavailable'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'manually stopping listening still scores the recognized transcript',
    (tester) async {
      final fake = _ControllableFakeSpeechService();
      await tester.pumpWidget(_wrap(fake));
      await tester.pump();

      await tester.tap(find.byIcon(Symbols.mic_none_rounded));
      await tester.pump();

      await tester.tap(find.byIcon(Symbols.mic_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('%'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping stop while the plugin is unresponsive resolves the listening '
    'state within the shorter post-stop timeout, not the 15s start timeout',
    (tester) async {
      final fake = _FakeSpeechService();
      await tester.pumpWidget(_wrap(fake));
      await tester.pump();

      await tester.tap(find.byIcon(Symbols.mic_none_rounded));
      await tester.pump();
      expect(find.text('Listening…'), findsOneWidget);

      // Explicit stop; the fake's stopListening() never calls onStopped,
      // simulating an unresponsive plugin.
      await tester.tap(find.byIcon(Symbols.mic_rounded));
      await tester.pump();
      expect(find.text('Listening…'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));

      expect(find.text('Listening…'), findsNothing);
    },
  );

  testWidgets(
    'after a recite score is shown, Try Again and Continue are both '
    'visible and the self-rate buttons are hidden',
    (tester) async {
      final fake = _ControllableFakeSpeechService();
      await tester.pumpWidget(_wrap(fake));
      await tester.pump();

      await tester.tap(find.byIcon(Symbols.mic_none_rounded));
      await tester.pump();
      await tester.tap(find.byIcon(Symbols.mic_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('I knew it'), findsNothing);
      expect(find.text("Didn't know"), findsNothing);
    },
  );

  testWidgets(
    'tapping Try Again after a recite score resets state without '
    'recording an attempt',
    (tester) async {
      final fake = _ControllableFakeSpeechService();
      await tester.pumpWidget(_wrap(fake));
      await tester.pump();

      await tester.tap(find.byIcon(Symbols.mic_none_rounded));
      await tester.pump();
      await tester.tap(find.byIcon(Symbols.mic_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Try Again'));
      await tester.pump();

      expect(find.text('Recite aloud'), findsOneWidget);
      expect(find.text('Verse 1 of 1'), findsOneWidget);
    },
  );

  testWidgets(
    'the recognized transcript is shown alongside the score, and clears '
    'on retry',
    (tester) async {
      final fake = _ControllableFakeSpeechService(
        finalTranscript: 'for god so loved the world',
      );
      await tester.pumpWidget(_wrap(fake));
      await tester.pump();

      await tester.tap(find.byIcon(Symbols.mic_none_rounded));
      await tester.pump();
      await tester.tap(find.byIcon(Symbols.mic_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('for god so loved the world'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await tester.pump();

      expect(find.textContaining('for god so loved the world'), findsNothing);
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
    'fill-blank fields show no visible label and carry a numbered '
    'accessible name for screen readers',
    (tester) async {
      await tester.pumpWidget(wrapFillBlank(_verse()));
      await tester.pump();

      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields, isNotEmpty);
      final total = fields.length;
      for (var i = 0; i < total; i++) {
        expect(fields.elementAt(i).decoration?.labelText, isNull);
        expect(
          find.bySemanticsLabel('Blank ${i + 1} of $total'),
          findsOneWidget,
        );
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

  Verse referenceVerse() => Verse(
        id: '1thess_5_19',
        reference: '1 Thessalonians 5:19',
        text: 'Do not quench the Spirit',
        translation: 'ESV',
        packId: 'pack_1',
        addedAt: DateTime(2024, 1, 1),
      );

  testWidgets(
    'a blank landing inside the reference book-name span accepts a '
    'recognized abbreviation',
    (tester) async {
      // Tokens of '1 Thessalonians 5:19' are ['1','Thessalonians','5',':','19'];
      // index 1 is the book-name word.
      await tester.pumpWidget(MaterialApp(
        home: TestSessionScreen(
          verses: [referenceVerse()],
          testMode: TestMode.review,
          selectedFormats: const {TestFormat.fillBlank},
          selectedDirections: const {PromptDirection.textToRef},
          debugBlankIndices: const [1],
        ),
      ));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Thess');
      await tester.tap(find.text('Check Answer'));
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.errorText, isNull);
    },
  );

  testWidgets(
    'typed text remains visible in a blank after checking, and clears on '
    'retry',
    (tester) async {
      await tester.pumpWidget(wrapFillBlank(_verse()));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'wrong');
      await tester.tap(find.text('Check Answer'));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'wrong',
      );

      await tester.tap(find.text('Try Again'));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'a correctly-answered blank announces "Correct" for screen readers',
    (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: TestSessionScreen(
          verses: [_verse()],
          testMode: TestMode.review,
          selectedFormats: const {TestFormat.fillBlank},
          selectedDirections: const {PromptDirection.textToRef},
          debugBlankIndices: const [0],
        ),
      ));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'John');
      await tester.tap(find.text('Check Answer'));
      await tester.pump();

      expect(find.bySemanticsLabel('Correct'), findsOneWidget);
    },
  );

  Verse longVerse() => Verse(
        id: 'rom_8_28',
        reference: 'Romans 8:28',
        text: 'And we know that all things work together for good to them '
            'that love God to them who are the called according to his purpose',
        translation: 'ESV',
        packId: 'pack_1',
        addedAt: DateTime(2024, 1, 1),
      );

  Widget wrapFillBlankWithDensity(Verse verse, BlankDensity density) =>
      MaterialApp(
        home: TestSessionScreen(
          // Forces a fresh State (and thus a fresh initState blank-count
          // computation) each time this test re-pumps with a new density —
          // otherwise Flutter would reuse the existing element/state since
          // the widget type and tree position are unchanged.
          key: ValueKey(density),
          verses: [verse],
          testMode: TestMode.review,
          selectedFormats: const {TestFormat.fillBlank},
          selectedDirections: const {PromptDirection.refToText},
          blankDensity: density,
        ),
      );

  testWidgets(
    'a higher blank density selection produces more blank fields',
    (tester) async {
      await tester.pumpWidget(
        wrapFillBlankWithDensity(longVerse(), BlankDensity.twenty),
      );
      await tester.pump();
      final lowCount = tester.widgetList<TextField>(find.byType(TextField)).length;

      await tester.pumpWidget(
        wrapFillBlankWithDensity(longVerse(), BlankDensity.seventyFive),
      );
      await tester.pump();
      final highCount = tester.widgetList<TextField>(find.byType(TextField)).length;

      expect(highCount, greaterThan(lowCount));
    },
  );
}
