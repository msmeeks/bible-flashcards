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

## 2026-07-07 — chore-settings-cleanup.md (#130, #132)

Removed the Google Drive cloud-backup feature entirely and fixed the Android app display label:

- **#130**: Deleted `lib/services/google_drive_service.dart` and the "Cloud Backup" section (Connect/Back Up Now/Backup Frequency/Restore from Drive/Delete Drive Backup/Disconnect) from `data_management_screen.dart` — only Export Data/Save Locally/Import Data remain. Removed the five Drive-only `AppSettings` fields (`driveBackupEnabled`, `backupCadence`, `lastBackupAt`, `driveConsentAt`, `driveConsentVersion`) from the model, provider persistence, and their tests (`settings_test.dart`, `import_service_test.dart`). Removed the now-unused `google_sign_in`/`googleapis` pubspec dependencies. Added `LegacySettingsMigration.clearStaleDriveSignInFlag()` (TDD'd against a mocked `flutter_secure_storage` method channel), called once from `main.dart` at startup, to delete the orphaned `drive_signed_in` intent-flag key left in Keystore-backed secure storage for any user who had previously connected Drive — it never stored OAuth tokens, just the flag.
- **#132**: Changed `android:label` in `AndroidManifest.xml` from `"bible_flashcards"` to `"Bible Flashcards"` (on-device display name only; `pubspec.yaml`'s package name untouched).

Updated `meta/PRIVACY.md` to remove the Cloud Backup section and all Google Drive references (data table, special-category-data note, permissions table, third-party SDK list). Updated `docs/features/data-management.md` and `docs/llms.md` via the doc-writer agent. Full suite (492 tests) + `flutter analyze` pass (only pre-existing, unrelated deprecation infos remain).

## 2026-07-06 — feat-add-verse-confirmation-redesign.md (#128, #129)

Redesigned the Add Verse confirmation flow in `lib/screens/verses/add_verse_screen.dart`, built incrementally via TDD (one vertical slice per behavior):

- **#128**: Removed the inline Accept/Dismiss preview card — a successful web/ESV lookup now writes the fetched reference/text directly into the form fields. Added focus-loss reference normalization: leaving the reference field now runs the same `normalizeReferenceForSave` resolution used at save time, rewriting the field in place (e.g. "phil 4:13" → "Philippians 4:13") or surfacing an inline "Unrecognized book name" error, without stealing focus back on failure. Replaced the old inline "Will save as: ... Confirm & Save / Edit" card with a real `AlertDialog` ("Save this verse?", showing the normalized reference + full verse text, `OutlinedButton` Cancel / `FilledButton` Save) — the one place that guarantees the user sees exactly what will be persisted, mirroring the existing ESV/Bible consent-dialog pattern (including focus restoration to Search after close).
- **#129**: Added a `CheckboxListTile` "Add directly to Memorized" near the translation selector; when checked, `_commitSave` constructs the `Verse` with `isMemorized: true`/`memorizedAt: DateTime.now()` instead of the default unmemorized state.

Rewrote `test/screens/verses/add_verse_screen_test.dart`'s preview/confirm-card tests for the new dialog-based flow and added 5 new tests (blur normalization success/failure, dialog confirm/cancel, memorized checkbox). Full suite (500 tests) + `flutter analyze` pass, plus the full `scripts/smoke_test.sh` (unit suite + on-device integration test: add a verse, memorize it, confirm Home reflects it, complete a test session) passed end-to-end. Updated `docs/features/verse-management.md`, `docs/features/esv-attribution.md` (stale preview-dialog wording for the ESV footer), and `docs/llms.md`.
