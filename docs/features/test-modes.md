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
| `lib/utils/scoring.dart` | `computeScore` (LCS) and `blankIndices` functions |
| `lib/services/speech_recognition_service.dart` | On-device speech-to-text wrapper for recite mode (mic permission, listen/stop/cancel) |

## Technical Detail

### Enums

```dart
enum TestMode { verseOfWeek, review }
enum TestFormat { recite, type, fillBlank }
enum PromptDirection { refToText, textToRef }
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

**Recite responses**: default path is self-rating — user sees the correct answer and rates "I knew it" (1.0) or "Didn't know" (0.0). An opt-in mic button (`_buildReciteArea`/`_onMicPressed` in `test_session_screen.dart`) lets the user instead speak the verse; `SpeechRecognitionService` runs on-device speech-to-text (package `speech_to_text`, `onDevice: true`, no cloud fallback — listen fails outright if on-device recognition isn't available), and the final transcript is scored with the same `computeScore` LCS function used for typed input via `_onReciteTranscriptFinal`. RECORD_AUDIO permission is requested at point-of-use (when the mic button is pressed), not pre-granted at app launch.

**Session total** = arithmetic mean of all card scores.

### Fill-in-Blank Word Selection
Words to mask are selected by `blankIndices()` in `lib/utils/scoring.dart`. The step cycles 3→4→5→3→… using `step = 3 + (blankCount % 3)` after each blank is placed, starting with the word at index 2. There is no difficulty setting and no short-word skipping.

### Privacy
Typed test input is held only in ephemeral widget state. It is discarded immediately after the scoring function runs and is never written to the database or logs. Voice transcripts from the recite-mode mic option follow the same rule — held in memory only, discarded immediately after `computeScore` runs, never persisted or logged. See `meta/PRIVACY.md` ("Voice Recitation (Recite Mode)" section) for the full data-handling statement.

### History
Each completed session is stored with: timestamp, mode, list of (reference, score) pairs, and total score. The Settings screen exposes a "Clear History" action. The home screen shows recent memorized verses as chips.

## Changelog
| Date | Change |
|---|---|
| 2026-05-27 | Initial documentation |
| 2026-05-27 | Updated with full implementation: enum types, word-level LCS scoring algorithm, fill-blank word selection pattern, setup/session/results screen structure, privacy decision on typed input |
| 2026-05-27 | Corrected enum identifiers, file paths, fill-blank algorithm description, recite scoring values; extracted scoring logic to lib/utils/scoring.dart; added unit tests |
| 2026-06-24 | Added opt-in mic button for recite mode: on-device speech-to-text via `speech_to_text` (`SpeechRecognitionService`), scored with existing LCS `computeScore`, transcript never persisted; RECORD_AUDIO requested at point-of-use; typed/self-rated recite remains the default path |
