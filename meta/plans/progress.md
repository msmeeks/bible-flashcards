# Iteration Progress

## 2026-07-06 — fix-recite-aloud-speech.md (#134, #135, #136)

Implemented all three recite-aloud fixes in one pass:
- **#134**: `SpeechRecognitionService.listen()` now sets `pauseFor: Duration(seconds: 15)` to tolerate thinking pauses. Also found and fixed a real bug while verifying the manual stop affordance: tapping the mic to stop early cleared `_listeningVerseIndex` before the plugin's async final transcript arrived, causing it to be silently discarded (no score shown). Manual stop now defers state reset to the normal finalization path, same as an auto-triggered stop. Added a tooltip on the mic button clarifying the stop action.
- **#135**: Recite-aloud score reveal now shows "Try Again" + "Continue" (mirroring fill-blank), gated the self-rate row so it's hidden once a score is shown (previously all four buttons were visible simultaneously).
- **#136**: Recognized transcript is captured and shown as plain text alongside the score; cleared on retry/advance, never persisted.

Added a `_ControllableFakeSpeechService` test double (simulates the plugin's async-after-resolve final-transcript delivery) and 4 new widget tests in `test/screens/test/test_session_screen_test.dart`. Full suite (491 tests) + `flutter analyze` pass — analyze findings are pre-existing, unrelated to this change. Updated `docs/features/test-modes.md`.

## 2026-07-06 — fix-test-result-reference-formatting.md (#137)

Test Summary (`test_result_screen.dart`) and Test History (`test_history_screen.dart`) now resolve each result's verse via `DatabaseHelper.getVerseById`, batched up front with `Future.wait` into a `Map<String, Verse?>`, and display the verse's stored `reference` field instead of re-deriving one from the id via `formatVerseReference` — which only recognized bundled-pack book-slug abbreviations and silently fell back to the raw id for custom-added verses (ids like `esv_romans_2_2` don't match the abbreviation dictionary). Deleted verses (map lookup returns `null`) show the raw id with an italic "(verse deleted)" suffix rather than a bare, ambiguous slug. Also fixed an adjacent bug in Test History's format-label switch, which compared snake_case `'fill_blank'` against the camelCase `.name` value actually stored (`fillBlank`) and so never matched — replaced with the shared `TestFormatLabel.tryFromName` helper already used on the results screen.

Added `test_results` table to the shared `test/helpers/fake_database_helper.dart` fake-DB schema (previously missing) so both new widget-test files could exercise `insertTestResult`/`getTestResults` against a real in-memory sqflite DB. New tests: `test/screens/test/test_result_screen_test.dart` (2 tests: custom-verse reference resolution, deleted-verse fallback) and `test/screens/settings/test_history_screen_test.dart` (2 tests: custom-verse reference resolution, fill-blank label fix). Full suite (495 tests) + `flutter analyze` pass — analyze findings are pre-existing, unrelated to this change. Updated `docs/features/test-modes.md`.
