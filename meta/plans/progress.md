# Iteration Progress

## 2026-07-06 — fix-recite-aloud-speech.md (#134, #135, #136)

Implemented all three recite-aloud fixes in one pass:
- **#134**: `SpeechRecognitionService.listen()` now sets `pauseFor: Duration(seconds: 15)` to tolerate thinking pauses. Also found and fixed a real bug while verifying the manual stop affordance: tapping the mic to stop early cleared `_listeningVerseIndex` before the plugin's async final transcript arrived, causing it to be silently discarded (no score shown). Manual stop now defers state reset to the normal finalization path, same as an auto-triggered stop. Added a tooltip on the mic button clarifying the stop action.
- **#135**: Recite-aloud score reveal now shows "Try Again" + "Continue" (mirroring fill-blank), gated the self-rate row so it's hidden once a score is shown (previously all four buttons were visible simultaneously).
- **#136**: Recognized transcript is captured and shown as plain text alongside the score; cleared on retry/advance, never persisted.

Added a `_ControllableFakeSpeechService` test double (simulates the plugin's async-after-resolve final-transcript delivery) and 4 new widget tests in `test/screens/test/test_session_screen_test.dart`. Full suite (491 tests) + `flutter analyze` pass — analyze findings are pre-existing, unrelated to this change. Updated `docs/features/test-modes.md`.
