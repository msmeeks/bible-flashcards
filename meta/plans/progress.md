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

## 2026-07-07 — fix-flashcard-translation-readonly.md (#131)

Removed the non-functional Translation selector from `lib/screens/verses/verse_detail_screen.dart`: deleted the `_TranslationSelector` `SegmentedButton` widget, its call site, and the dead `_selectedTranslation` state field that backed it (never persisted, never read anywhere). The verse's real translation was already displayed correctly, read-only, via the existing `_MetadataCard` row on the same screen — unchanged.

TDD'd with a new `test/screens/verses/verse_detail_screen_test.dart` asserting no `SegmentedButton` is present on the screen and the verse's actual translation renders as text; confirmed RED (selector still present) before deleting the widget, then GREEN. Full suite (493 tests) + `flutter analyze` pass — only pre-existing, unrelated deprecation infos remain. Updated `docs/features/verse-management.md` via the doc-writer agent.

## 2026-07-06 — feat-add-verse-confirmation-redesign.md (#128, #129)

Redesigned the Add Verse confirmation flow in `lib/screens/verses/add_verse_screen.dart`, built incrementally via TDD (one vertical slice per behavior):

- **#128**: Removed the inline Accept/Dismiss preview card — a successful web/ESV lookup now writes the fetched reference/text directly into the form fields. Added focus-loss reference normalization: leaving the reference field now runs the same `normalizeReferenceForSave` resolution used at save time, rewriting the field in place (e.g. "phil 4:13" → "Philippians 4:13") or surfacing an inline "Unrecognized book name" error, without stealing focus back on failure. Replaced the old inline "Will save as: ... Confirm & Save / Edit" card with a real `AlertDialog` ("Save this verse?", showing the normalized reference + full verse text, `OutlinedButton` Cancel / `FilledButton` Save) — the one place that guarantees the user sees exactly what will be persisted, mirroring the existing ESV/Bible consent-dialog pattern (including focus restoration to Search after close).
- **#129**: Added a `CheckboxListTile` "Add directly to Memorized" near the translation selector; when checked, `_commitSave` constructs the `Verse` with `isMemorized: true`/`memorizedAt: DateTime.now()` instead of the default unmemorized state.

Rewrote `test/screens/verses/add_verse_screen_test.dart`'s preview/confirm-card tests for the new dialog-based flow and added 5 new tests (blur normalization success/failure, dialog confirm/cancel, memorized checkbox). Full suite (500 tests) + `flutter analyze` pass, plus the full `scripts/smoke_test.sh` (unit suite + on-device integration test: add a verse, memorize it, confirm Home reflects it, complete a test session) passed end-to-end. Updated `docs/features/verse-management.md`, `docs/features/esv-attribution.md` (stale preview-dialog wording for the ESV footer), and `docs/llms.md`.

## 2026-07-07 — fix-design-brief-button-audit.md (#133)

Continued a prior in-progress attempt (found 10 of 12 dialogs already swapped and uncommitted in the working tree) and finished the remaining two "full-redesign" dialogs, per the plan's table:

- **`test_session_screen.dart:350`** (Microphone access needed): `Cancel` → `OutlinedButton`, `Open Settings` → `FilledButton` (behavior/`onPressed` unchanged).
- **`verse_detail_screen.dart:148`** (Remove from memorized?): `Cancel` → `OutlinedButton`, `Remove` → error-colored `FilledButton` (`backgroundColor: cs.error`, `foregroundColor: cs.onError`), matching the destructive-button pattern already used in `data_management_screen.dart`.

All 12 dialogs from the plan's table now use `OutlinedButton`/`FilledButton` action pairs; verified no other `AlertDialog` action pairs remain on bare `TextButton` (the handful of remaining `TextButton`s app-wide are inline links/toggles/single-button dismissals, correctly out of scope per the plan).

TDD'd the two remaining dialogs: added a `_PermanentlyDeniedSpeechService` test double (already scaffolded from the prior attempt) and a new widget test in `test/screens/test/test_session_screen_test.dart` asserting the mic-permission dialog's button types; added a new widget test in `test/screens/verses/verse_detail_screen_test.dart` asserting the remove-confirmation dialog's button types and error coloring. Confirmed both RED before implementing, then GREEN. Full suite (504 tests) + `flutter analyze` pass (only pre-existing, unrelated deprecation infos remain), plus the full `scripts/smoke_test.sh` (unit suite + on-device integration test) passed end-to-end.

## 2026-07-07 — fix-dark-theme-badge-contrast.md (#138)

Lightened `ConfidenceBadge`'s dark-theme Strong/Learning/Weak colors, which previously sat too close in luminance to the dark surface (#1C1917), reading muddy:

- `successContainer` (`lib/theme/app_colors.dart`): `#0F3D1E` → `#1D7439` (kept the same hue/saturation, just lighter); `onSuccessContainer` unchanged (`#C8F0D0`, still clears 4.5:1 against the new fill).
- `warningContainer`: `#4A3800` → `#816100` — a smaller lightness jump than success/error per the issue's explicit ask; `onWarningContainer` changed from the reused light-theme hex (`#FFDEA3`, no longer sufficient contrast) to a dedicated `#FFF2CC`.
- `errorContainer`/`onErrorContainer` weren't previously overridden for dark — they fell through to the MD3-seed defaults (`#93000A`/`#FFDAD6`), also too dark. Added dark-only overrides in `lib/theme/app_theme.dart`'s `dark()` `.copyWith(...)`: `#D6000F`/`#FFE9E6`.

Followed the plan's pre-implementation review: added a new `contrast_test.dart` group asserting all three dark containers meet 3:1 against `surface` (the WCAG 1.4.11 non-text/UI-boundary check the existing suite didn't cover — it only asserted on-color vs. container). TDD'd these three assertions first (confirmed RED against the old hex values), then iterated hex values (picked via a hue/saturation-preserving lightness search satisfying both the new 3:1-vs-surface and existing 4.5:1-vs-on-color constraints) until GREEN. Added one-line cross-reference comments between `app_colors.dart` and `app_theme.dart` noting the split location for future tier additions. Light theme and the Pending badge's `surfaceContainerHighest`/`onSurfaceVariant` untouched. Full suite (507 tests) + `flutter analyze` pass (only pre-existing, unrelated deprecation infos remain).

## 2026-07-07 — fix-verse-lookup-dedup.md (#140, #141)

Deduplicated the verse-lookup-by-id logic shared by `test_result_screen.dart` and `test_history_screen.dart`:

- Added `DatabaseHelper.getVersesByIds(Set<String>)` — a single batched `WHERE id IN (...)` query, replacing the two screens' independent N+1 `Future.wait` loops over `getVerseById`. Removed `getVerseById` entirely once it had no remaining callers.
- Extracted `resolveVersesForResults(results, db)` in `lib/services/verse_result_lookup.dart` — collects unique verse ids from a result list and resolves them via the batch method; both screens now call this instead of duplicating the collection/lookup logic.
- Extracted `VerseReferenceLabel` (`lib/widgets/verse_reference_label.dart`) — renders a result's verse reference or the italic "$id (verse deleted)" fallback identically on both screens.

TDD'd bottom-up: `getVersesByIds` (2 new tests in `test/database/database_helper_test.dart`), `resolveVersesForResults` (1 new test in `test/services/verse_result_lookup_test.dart`), `VerseReferenceLabel` (2 new tests in `test/widgets/verse_reference_label_test.dart`), then refactored both screens to use them — their existing behavior-level widget tests passed unmodified, confirming no user-visible change. Full suite (512 tests) + `flutter analyze` pass (only pre-existing, unrelated deprecation infos remain).
