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
| `lib/screens/test/test_session_screen.dart` | Active card display, type/fill-blank input, `_AnswerDiff` render widget |
| `lib/screens/test/test_result_screen.dart` | Per-card scores, session total |
| `lib/screens/test/test_enums.dart` | `TestMode`, `TestFormat`, `PromptDirection` enums |
| `lib/models/test_result.dart` | `VerseTestResult` and `TestSessionResult` models |
| `lib/utils/scoring.dart` | `computeScore` (LCS), `diffWords` (word-level diff), `normalizeWords`, `computeReferenceScore` (lenient book-name matching), `blankCountForPercentage`, `blankIndices` |
| `lib/utils/book_name_variants.dart` | Shared book-name-variant table (`builtInBookNameVariants`, `bookDisplayNames`, `normalizeBookNameKey`, `bookNameToUsfm`); single source of truth, also used by `BibleLookupService` |
| `lib/utils/verse_reference_format.dart` | `formatVerseReference` — slug ("esv_phil_4_13") to display string ("Phil 4:13 (ESV)") |
| `lib/screens/settings/book_variants_screen.dart` | Settings UI to add/remove custom book-name variants |
| `lib/database/database_helper.dart` | `book_name_variants` table + CRUD (`getBookNameVariants`, `addBookNameVariant`, `removeBookNameVariant`, `getCustomVariantLookup`) |

## Technical Detail

### Enums

```dart
enum TestMode { verseOfWeek, review }
enum TestFormat { type, fillBlank }
enum PromptDirection { refToText, textToRef }
```

`fillBlank` ignores `PromptDirection` (always reference context → masked text).

`TestFormat.label` extension getter is single source of truth for display labels ("Type"/"Fill Blanks"), used by `test_screen.dart` and `test_result_screen.dart`. `TestFormatLabel.tryFromName` does safe string-to-enum lookup for stored values, returning `null` for any name that doesn't match a current enum member.

