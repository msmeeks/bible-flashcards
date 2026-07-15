# Plan: Notification & Audio Services — Test Seams, Branch Coverage, and Cleanup

**Issues:** #170, #171, #172, #185, #187, #188
**Prerequisite:** land `fix-settings-audio-ux.md` first — #185 reformats `test/screens/settings/settings_screen_test.dart`, which that plan rewrites.

---

## Goal

The service layer behind the daily reminder and periodic verse playback has deterministic coverage of its correctness-critical branches — timezone fallback, midnight rollover, action dispatch, mid-flight cancellation, and corrupted-preference recovery — none of which depend on when or where the suite runs.

---

## Context

The notifications (#163) and periodic-audio-playback (#164) work added scheduling, a platform channel, and a notification-action dispatcher, but the accompanying tests stopped at the happy paths. The gaps that matter are the ones guarding user-visible failure modes: `AudioInterruptService`'s two mid-flight guards are exactly what prevents "a verse played after I turned this off", and neither is exercised — removing either would not fail the suite. `AudioTriggerMode.fromName`'s `orElse` is the only thing between a corrupted `SharedPreferences` value and a `StateError` crash on settings load, and it's unasserted. Worse than uncovered, the daily-reminder midnight-rollover branch is *nondeterministically* covered: it reads the real wall clock, so whether it executes at all depends on what time of day CI happens to run, and the suite passes either way. Two small cleanups ride along in the same files: duplicated catch scaffolding in `SystemAudioService`, and four files carrying `dart format` drift.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/services/notification_service.dart` | Optional clock seam on the constructor; `@visibleForTesting` hook onto the action-dispatch path |
| `lib/services/system_audio_service.dart` | Extract the shared bool-returning `try`/`catch` into one private helper |
| `test/services/notification_service_test.dart` | Rollover both-sides tests, action-dispatch tests, `initialize()` + UTC-fallback tests, default notification body assertion |
| `test/services/audio_interrupt_service_test.dart` | Mid-flight `stopTracking()` tests using a non-zero debounce delay |
| `test/models/settings_test.dart` | `fromMap` fallback for garbage / unknown / null trigger-mode values |
| `test/android_manifest_test.dart` | Formatting only (#185) |
| `docs/features/notifications.md` | Note the clock seam and dispatch hook |

### Steps

1. **Clock seam + rollover coverage (#171).** Add an optional named clock parameter to the `NotificationService` constructor, defaulting to the real current time. It has an implicit default constructor today and only a handful of construction sites (`main.dart` plus tests), so this is backward-compatible with no call-site churn — and it mirrors `AudioInterruptService`, which already takes optional collaborators and timing params with real defaults. **The seam must yield a timezone-aware value consistent with the `tz.local` location the scheduling math uses**; a naive `DateTime` seam loses the zone and will produce wrong results at DST boundaries. Then add two tests against a pinned "now": requested time in the past → schedules tomorrow; in the future → schedules today. Assert the full scheduled date, not just the time. Reuse the existing `_FakeAndroidPlugin` in the suite, which already captures `zonedSchedule` calls. Do not change the rollover logic — it is correct, only untestable.

2. **Action dispatch (#170).** Expose a `@visibleForTesting` entry point on `NotificationService` that accepts a notification response and runs the *same* dispatch logic the plugin callback runs — delegate, don't duplicate the valid-action filter, or the test asserts a copy. This matches the established pattern (`AudioInterruptService`'s fire hook; `@visibleForTesting` seams across the providers and database helper) and is far cheaper than driving a fake platform through `initialize()` to reach one branch. Cover: each valid action id (`pause`/`stop`/`play`/`dismiss`) fires `onAction`; an unrecognized id does not; a null id does not; a valid action with no callback assigned does not throw. Keep the valid-action set private.

3. **Mid-flight cancellation (#172).** Construct `AudioInterruptService` with a **non-zero** `debounceDelay` so there is a window to cancel in — existing tests use `Duration.zero` and always run sampling to completion, which is why the guards are dead to the suite. Use `fake_async` or a `Completer`-gated fake audio probe to call `stopTracking()` between samples. Assert no verse was played and that the probe ran fewer times than `debounceSamples` (proving the loop short-circuited rather than finishing and being filtered later). Also cover the guard sitting between a completed sample and playback. Assert via the fakes' recorded calls, not private state. Must be deterministic — no real sleeps.

4. **Remaining coverage gaps (#188).**
   - Drive `initialize()` against the fake-platform pattern the suite already establishes (subclass the Android implementation, swap into the plugin's platform instance). Inject an unknown timezone name — this needs its own fake/override on the timezone plugin — and assert the fallback to `tz.UTC` rather than a throw; assert a valid name sets the matching location; assert both notification channels are created. No test may depend on the host's real timezone.
   - Assert the default (verse-of-week) notification body alongside the existing `reviewVerse` assertion.
   - Assert `AppSettings.fromMap` yields `whileOtherAudioPlaying` for garbage, unknown, and null persisted trigger-mode values — via the public deserialization path, since that's the route a corrupted preference actually takes.
   - If step 1's clock seam has landed, reuse it rather than adding a second.

5. **`SystemAudioService` cleanup (#187).** Extract the bool-returning channel calls into one private helper (`Future<bool> _invokeBool(String method)`) owning the invoke, the null-coalesce to false, and both catch clauses; `isMusicActive()` and `requestTransientFocus()` become one-line delegations. **Leave `abandonFocus` alone** — contrary to the report, it is not an identical third repetition: it returns void and its two catch clauses carry different explanatory comments that folding would discard. Public API and semantics unchanged; the fail-closed behavior (unreachable platform → "no other audio", "focus not granted") is load-bearing and must survive. Keep the fix proportionate — no general-purpose channel abstraction in a 51-line file.

6. **Formatting (#185) — do this last.** Run `dart format .` repo-wide rather than file-by-file, so the result is correct regardless of merge order against the settings plan. Whitespace only; no logic changes. If a format conflict arises against `fix-settings-audio-ux.md`, take both sides' logic and re-run the formatter — never hand-resolve.

---

## Acceptance Criteria

- [ ] "Now" is injectable into `NotificationService`, defaults to the real clock, and stays timezone-aware; existing construction sites are unchanged.
- [ ] Rollover is asserted on both sides against a pinned now, and neither test's outcome depends on the wall-clock time at which it runs.
- [ ] All four valid action ids fire `onAction`; unrecognized and null ids do not; no callback assigned does not throw; the filter is not duplicated in test code.
- [ ] Stopping tracking between debounce samples plays no verse and short-circuits the probe loop; the between-sample-and-playback guard is covered; tests use no real sleeps.
- [ ] `initialize()` falls back to UTC on an unknown timezone without throwing, sets a valid location correctly, and creates both channels.
- [ ] Both notification body branches are asserted.
- [ ] `AppSettings.fromMap` returns the default trigger mode for garbage, unknown, and null values.
- [ ] `SystemAudioService`'s bool paths share one helper; both exception types still yield false; `abandonFocus`'s comments survive; existing tests pass unmodified.
- [ ] `dart format --output=none --set-exit-if-changed .` exits zero; `flutter analyze` clean; `flutter test` passes.

---

## Pre-Implementation Review

No new `/sdlc` plan-review pass was dispatched — these issues are themselves the output of the completed seven-agent SDLC review of this iteration (`sdlc_review_completed_agents` in `prd.json`). Carried forward from triage-time verification:

- **Correctness (#171 — the sharpest risk here).** The rollover branch's coverage currently depends on CI's wall-clock time. This is not merely a gap: the suite reports green while silently exercising a different branch each run. The DST caveat on the seam is the part most likely to be got wrong — a naive `DateTime` seam will look correct and fail at zone boundaries.
- **Correctness (#187 — report inaccuracy, verified).** The finding claims three identical catch repetitions; there are two. `abandonFocus` differs in return type and comments. Following the report literally would delete useful comments and change a void method's shape.
- **Test integrity (#170).** The `@visibleForTesting` hook must delegate to the production dispatch path. A hook that re-implements the valid-action filter would pass while testing nothing.
- **Sequencing (#185).** Overlaps `fix-settings-audio-ux.md` on `test/screens/settings/settings_screen_test.dart`; hence the prerequisite and the format-last-and-repo-wide instruction.
- **Privacy / security.** No new data flows, no new permissions, no dependency changes. `SystemAudioService`'s fail-closed semantics are the privacy-relevant property and are pinned by an acceptance criterion.
