import 'package:flutter_test/flutter_test.dart';

import 'package:bible_flashcards/services/speech_recognition_service.dart';

// SpeechRecognitionService wraps the speech_to_text plugin's SpeechToText
// class, which requires native plugin registration (speech recognizer
// availability, mic permission channel) only present on a real device or
// emulator. permission_handler's Permission.microphone.request() has the
// same constraint. Neither can be satisfied in a headless unit test
// environment without injecting the platform instance — see
// notification_service_test.dart for the same limitation on a different
// plugin wrapper in this codebase.
//
// Coverage for permission request, on-device initialization, listen/stop/
// cancel, and transcript scoring is provided by manual/integration testing
// on the emulator (see meta/plans/feat-recite-test-stt.md verification
// checklist).

void main() {
  group('SpeechRecognitionService', () {
    test('isListening is false before any listen() call', () {
      final service = SpeechRecognitionService();
      expect(service.isListening, isFalse);
    });

    test('dispose does not throw', () {
      final service = SpeechRecognitionService();
      expect(service.dispose, returnsNormally);
    });
  });
}
