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
| `lib/features/test_modes/test_setup_screen.dart` | Mode, format, and direction pickers |
| `lib/features/test_modes/test_session_screen.dart` | Active card display, recite/type/fill-blank input |
| `lib/features/test_modes/test_results_screen.dart` | Per-card scores, session total, save to history |
| `lib/models/test_session.dart` | Session domain model (mode, cards, scores) |
| `lib/data/test_dao.dart` | Persist and retrieve test history |
| `lib/providers/test_provider.dart` | Active session state and scoring logic |

## Technical Detail

### Enums

```dart
enum TestMode { verseOfWeek, review }
enum TestFormat { recite, type, fillBlank }
enum PromptDirection { referenceToText, textToReference }
```

`fillBlank` ignores `PromptDirection` (always reference context → masked text).

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

**Recite responses**: user self-rates accuracy after seeing the correct answer. Rating options: 0 / 25 / 50 / 75 / 100.

**Session total** = arithmetic mean of all card scores.

### Fill-in-Blank Word Selection
Words to mask are selected by pattern: every Nth word is masked (N determined by difficulty setting, default every 5th word). Short function words (≤ 3 characters) are skipped and the next eligible word is masked instead, ensuring content words are always tested.

### Privacy
Typed test input is held only in ephemeral widget state. It is discarded immediately after the scoring function runs and is never written to the database or logs.

### History
Each completed session is stored with: timestamp, mode, list of (reference, score) pairs, and total score. The Settings screen exposes a "Clear History" action. The home screen shows recent memorized verses as chips.

## Changelog
| Date | Change |
|---|---|
| 2026-05-27 | Initial documentation |
| 2026-05-27 | Updated with full implementation: enum types, word-level LCS scoring algorithm, fill-blank word selection pattern, setup/session/results screen structure, privacy decision on typed input |
