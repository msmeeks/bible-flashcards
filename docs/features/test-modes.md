# Test Modes

## Summary
The test feature helps the user confirm memorization through active recall. Two modes (verse-of-week and review) cover both current learning and long-term retention, with multiple prompt/response formats and per-verse accuracy scoring.

## Users / Use Cases
- **Solo user**: runs verse-of-week tests to confirm the current verse is locked in; runs review tests to check retention of previously memorized verses.

## Technologies
- `sqflite_sqlcipher` — stores test session history and per-verse scores
- Provider — `TestProvider` manages active session state
- Flutter UI — setup screen, active session screen, results screen

## Technical Overview
A test session is a sequence of verse cards. The user first configures mode, format, and prompt direction on a setup screen, then works through the active session screen one card at a time. After all cards are answered the results screen scores and persists the session. Typed test input is discarded immediately after scoring and never written to the database.

## Key Files
| File | Purpose |
|---|---|
| `lib/screens/test/test_screen.dart` | Mode, format, and direction pickers |
| `lib/screens/test/test_session_screen.dart` | Active card display, recite/type/fill-blank input |
| `lib/screens/test/test_result_screen.dart` | Per-card scores, session total |
| `lib/screens/test/test_enums.dart` | `TestMode`, `TestFormat`, `PromptDirection` enums |
| `lib/models/test_result.dart` | `VerseTestResult` and `TestSessionResult` models |
| `lib/utils/scoring.dart` | `computeScore` (LCS), `computeReferenceScore` (lenient book-name matching), `blankCountForPercentage`, `blankIndices` |
| `lib/utils/book_name_variants.dart` | Shared book-name-variant table (`builtInBookNameVariants`, `bookDisplayNames`, `normalizeBookNameKey`, `bookNameToUsfm`); single source of truth, also used by `BibleLookupService` |
| `lib/services/speech_recognition_service.dart` | On-device speech-to-text wrapper for recite mode (mic permission, listen/stop/cancel) |
| `lib/utils/verse_reference_format.dart` | `formatVerseReference` — slug ("esv_phil_4_13") to display string ("Phil 4:13 (ESV)") |
| `lib/screens/settings/book_variants_screen.dart` | Settings UI to add/remove custom book-name variants |
| `lib/database/database_helper.dart` | `book_name_variants` table + CRUD (`getBookNameVariants`, `addBookNameVariant`, `removeBookNameVariant`, `getCustomVariantLookup`) |

## Technical Detail

### Enums

```dart
enum TestMode { verseOfWeek, review }
enum TestFormat { recite, type, fillBlank }
enum PromptDirection { refToText, textToRef }
```

`fillBlank` ignores `PromptDirection` (always reference context → masked text).

`TestFormat.label` extension getter is single source of truth for display labels ("Recite"/"Type"/"Fill Blanks"), used by `test_screen.dart` and `test_result_screen.dart`. `TestFormatLabel.tryFromName` does safe string-to-enum lookup for stored values. Fixes prior bug where `test_result_screen.dart` checked for `'fill_blank'` when stored value was actually `'fillBlank'`.

### Modes

| Mode | Verses Tested |
|---|---|
| `verseOfWeek` | The single current verse only |
| `review` | User-chosen count of verses, randomly chosen from the memorized list, via `getRandomMemorizedVerses(count, includeVerseOfWeek)` |

### Review Mode Controls (`test_screen.dart`)
When Review mode is selected, a count `Slider` (1 → memorized-verse count) plus jump-`FilterChip`s (5/10/20/All — chips above the memorized count are omitted entirely, not disabled) and an "Include verse of the week" `SwitchListTile` (default on) appear below the mode selector; both are hidden in Verse of Week mode. Starting a Review-mode session with zero memorized verses shows a prerequisite error instead of rendering the slider (which has no valid range at zero).

### Prompt / Response Formats

| Format | Prompt | User Action |
|---|---|---|
| `recite` (referenceToText) | Reference shown | User recites the text aloud |
| `recite` (textToReference) | Verse text shown | User recites the reference aloud |
| `type` (referenceToText) | Reference shown | User types the verse text |
| `type` (textToReference) | Verse text shown | User types the reference |
| `fillBlank` | Verse text with words masked | User types or selects missing words |

### Scoring Algorithm
**Typed and fill-in-blank responses** use word-level Longest Common Subsequence (LCS):

```
score = lcs_length(typed_words, correct_words) / max(len(typed_words), len(correct_words))
```

