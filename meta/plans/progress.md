# Progress Log

## 2026-06-26 — refactor-audio-interrupt-probability.md (#42)

Repurposed the audio interrupt probability slider so it controls how often the
verse-of-week is chosen vs. a random memorized verse, instead of gating
whether an interrupt fires at all. Interrupts now always fire once the time
threshold is crossed.

- `lib/services/audio_interrupt_service.dart`: removed the probabilistic gate
  in `_checkThreshold`; extracted verse selection into a top-level
  `@visibleForTesting` `pickVerseForInterrupt()` function so the weighting
  logic can be unit tested directly (the timer/threshold path relies on real
  `DateTime.now()`, which doesn't cooperate with `fakeAsync`).
- `lib/models/settings.dart`: clamp `audioInterruptProbability` to `[0.0, 1.0]`
  in `fromMap` as a tamper guard (SharedPreferences is unencrypted).
- `lib/screens/settings/settings_screen.dart`: renamed the slider label and
  dialog title to "Verse-of-week probability".
- `docs/features/audio.md`: updated settings table + changelog.
- Added `test/services/audio_interrupt_service_test.dart` (probability 0.0,
  1.0, 0.5 cases) and two clamp tests in `test/models/settings_test.dart`.

`flutter test` passes (283 passed; 1 pre-existing unrelated failure in
`test/widget_test.dart` — confirmed present before this change too).