**Recite mode was removed entirely (#165).** On-device speech recognition proved unreliable in practice; Type mode plus the device keyboard's own dictation covers the same need. Removed: `lib/services/speech_recognition_service.dart` and its test, the `speech_to_text` and `permission_handler` pubspec dependencies, and the `RECORD_AUDIO` manifest permission. `TestResult.testFormat` is still stored as a free-form string rather than a validated enum name, and `TestFormatLabel.tryFromName` deliberately returns `null` for `"recite"` (and any other unrecognized value) rather than throwing — this is a read-tolerance decision so pre-#165 history rows keep rendering. `test_result_screen.dart` and `test_history_screen.dart` both fall back to displaying the raw stored string as the label when `tryFromName` returns `null`.

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
| `type` (referenceToText) | Reference shown | User types the verse text |
| `type` (textToReference) | Verse text shown | User types the reference |
| `fillBlank` | Verse text with words masked | User types or selects missing words |

### Scoring Algorithm
**Typed and fill-in-blank responses** use word-level Longest Common Subsequence (LCS), implemented in `scoring.dart` on top of the same word-level diff that renders the answer feedback (#162):

```
score = lcs_length(typed_words, correct_words) / max(len(typed_words), len(correct_words))
```

- `normalizeWords(String) -> List<String>` (public, top-level) lowercases, strips all punctuation via `RegExp(r'[^\w\s]')`, collapses whitespace, and tokenizes. Punctuation is removed rather than replaced with a space, so a contraction stays one token: apostrophes are stripped, so "don't", "dont", and curly "don't" all compare equal (#161). Fill-blank's inline blank comparison in `test_session_screen.dart` calls this same shared function, so both modes forgive apostrophes identically.
- `diffWords(String typed, String correct) -> List<DiffToken>` aligns the two on normalized text (via the LCS table) but backtracks and emits `DiffToken`s **in source order**, each carrying the *original* word (source casing/punctuation for `match`/`delete`, the user's own for `insert`) and a `DiffOp` (`match`/`delete`/`insert`). `delete` = a source word the answer missed; `insert` = a word the answer added but the source doesn't contain.
- `computeScore` is implemented on top of `diffWords` (match count / `max(typedLen, correctLen)`), so the rendered diff can never contradict the percentage shown beside it.
- Denominator is `max(typed length, correct length)` — penalises both omissions and extra words equally.
- Result is clamped to 0–100%.

**Type-mode answer diff (#162)**: after `_onTypeCheck` scores the answer, `_lastTypeDiff` holds the `diffWords` result and is rendered by the private `_AnswerDiff` widget below the score. Match words render in `onSurface`; deleted (missed) words render in `cs.error` with a strikethrough; inserted (extra) words render in `cs.onSurfaceVariant` with a wavy underline. Every non-match token also carries a `Semantics` label ("Missing word: X" / "Extra word: X", `excludeSemantics: true`) so nothing is conveyed by colour alone, and a text legend ("N missed (struck through) · N extra (underlined)") renders only when there's something to decode — a perfect answer shows no legend. Theme tokens only, no raw hex.

**Session total** = arithmetic mean of all card scores.

### Lenient Book-Name Matching (textToRef answers)
When the prompt direction is `textToReference` (user types the reference), `test_session_screen.dart`'s `_scoreAnswer()` calls `computeReferenceScore` instead of plain `computeScore`. It splits both the typed/spoken answer and the correct reference into book-name span + chapter:verse span (regex `^(.+?)\s+(\d+:\d+(?:-\d+)?)\s*$`), resolves each book name to a USFM code via `bookNameToUsfm` (built-in table plus any custom variants), and — if both resolve to the **same** book — rewrites the typed book name to match the correct wording before running the usual word-level LCS. So "1 Pt 5:7", "First Peter 5:7", and "The First Letter of Peter 5:7" (if added as a custom variant) all score identically to whatever wording the stored verse reference uses. If either book name is unrecognized, or the two resolve to different books, it falls straight through to plain `computeScore` (no silent pass for wrong-book answers). `fillBlank` and `refToText` directions are untouched — book names there aren't a "type the reference" target, so the issue (#30) scoped lenient matching to `textToRef` only.

Custom variants are loaded once per session in `initState` via `_loadCustomVariants()` → `DatabaseHelper.getCustomVariantLookup()`, which merges all stored rows into a normalized-key → USFM-code map layered on top of the built-in table (built-in never mutated).

### Natural Separator/Range Normalization (typed references)
Before `computeReferenceScore` splits a typed reference into book-name + chapter:verse spans, `_normalizeReferenceInput()` (`lib/utils/scoring.dart`) rewrites common natural-language separator and range variants into the canonical `Chapter:Verse` / `Verse-Verse` form, so e.g. "Phil 4.13", "Phil 4 13", and "Phil 4 colon 13" all score identically to "Phil 4:13", and "John 3:16 to/through/and 17" scores identically to "John 3:16-17". Rewrite order is significant — word-based connectors (`colon`, `dot`, `dash`, `to`/`through`, `and`) are resolved before the bare two-number-with-space rule, otherwise a range like "16 to 17" would become "16:to 17" before "to" is replaced. This only runs on the *typed* side; the stored `correct` reference is assumed already canonical.

### Custom Book-Name Variants (Settings)
`lib/screens/settings/book_variants_screen.dart`, linked from Settings → Data ("Book Name Variants"), lets the user add/remove their own variant spellings per book (e.g. a personal abbreviation). Add flow: book `DropdownButtonFormField` (from `bookDisplayNames`) + free-text `TextFormField` (capped at `maxVariantLength` = 60 chars), inline `errorText` validation, focus returned to the offending field on error. List view shows existing variants with an accessible (48x48, `Semantics`-labeled) delete button per row. Stored variants are capped at `maxCustomVariants` = 200 total (data minimization) and validated server-side (in `DatabaseHelper.addBookNameVariant`) for unknown book code, empty/over-length text, and duplicate (book, variant) pairs — the count-check-then-insert runs inside one `db.transaction` to avoid a race past the cap.

The Add-variant dialog guards against double-tap submission with an `isSubmitting` flag (#103): while true, the Book dropdown and variant text field are disabled, the Add button shows a spinner, and `PopScope(canPop: !isSubmitting)` blocks dismissing the dialog mid-submit — mirroring the async-button pattern already used in `add_verse_screen.dart`. Rapid double-taps on Add previously fired two concurrent `addBookNameVariant` calls, one of which could hit a disposed `FocusNode`/`TextEditingController` when the dialog closed early. The fix also defers disposal of the dialog's `FocusNode`s/controller by one frame (`WidgetsBinding.instance.addPostFrameCallback`), since the dialog route's exit transition still renders the about-to-be-removed content for one more frame after `showDialog`'s future resolves.

### Fill-in-Blank Word Selection
Blank count and positions are now percentage-driven and randomized, replacing the old fixed 3→4→5 step cycle (#98/#99).

`test_enums.dart` defines `BlankDensity` (twenty/thirty/fifty/seventyFive/random), each with a `.label` ("20%" etc.) and `.percentage` getter; `random` has no single percentage and instead re-rolls one of `BlankDensityLabel.fixedPercentages` ([20, 30, 50, 75]) independently per verse. `test_screen.dart` shows a single-select `ChoiceChip` row for density (unlike the multi-select `FilterChip` rows for Format/Direction), visible only when Fill Blank format is selected, default 20%, in a live region so screen readers announce its appearance/disappearance. `TestSessionScreen` takes a `blankDensity` param (default `BlankDensity.twenty`).

For each verse, `blankCountForPercentage(candidateWordCount, percentage)` in `lib/utils/scoring.dart` computes `round(percentage / 100 * candidateWordCount)`, floored at 1 (for 20%) or 2 (for 30/50/75%) so at least one blank always appears. `blankIndices(words, count, {Random? random})` then randomly selects `count` distinct non-`':'` candidate positions (falls back to all candidates if `count` exceeds availability), sorted ascending to preserve word order. `random` is injectable for deterministic tests; `TestSessionScreen` keeps one instance-level `Random` for its whole session and re-rolls the percentage (not the RNG) per verse when density is `random`.

### Type Mode: Explicit Advance (#166)
Checking a Type-mode answer no longer auto-advances to the next card after a delay. `_onTypeCheck` scores the answer, clears the input, and shows the score + diff — the session stays on that card indefinitely. A **Next** `FilledButton` (key `type-next-button`, 48dp) appears once the result is showing and receives focus automatically (`_nextFocusNode`) so a keyboard/screen-reader user lands on the forward action. Tapping it calls `_onTypeNext`, which is guarded by `if (!_showingTypeResult || _lastTypeScore == null) return;` so a double-tap can only record the card once.

### Privacy
Typed test input is held only in ephemeral widget state (`_typeController`/blank controllers). It is cleared immediately (`_typeController.clear()`) once the scoring function runs, and the resulting `diffWords` alignment (`_lastTypeDiff`) is held in memory only for on-screen rendering — none of it is written to the database or logs. See `meta/PRIVACY.md` for the full data-handling statement.

### History
Each completed session is stored with: timestamp, mode, list of (reference, score) pairs, and total score. The Settings screen exposes a "Clear History" action. The home screen shows recent memorized verses as chips. Results screen (`test_result_screen.dart`) and Test History screen (`lib/screens/settings/test_history_screen.dart`) both display the verse's stored `reference` field (via `DatabaseHelper.getVerseById`, resolved for all rows up front with a single `Future.wait` rather than per-row `FutureBuilder`s) instead of deriving it from the id via `formatVerseReference` — `formatVerseReference`'s slug parser only recognizes bundled-pack book abbreviations, so it silently fell back to the raw id for custom-added verses (whose ids embed the full book name, e.g. `esv_romans_2_2`). If a result's verse has since been deleted, both screens show the raw id suffixed with "(verse deleted)" in italics rather than a bare, ambiguous-looking slug.

### ESV Attribution
`test_session_screen.dart` renders `EsvCopyrightFooter(hasEsvContent: _currentVerse.translation == 'ESV')` below the answer area. See `docs/features/esv-attribution.md` for the shared widget's behavior.

### Accessibility
Fill-blank feedback in `test_session_screen.dart` uses `TextField` `errorText`/`helperText` (not just color/icon) so screen readers announce "Incorrect — correct: <word>" or "Correct".

### Format Chip UI
`test_screen.dart` format-selection `FilterChip`s use a private `_FormatChip` widget that puts the format icon inside the label `Row` rather than the `avatar` slot, avoiding overlap with the Material selection checkmark.

## Changelog
| Date | Change |
|---|---|
| 2026-07-15 | Recite mode removed entirely (#165) — unreliable on-device recognition in practice, Type mode plus keyboard dictation covers the need; deleted `speech_recognition_service.dart`, its test, the `speech_to_text`/`permission_handler` deps, and `RECORD_AUDIO`; `TestFormatLabel.tryFromName` intentionally returns `null` for `"recite"` so old history rows still display via raw-string fallback. Apostrophes now stripped in scoring normalization (#161): `[^\w\s']` → `[^\w\s]`, extracted to public `normalizeWords`, so "don't"/"dont"/"don't" compare equal in both Type and Fill Blank. Word-level diff now surfaced instead of discarded (#162): new `DiffOp`/`DiffToken`/`diffWords` in `scoring.dart`, rendered by `_AnswerDiff` (strikethrough+error for missed words, wavy-underline+onSurfaceVariant for extra words, `Semantics` labels, text legend); `computeScore` is now implemented on top of `diffWords` so score and diff can never disagree. Type mode no longer auto-advances (#166): checking reveals score+diff and waits for a new focused **Next** button (`type-next-button`), double-tap-safe. |
| 2026-07-07 | Hardened recite-aloud speech handling (#143, #144, #152, #154, #157): added widget-test coverage for transient mic-permission `denied` (announcement only, no Settings dialog — that's `permanentlyDenied`-only) and `listen()` returning `false` (unavailable announcement, listening state reset), via new test fakes `_TransientlyDeniedSpeechService` and `_FakeSpeechService.listenReturnsFalse`; added a shorter `_postStopTimeoutDuration` (4s) for the explicit-stop path so tapping stop while the plugin is unresponsive resolves the "Listening…" UI within ~4s instead of the full 15s start-side `_micTimeoutDuration` wedge-detection window; documented the `pauseFor: 15s` rationale in `speech_recognition_service.dart`; swapped remaining default `Icons.*` usages in `test_session_screen.dart` for Material Symbols Rounded equivalents (no behavior change) |
| 2026-07-06 | Fixed inconsistent verse-reference display on Test Summary and Test History (#137): both screens now resolve each result's verse via `DatabaseHelper.getVerseById` (batched with `Future.wait`, not per-row `FutureBuilder`s) and show its stored `reference` instead of re-deriving one from the id via `formatVerseReference`, which only recognized bundled-pack abbreviations and silently returned the raw id for custom-added verses; deleted verses show "id (verse deleted)" in italics; also fixed Test History's format label to use the shared `TestFormatLabel.tryFromName` helper (was checking snake_case `fill_blank` against the camelCase `fillBlank` stored value, so it never matched) |
| 2026-07-06 | Fixed recite-aloud speech issues (#134/#135/#136): `pauseFor: 15s` tolerates mid-verse silence before auto-stopping; manual mic-stop no longer clears listening state early (was discarding the async final transcript, showing no score) and gained a discoverability `Tooltip`; recite score reveal now shows "Try Again"/"Continue" (mirroring fill-blank) with `_onReciteRetry()`, and self-rate buttons are hidden once a score is shown; recognized transcript displayed as "Heard: ..." above the buttons, in-memory only, never persisted |
| 2026-07-02 | Fixed double-tap crash in Book Name Variants Add dialog (#103): `isSubmitting` guard disables inputs/Add button and shows a spinner; `PopScope` blocks dismiss mid-submit; dialog `FocusNode`/controller disposal deferred by a frame |
| 2026-06-30 | Fill-blank difficulty now percentage-based and randomized (#98/#99): `blankIndices` reworked to take an explicit `count` and pick random distinct positions (was fixed 3→4→5 step cycle); new `blankCountForPercentage`; new `BlankDensity` enum + `ChoiceChip` density picker in `test_screen.dart`; `TestSessionScreen` re-rolls percentage per verse for the "random" density option |
| 2026-06-26 | Normalized natural separator/range variants in typed references before scoring (#43, #44): `_normalizeReferenceInput()` handles "colon"/"dot"/"dash" words, "to"/"through"/"and" ranges, bare-dot, and bare-space chapter:verse forms |
| 2026-06-25 | Retrofitted Review mode (#49) with a user-chosen count slider/chips + verse-of-week toggle, replacing the hardcoded 5-verse selection; wired into `getRandomMemorizedVerses(count, includeVerseOfWeek)` (#46/#53) |
| 2026-06-24 | Added lenient book-name matching for `textToRef` answers (#30): `computeReferenceScore` in `scoring.dart` canonicalizes the typed book-name span before LCS scoring; new shared `lib/utils/book_name_variants.dart` table (built-in variants + longhand/spoken-number forms), `book_name_variants` DB table (v2→v3) for user-added variants with CRUD + caps, new Settings screen `book_variants_screen.dart` |
| 2026-05-27 | Initial documentation |
| 2026-05-27 | Updated with full implementation: enum types, word-level LCS scoring algorithm, fill-blank word selection pattern, setup/session/results screen structure, privacy decision on typed input |
| 2026-05-27 | Corrected enum identifiers, file paths, fill-blank algorithm description, recite scoring values; extracted scoring logic to lib/utils/scoring.dart; added unit tests |
| 2026-06-24 | Added opt-in mic button for recite mode: on-device speech-to-text via `speech_to_text` (`SpeechRecognitionService`), scored with existing LCS `computeScore`, transcript never persisted; RECORD_AUDIO requested at point-of-use; typed/self-rated recite remains the default path |
| 2026-06-23 | Fixed #21/#23/#24/#25: added `TestFormat.label`/`tryFromName` shared label helper (fixed fillBlank/fill_blank mismatch bug), added `verse_reference_format.dart` for slug-to-display formatting on results screen, a11y errorText/helperText for fill-blank feedback, fixed icon/checkmark overlap in format chips via `_FormatChip` |
