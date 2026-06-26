# Progress Log

## 2026-06-26 — refactor-audio-interrupt-probability.md (#42)

Repurposed the audio interrupt probability slider so it controls how often the
verse-of-week is chosen vs. a random memorized verse, instead of gating
whether an interrupt fires at all. Interrupts now always fire once the time
threshold is crossed.

- `lib/services/audio_interrupt_service.dart`: removed the probabilistic gate
  in `_checkThreshold`; extracted verse selection into a top-level
  `@visibleForTesting` `pickVerseForInterrupt()` function so the weighting
  logic can be unit tested directly (the timer/threshold path relies on real
  `DateTime.now()`, which doesn't cooperate with `fakeAsync`).
- `lib/models/settings.dart`: clamp `audioInterruptProbability` to `[0.0, 1.0]`
  in `fromMap` as a tamper guard (SharedPreferences is unencrypted).
- `lib/screens/settings/settings_screen.dart`: renamed the slider label and
  dialog title to "Verse-of-week probability".
- `docs/features/audio.md`: updated settings table + changelog.
- Added `test/services/audio_interrupt_service_test.dart` (probability 0.0,
  1.0, 0.5 cases) and two clamp tests in `test/models/settings_test.dart`.

`flutter test` passes (283 passed; 1 pre-existing unrelated failure in
`test/widget_test.dart` — confirmed present before this change too).

## 2026-06-26 — feat-esv-lookup.md (#67)

Implemented ESV text lookup and storage, the foundational plan that unblocks
feat-esv-attribution, feat-esv-settings, and feat-esv-audio.

- `lib/services/esv_lookup_service.dart`: new `EsvLookupService`, mirrors
  `BibleLookupService` but targets `api.esv.org` (Crossway). Auth via
  `Authorization: Token <key>` header; key read from
  `String.fromEnvironment('ESV_API_KEY')`. Instance `isAvailable` getter
  reflects whether the key is configured. 50-entry LRU cache, 10s timeout,
  same `LookupException` surface as the existing service.
- `lib/database/database_helper.dart`: added `insertEsvVerse(verse, {cap:
  500})` — atomic transaction enforcing Crossway's 500-verse storage cap,
  preventing double-save races.
- `lib/providers/verse_provider.dart`: added `esvVerseCount` getter;
  `addCustomVerse` now routes ESV verses through `insertEsvVerse`.
- `lib/models/settings.dart`: `defaultTranslation` validated against an
  allowlist (`BSB`, `KJV`, `WEB`, `ESV`) in `fromMap`, same tamper-guard
  pattern as `backupCadence`.
- `lib/screens/verses/add_verse_screen.dart`: ESV presented as a distinct
  `ActionChip` below the BSB/KJV/WEB segmented button (hidden when the build
  has no API key); consent flow extracted into shared `_ensureConsentFor`
  helper with an isolated `esv_lookup_consent_v1` key; pre-lookup cap
  advisory (`warningContainer`) and save-time cap block (`errorContainer`);
  fixed two pre-existing a11y gaps (focus restore after preview
  accept/dismiss, error icons alongside color).
- `meta/PRIVACY.md`: added ESV Verse Lookup section (api.esv.org/Crossway
  recipient, 500-verse cap, isolated consent key) and updated network
  request and data-table sections.
- `docs/features/verse-management.md` and `docs/llms.md`: updated.
- Added `test/services/esv_lookup_service_test.dart` (14 cases) and tests for
  `esvVerseCount` and `defaultTranslation` allowlist.

No existing test harness covers `DatabaseHelper` against a real sqlite
engine in this repo, so `insertEsvVerse`'s atomicity wasn't independently
unit-tested — consistent with the existing test boundary for that class.

`flutter test` passes (303 passed; same 1 pre-existing unrelated failure in
`test/widget_test.dart`).

## 2026-06-26 — feat-auto-verse-of-week.md (#45)

Implemented automatic weekly verse-of-week advancement. Picked this plan over
`feat-reference-scoring-normalization.md` (self-contained but had been
repeatedly skipped by prior runs without an architectural reason to skip
again) and `feat-esv-audio.md` (its plan explicitly requires discovering the
live Crossway audio CDN hostname from a real API response before hardcoding
a security allowlist — not safely doable without network/API-key access in
this environment).

- `lib/models/settings.dart`: added `autoAdvanceVerseOfWeek` (bool, default
  false) and `lastVerseAdvanceDate` (`DateTime?`) to `AppSettings`, with the
  same far-future tamper-guard pattern as `lastBackupAt` in `fromMap`.
- `lib/providers/settings_provider.dart`: persists/loads both new fields
  through `_persist`/`load`, following the existing key-per-field pattern.
- `lib/providers/verse_provider.dart`: added `pickVerseForAutoAdvance`
  (`@visibleForTesting`) — pure decision logic (disabled / not-Sunday /
  already-advanced-this-ISO-week / no-candidate checks) kept separate from
  the DB write so it's unit-testable without a real database, mirroring the
  `pickVerseForInterrupt` precedent from the audio-interrupt-probability
  plan. `autoAdvanceVerseOfWeekIfNeeded` wraps it and calls
  `setVerseOfWeek` + an `onUpdate` callback to persist the new
  `lastVerseAdvanceDate`. ISO-week equality compares the Monday of each
  date's week, correctly handling the Dec/Jan year boundary.
- `lib/screens/settings/settings_screen.dart`: added "Auto-advance verse of
  the week" `SwitchListTile`.
- `lib/screens/home/home_screen.dart`: calls
  `autoAdvanceVerseOfWeekIfNeeded` in the existing post-frame callback after
  `loadVerses()`.
- `meta/PRIVACY.md`, `docs/features/verse-management.md`, `docs/llms.md`:
  updated.
- Tests added in `test/models/settings_test.dart`,
  `test/providers/settings_provider_test.dart`,
  `test/providers/verse_provider_test.dart` (including the Dec-28/Dec-29
  ISO-week-boundary pair), and `test/screens/settings/settings_screen_test.dart`.
  The `HomeScreen` wiring itself isn't independently tested — it calls
  `loadVerses()` against a real `DatabaseHelper`/sqflite, the same untested
  DB-touching boundary noted for `insertEsvVerse` in the prior entry.

`flutter test` passes (318 passed; same 1 pre-existing unrelated failure in
`test/widget_test.dart`). `flutter analyze` clean.