- Comparison is case-insensitive and strips punctuation before tokenising.
- Denominator is `max(typed length, correct length)` — penalises both omissions and extra words equally.
- Result is clamped to 0–100%.

**Recite responses**: default path is self-rating — user sees the correct answer and rates "I knew it" (1.0) or "Didn't know" (0.0). An opt-in mic button (`_buildReciteArea`/`_onMicPressed` in `test_session_screen.dart`) lets the user instead speak the verse; `SpeechRecognitionService` runs on-device speech-to-text (package `speech_to_text`, `onDevice: true`, no cloud fallback — listen fails outright if on-device recognition isn't available), and the final transcript is scored with the same `computeScore` LCS function used for typed input via `_onReciteTranscriptFinal`. RECORD_AUDIO permission is requested at point-of-use (when the mic button is pressed), not pre-granted at app launch.

**Session total** = arithmetic mean of all card scores.

### Lenient Book-Name Matching (textToRef answers)
When the prompt direction is `textToReference` (user types or recites the reference), `test_session_screen.dart`'s `_scoreAnswer()` calls `computeReferenceScore` instead of plain `computeScore`. It splits both the typed/spoken answer and the correct reference into book-name span + chapter:verse span (regex `^(.+?)\s+(\d+:\d+(?:-\d+)?)\s*$`), resolves each book name to a USFM code via `bookNameToUsfm` (built-in table plus any custom variants), and — if both resolve to the **same** book — rewrites the typed book name to match the correct wording before running the usual word-level LCS. So "1 Pt 5:7", "First Peter 5:7", and "The First Letter of Peter 5:7" (if added as a custom variant) all score identically to whatever wording the stored verse reference uses. If either book name is unrecognized, or the two resolve to different books, it falls straight through to plain `computeScore` (no silent pass for wrong-book answers). `fillBlank` and `refToText` directions are untouched — book names there aren't a "type the reference" target, so the issue (#30) scoped lenient matching to `textToRef` only.

Custom variants are loaded once per session in `initState` via `_loadCustomVariants()` → `DatabaseHelper.getCustomVariantLookup()`, which merges all stored rows into a normalized-key → USFM-code map layered on top of the built-in table (built-in never mutated).

### Natural Separator/Range Normalization (typed references)
Before `computeReferenceScore` splits a typed reference into book-name + chapter:verse spans, `_normalizeReferenceInput()` (`lib/utils/scoring.dart`) rewrites common natural-language separator and range variants into the canonical `Chapter:Verse` / `Verse-Verse` form, so e.g. "Phil 4.13", "Phil 4 13", and "Phil 4 colon 13" all score identically to "Phil 4:13", and "John 3:16 to/through/and 17" scores identically to "John 3:16-17". Rewrite order is significant — word-based connectors (`colon`, `dot`, `dash`, `to`/`through`, `and`) are resolved before the bare two-number-with-space rule, otherwise a range like "16 to 17" would become "16:to 17" before "to" is replaced. This only runs on the *typed* side; the stored `correct` reference is assumed already canonical.

### Custom Book-Name Variants (Settings)
`lib/screens/settings/book_variants_screen.dart`, linked from Settings → Data ("Book Name Variants"), lets the user add/remove their own variant spellings per book (e.g. a personal abbreviation). Add flow: book `DropdownButtonFormField` (from `bookDisplayNames`) + free-text `TextFormField` (capped at `maxVariantLength` = 60 chars), inline `errorText` validation, focus returned to the offending field on error. List view shows existing variants with an accessible (48x48, `Semantics`-labeled) delete button per row. Stored variants are capped at `maxCustomVariants` = 200 total (data minimization) and validated server-side (in `DatabaseHelper.addBookNameVariant`) for unknown book code, empty/over-length text, and duplicate (book, variant) pairs — the count-check-then-insert runs inside one `db.transaction` to avoid a race past the cap.

### Fill-in-Blank Word Selection
Blank count and positions are now percentage-driven and randomized, replacing the old fixed 3→4→5 step cycle (#98/#99).

`test_enums.dart` defines `BlankDensity` (twenty/thirty/fifty/seventyFive/random), each with a `.label` ("20%" etc.) and `.percentage` getter; `random` has no single percentage and instead re-rolls one of `BlankDensityLabel.fixedPercentages` ([20, 30, 50, 75]) independently per verse. `test_screen.dart` shows a single-select `ChoiceChip` row for density (unlike the multi-select `FilterChip` rows for Format/Direction), visible only when Fill Blank format is selected, default 20%, in a live region so screen readers announce its appearance/disappearance. `TestSessionScreen` takes a `blankDensity` param (default `BlankDensity.twenty`).

For each verse, `blankCountForPercentage(candidateWordCount, percentage)` in `lib/utils/scoring.dart` computes `round(percentage / 100 * candidateWordCount)`, floored at 1 (for 20%) or 2 (for 30/50/75%) so at least one blank always appears. `blankIndices(words, count, {Random? random})` then randomly selects `count` distinct non-`':'` candidate positions (falls back to all candidates if `count` exceeds availability), sorted ascending to preserve word order. `random` is injectable for deterministic tests; `TestSessionScreen` keeps one instance-level `Random` for its whole session and re-rolls the percentage (not the RNG) per verse when density is `random`.

### Privacy
Typed test input is held only in ephemeral widget state. It is discarded immediately after the scoring function runs and is never written to the database or logs. Voice transcripts from the recite-mode mic option follow the same rule — held in memory only, discarded immediately after `computeScore` runs, never persisted or logged. See `meta/PRIVACY.md` ("Voice Recitation (Recite Mode)" section) for the full data-handling statement.

### History
Each completed session is stored with: timestamp, mode, list of (reference, score) pairs, and total score. The Settings screen exposes a "Clear History" action. The home screen shows recent memorized verses as chips. Results screen displays verse refs via `formatVerseReference` instead of raw slug.

### ESV Attribution
`test_session_screen.dart` renders `EsvCopyrightFooter(hasEsvContent: _currentVerse.translation == 'ESV')` below the answer area. See `docs/features/esv-attribution.md` for the shared widget's behavior.

### Accessibility
Fill-blank feedback in `test_session_screen.dart` uses `TextField` `errorText`/`helperText` (not just color/icon) so screen readers announce "Incorrect — correct: <word>" or "Correct".

### Format Chip UI
`test_screen.dart` format-selection `FilterChip`s use a private `_FormatChip` widget that puts the format icon inside the label `Row` rather than the `avatar` slot, avoiding overlap with the Material selection checkmark.

## Changelog
| Date | Change |
|---|---|
| 2026-06-30 | Fill-blank difficulty now percentage-based and randomized (#98/#99): `blankIndices` reworked to take an explicit `count` and pick random distinct positions (was fixed 3→4→5 step cycle); new `blankCountForPercentage`; new `BlankDensity` enum + `ChoiceChip` density picker in `test_screen.dart`; `TestSessionScreen` re-rolls percentage per verse for the "random" density option |
| 2026-06-26 | Normalized natural separator/range variants in typed references before scoring (#43, #44): `_normalizeReferenceInput()` handles "colon"/"dot"/"dash" words, "to"/"through"/"and" ranges, bare-dot, and bare-space chapter:verse forms |
| 2026-06-25 | Retrofitted Review mode (#49) with a user-chosen count slider/chips + verse-of-week toggle, replacing the hardcoded 5-verse selection; wired into `getRandomMemorizedVerses(count, includeVerseOfWeek)` (#46/#53) |
| 2026-06-24 | Added lenient book-name matching for `textToRef` answers (#30): `computeReferenceScore` in `scoring.dart` canonicalizes the typed book-name span before LCS scoring; new shared `lib/utils/book_name_variants.dart` table (built-in variants + longhand/spoken-number forms), `book_name_variants` DB table (v2→v3) for user-added variants with CRUD + caps, new Settings screen `book_variants_screen.dart` |
| 2026-05-27 | Initial documentation |
| 2026-05-27 | Updated with full implementation: enum types, word-level LCS scoring algorithm, fill-blank word selection pattern, setup/session/results screen structure, privacy decision on typed input |
| 2026-05-27 | Corrected enum identifiers, file paths, fill-blank algorithm description, recite scoring values; extracted scoring logic to lib/utils/scoring.dart; added unit tests |
| 2026-06-24 | Added opt-in mic button for recite mode: on-device speech-to-text via `speech_to_text` (`SpeechRecognitionService`), scored with existing LCS `computeScore`, transcript never persisted; RECORD_AUDIO requested at point-of-use; typed/self-rated recite remains the default path |
| 2026-06-23 | Fixed #21/#23/#24/#25: added `TestFormat.label`/`tryFromName` shared label helper (fixed fillBlank/fill_blank mismatch bug), added `verse_reference_format.dart` for slug-to-display formatting on results screen, a11y errorText/helperText for fill-blank feedback, fixed icon/checkmark overlap in format chips via `_FormatChip` |
