# Test Modes

## Summary
The test feature helps the user confirm memorization through active recall. Two modes (verse-of-week and review) cover both current learning and long-term retention, with multiple prompt/response formats and per-verse accuracy scoring.

## Users / Use Cases
- **Solo user**: runs verse-of-week tests to confirm the current verse is locked in; runs review tests to check retention of previously memorized verses.

## Technologies
- sqflite — stores test session history and per-verse scores
- Flutter UI — interactive card-based test flow

## Technical Overview
A test session is a sequence of verse cards. Each card presents a prompt and accepts a response. After all cards are answered, the session scores each card and displays an aggregate. Sessions and scores are persisted so the user can review history.

## Key Files
| File | Purpose |
|---|---|
| `lib/features/test_modes/` | Test session flow, card widgets, results screen |
| `lib/models/test_session.dart` | Session domain model (mode, cards, scores) |
| `lib/data/test_dao.dart` | Persist and retrieve test history |

## Technical Detail

### Modes

| Mode | Verses Tested |
|---|---|
| Verse of the Week | The single current verse only |
| Review | 5 verses chosen at random from the memorized list |

### Prompt / Response Formats

| Format | Prompt | User Action |
|---|---|---|
| Recite by reference | Reference shown | User speaks/recites the text |
| Recite by text | Verse text shown | User speaks/recites the reference |
| Type by reference | Reference shown | User types the verse text |
| Type by text | Verse text shown | User types the reference |
| Fill in the blank | Verse text with words masked | User types or selects missing words |

All formats except fill-in-blank support both prompt directions (reference -> text and text -> reference).

### Scoring
- Each verse card receives an accuracy score (0–100%).
- Typed/fill-in-blank responses: scored by string similarity against the correct answer (case-insensitive, punctuation-tolerant).
- Recite responses: user self-rates accuracy after seeing the correct answer (binary or 0/25/50/75/100 scale — TBD during implementation).
- Session total score = average of all card scores.

### History
Each completed session is stored with: timestamp, mode, list of (reference, score) pairs, and total score. The home screen shows the most recent session score per mode.

## Changelog
| Date | Change |
|---|---|
| 2026-05-27 | Initial documentation |
