# Plan: Recite-aloud speech recognition improvements

**Issues:** #134, #135, #136

---

## Goal

Recite-aloud tests tolerate normal thinking pauses, let the user retry a verse without penalty, and show what the speech recognizer actually heard.

---

## Context

Three related gaps in the recite-aloud test flow, all localized to `lib/services/speech_recognition_service.dart` and `lib/screens/test/test_session_screen.dart`:

1. The recognizer stops listening after the plugin's short default silence window (~2-3s) rather than a configured pause length, unfairly truncating recitations when the user pauses to think (#134).
2. Recite-aloud only offers "Continue" after scoring — no "Try Again" like fill-in-the-blank already has (#135).
3. The recognized transcript is scored then thrown away, so users can't tell whether a low score was a recognizer miss or an actual memory gap (#136).

All three touch the same recite-aloud code path in the same session, so they're grouped into one plan to avoid repeated conflicting edits to `test_session_screen.dart`.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/services/speech_recognition_service.dart` | Add `pauseFor: Duration(seconds: 15)` (and consider `listenFor` cap) to the `SpeechListenOptions(...)` call in `listen()` (currently lines 64-68) |
| `lib/screens/test/test_session_screen.dart` | Add `_onReciteRetry()` + Try Again button (#135); add `_lastReciteTranscript` field, capture it in `_onReciteTranscriptFinal`, render it in the score-reveal area (#136) |

### Steps

1. **#134 — configurable pause length.** In `speech_recognition_service.dart`, set `pauseFor: const Duration(seconds: 15)` inside the existing `SpeechListenOptions(...)` in `listen()`, matching the app-level `_micTimeoutDuration` (15s, `test_session_screen.dart` line 86) for consistency. Do not touch `_micTimeoutDuration`/`_startMicTimeout` — that's an unrelated wedged-state watchdog and must keep working as-is.
   - The manual "stop listening" affordance already exists: `_onMicPressed` (lines 268-344) toggles `stopListening()` when `_isListening` is true. Verify tapping it while `pauseFor` is now longer still stops immediately and still triggers scoring (confirm the toggle branch calls the same finalization path as a natural pause-triggered stop — if today's manual stop is silent/doesn't submit for scoring, wire it to the same `_onReciteTranscriptFinal` completion path issue #134 asks for a "clearer, more discoverable" stop affordance, not just a functional one).

2. **#135 — Try Again button.** Add `_onReciteRetry()` mirroring `_onBlankRetry()` (lines 454-468): reset `_showingReciteScore = false`, `_lastReciteScore = null`, `_lastReciteTranscript = null` (see step 3), clear `_micAnnouncement`. Do not call `_recordAndAdvance` — retry must not record an attempt.
   - In `_buildReciteArea`'s score-reveal block (around lines 567-580), replace the single `FilledButton` "Continue" with a `Row` matching fill-blank's layout (lines 776-798): `OutlinedButton` "Try Again" (left) `onPressed: _onReciteRetry`, `FilledButton` "Continue" (right) `onPressed: () => _recordAndAdvance(_lastReciteScore!)`.
   - **Critical:** the "I knew it"/"Didn't know" self-rate `Row` (currently lines 615-647) renders unconditionally, outside the score-reveal `if` block — unlike fill-blank, which gates its "Check Answer" button on `if (!_showingBlankResult)` (line 801). Gate the self-rate row on `!_showingReciteScore` so it's hidden once a score is shown; otherwise four buttons (Try Again, Continue, I knew it, Didn't know) are simultaneously visible/tappable and "I knew it" would silently discard the just-scored transcript via a separate code path.
   - Add focus management matching fill-blank's pattern: a dedicated `_reciteRetryFocusNode` (mirroring `_retryFocusNode`) with `addPostFrameCallback` to shift focus to the Try Again button once the score reveal appears, per `meta/DESIGN_BRIEF.md`'s focus-after-submission guidance.

3. **#136 — show transcript.** Add `String? _lastReciteTranscript` field near `_lastReciteScore` (line 78). In `_onReciteTranscriptFinal` (lines 373-388), set `_lastReciteTranscript = transcript` inside the same `setState` block that sets `_lastReciteScore`. Clear it alongside `_lastReciteScore = null` in `_recordAndAdvance`'s reset (lines 241-243) and in `_onReciteRetry` (step 2).
   - Render as plain `Text(_lastReciteTranscript ?? '')` above/below the shared `_ScoreReveal` call inside the `if (_showingReciteScore && _lastReciteScore != null)` block — do not add a `transcript` param to the shared `_ScoreReveal` widget itself, since fill-blank/type modes don't use it; keep the text rendering local to `_buildReciteArea`.
   - No per-word/character highlighting — plain text only, per acceptance criteria. Per the existing "discard after scoring" privacy contract (`docs/features/test-modes.md`), keep `_lastReciteTranscript` in-memory only: never persist it to the DB or test-history record, and ensure it's cleared on advance/retry/dispose so it doesn't leak into the next verse's reveal.

---

## Acceptance Criteria

- [ ] Pausing mid-recitation for up to 15 seconds does not end listening or truncate the transcript.
- [ ] A visible "stop listening" action is available while listening, distinct from waiting for auto-stop.
- [ ] Ending recitation manually still allows self-rating, same as today.
- [ ] After a recite-aloud score is shown, both "Try Again" and "Continue" buttons are visible, styled/positioned like fill-in-the-blank's (`OutlinedButton` left, `FilledButton` right).
- [ ] "Try Again" resets recite state for the current verse without recording the discarded attempt.
- [ ] "Continue" behaves exactly as today.
- [ ] The recognized transcript is shown as plain text alongside the score for every recite-aloud attempt (high or low accuracy).
- [ ] Transcript is never persisted beyond the current score-reveal view.
