# Plan: Close test coverage gaps from the ESV-integration branch

**Issues:** #91, #92, #93, #94, #95, #96

---

## Goal

Add missing test coverage for the ESV-cap enforcement, Add Verse's ESV UI wiring, AudioInterruptService's stateful behavior, VerseProvider's auto-advance side effects, scoring's reference normalization, and a handful of smaller untested branches — all flagged by SDLC review with zero or partial coverage.

---

## Context

The ESV-integration branch introduced several pieces of non-trivial logic (cap enforcement with a TOCTOU-safe transaction, a consent/lookup UI flow, audio interrupt scheduling, auto-advance side effects, reference-normalization rule ordering) where only pure/simple branches were tested, leaving the riskiest paths (race conditions, async side effects, UI flows) unverified. None of these require behavior changes — only new tests — so they're bundled into one test-only cluster.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `test/database/database_helper_test.dart` (new) | Cap-under, cap-exceeded-throws, and concurrent race tests for `insertEsvVerse` (#91) |
| `test/screens/verses/add_verse_screen_test.dart` | Widget tests for cap-blocked lookup, consent accept/decline, lookup success/failure rendering, cap-warning clearing (#92) |
| `test/services/audio_interrupt_service_test.dart` | Instance-level start/pause/resume/threshold-trigger tests; `pickVerseForInterrupt` null/empty branch tests (#93) |
| `test/providers/verse_provider_test.dart` | Test for public `autoAdvanceVerseOfWeekIfNeeded` asserting `setVerseOfWeek`/`onUpdate` invocation (#94) |
| `test/utils/scoring_test.dart` | Compound/colliding reference-normalization regression tests; empty-input boundary test (#95) |
| `test/screens/settings/settings_screen_test.dart`, `test/widgets/esv_copyright_footer_test.dart`, `test/models/settings_test.dart` | Smaller listed branch/boundary tests (#96) |

### Steps

1. **#91:** Create `test/database/database_helper_test.dart` (if it doesn't exist) covering: insert succeeds under the 500-verse cap; insert at/over the cap throws the expected exception; a concurrent `Future.wait` pair of inserts near the cap boundary still respects the cap (exercises the transaction's TOCTOU guard).
2. **#92:** Add widget tests to Add Verse's test file for: cap-blocked lookup (attempting lookup when at cap), consent dialog accept path, consent dialog decline path, ESV lookup success rendering, ESV lookup failure rendering, and `_capWarning` clearing when switching translation away from ESV.
3. **#93:** Add instance-level tests for `AudioInterruptService` covering `startTracking`, pause, resume, and threshold-crossing triggering `_triggerInterrupt`. Add two missing branch tests for the pure helper `pickVerseForInterrupt`: `verseOfWeek == null` and `memorizedVerses.isEmpty`.
4. **#94:** Add a test that calls `VerseProvider.autoAdvanceVerseOfWeekIfNeeded` directly (not just `pickVerseForAutoAdvance`) and asserts `setVerseOfWeek` is called with the expected verse and that the `onUpdate` callback fires.
5. **#95:** Add regression tests to `scoring_test.dart` for compound/colliding reference inputs (e.g. "John 3 16 and 17", "Phil 4 13 to 14") through `_normalizeReferenceInput`/`computeReferenceScore`, plus an empty/whitespace-only input boundary test.
6. **#96:** Add the remaining listed small tests: Settings auto-advance toggle-off, Settings "ESV.org" `launchUrl` tap, `EsvCopyrightFooter` reduced-motion branch, `EsvCopyrightFooter` Settings-navigation tap, `AppSettings.copyWith(clearLastVerseAdvanceDate: true)`, and the just-inside-365-day boundary case.

---

## Acceptance Criteria

- [ ] All listed test cases across #91-#96 are added and passing
- [ ] No production code behavior changes as a result of this cluster
- [ ] `flutter test` passes with the new tests included
- [ ] Line/branch coverage for the affected files (database_helper.dart, add_verse_screen.dart, audio_interrupt_service.dart, verse_provider.dart, scoring.dart) measurably increases
