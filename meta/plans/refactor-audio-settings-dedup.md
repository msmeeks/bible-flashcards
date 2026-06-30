# Plan: De-duplicate audio phase-resume and settings timestamp validation

**Issues:** #75, #78

---

## Goal

Remove two pre-existing code-duplication patterns (audio playback phase sequencing, settings timestamp validation) that the ESV-integration branch widened.

---

## Context

Both findings are straightforward DRY cleanups with no behavior change intended. `audio_service.dart` re-implements the same reference→pause→text sequence in `playVerse` and twice inside `resume` (#75). `settings.dart` repeats an identical far-future-timestamp guard for `lastBackupAt` and `lastVerseAdvanceDate` (#78). Neither touches UI or public API surface.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/services/audio_service.dart` | Extract `_runFromPhase(_PlayPhase startPhase, Verse verse)`; have `playVerse` and `resume` call it |
| `lib/models/settings.dart` | Extract `DateTime? _parseGuardedTimestamp(String? raw)`; use for both `lastBackupAt` and `lastVerseAdvanceDate` |

### Steps

1. In `audio_service.dart`, identify the shared reference→pause→text sequence across `playVerse` (current lines ~77-105) and the `reference`/`pause` cases of `resume` (~127-174). Extract a private `_runFromPhase(_PlayPhase startPhase, Verse verse)` that both call into, parameterized by starting phase.
2. Verify ESV-audio integration points (cache lookup, playback source selection) are threaded through the new shared method identically to how each call site currently does it — no double-fetching or skipped phases.
3. In `settings.dart`, extract the repeated far-future-timestamp guard (currently duplicated for `lastBackupAt` at lines ~118-127 and `lastVerseAdvanceDate` at ~129-138) into `DateTime? _parseGuardedTimestamp(String? raw)`. Use it for both fields.
4. Run the existing audio and settings test suites to confirm behavior is unchanged.

---

## Acceptance Criteria

- [ ] `playVerse` and `resume` share one phase-sequencing code path with no duplicated reference→pause→text logic
- [ ] One helper implements the far-future-timestamp guard, used by both `lastBackupAt` and `lastVerseAdvanceDate`
- [ ] Existing audio playback/resume tests pass unchanged
- [ ] Existing settings parsing tests (including the 400-day-rejection case) pass unchanged
