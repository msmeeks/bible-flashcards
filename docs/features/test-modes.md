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
| `lib/utils/scoring.dart` | `computeScore` (LCS), `computeReferenceScore` (lenient book-name matching), `blankIndices` |
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
| `review` | 5 verses chosen at random from the memorized list |

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

### Custom Book-Name Variants (Settings)
`lib/screens/settings/book_variants_screen.dart`, linked from Settings → Data ("Book Name Variants"), lets the user add/remove their own variant spellings per book (e.g. a personal abbreviation). Add flow: book `DropdownButtonFormField` (from `bookDisplayNames`) + free-text `TextFormField` (capped at `maxVariantLength` = 60 chars), inline `errorText` validation, focus returned to the offending field on error. List view shows existing variants with an accessible (48x48, `Semantics`-labeled) delete button per row. Stored variants are capped at `maxCustomVariants` = 200 total (data minimization) and validated server-side (in `DatabaseHelper.addBookNameVariant`) for unknown book code, empty/over-length text, and duplicate (book, variant) pairs — the count-check-then-insert runs inside one `db.transaction` to avoid a race past the cap.

### Fill-in-Blank Word Selection
Words to mask are selected by `blankIndices()` in `lib/utils/scoring.dart`. The step cycles 3→4→5→3→… using `step = 3 + (blankCount % 3)` after each blank is placed, starting with the word at index 2. There is no difficulty setting and no short-word skipping.

### Privacy
Typed test input is held only in ephemeral widget state. It is discarded immediately after the scoring function runs and is never written to the database or logs. Voice transcripts from the recite-mode mic option follow the same rule — held in memory only, discarded immediately after `computeScore` runs, never persisted or logged. See `meta/PRIVACY.md` ("Voice Recitation (Recite Mode)" section) for the full data-handling statement.

### History
Each completed session is stored with: timestamp, mode, list of (reference, score) pairs, and total score. The Settings screen exposes a "Clear History" action. The home screen shows recent memorized verses as chips. Results screen displays verse refs via `formatVerseReference` instead of raw slug.

### Accessibility
Fill-blank feedback in `test_session_screen.dart` uses `TextField` `errorText`/`helperText` (not just color/icon) so screen readers announce "Incorrect — correct: <word>" or "Correct".

### Format Chip UI
`test_screen.dart` format-selection `FilterChip`s use a private `_FormatChip` widget that puts the format icon inside the label `Row` rather than the `avatar` slot, avoiding overlap with the Material selection checkmark.

## Changelog
| Date | Change |
|---|---|
| 2026-06-24 | Added lenient book-name matching for `textToRef` answers (#30): `computeReferenceScore` in `scoring.dart` canonicalizes the typed book-name span before LCS scoring; new shared `lib/utils/book_name_variants.dart` table (built-in variants + longhand/spoken-number forms), `book_name_variants` DB table (v2→v3) for user-added variants with CRUD + caps, new Settings screen `book_variants_screen.dart` |
| 2026-05-27 | Initial documentation |
| 2026-05-27 | Updated with full implementation: enum types, word-level LCS scoring algorithm, fill-blank word selection pattern, setup/session/results screen structure, privacy decision on typed input |
| 2026-05-27 | Corrected enum identifiers, file paths, fill-blank algorithm description, recite scoring values; extracted scoring logic to lib/utils/scoring.dart; added unit tests |
| 2026-06-24 | Added opt-in mic button for recite mode: on-device speech-to-text via `speech_to_text` (`SpeechRecognitionService`), scored with existing LCS `computeScore`, transcript never persisted; RECORD_AUDIO requested at point-of-use; typed/self-rated recite remains the default path |
| 2026-06-23 | Fixed #21/#23/#24/#25: added `TestFormat.label`/`tryFromName` shared label helper (fixed fillBlank/fill_blank mismatch bug), added `verse_reference_format.dart` for slug-to-display formatting on results screen, a11y errorText/helperText for fill-blank feedback, fixed icon/checkmark overlap in format chips via `_FormatChip` |
