# Plan: Repurpose Audio Interrupt Probability to Verse-of-Week Probability

**Issues:** #42

---

## Goal

The audio interrupt probability slider controls how often the verse-of-week is chosen versus a random memorized verse, rather than whether an interrupt fires at all.

---

## Context

The existing interrupt probability slider controls how often an audio interruption fires at all (probabilistic gate in `_checkThreshold`). Users want the slider to instead control how often the verse-of-week is chosen vs. a random memorized verse. Interrupts should always fire once the time threshold is crossed; the probability becomes a verse-selection weight.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/services/audio_interrupt_service.dart` | Remove probabilistic gate; repurpose probability in `_pickVerse` |
| `lib/screens/settings/settings_screen.dart` | Rename label, subtitle, and dialog title (3 string constants) |
| `lib/models/settings.dart` | Add `.clamp(0.0, 1.0)` in `fromMap` |
| `docs/features/audio.md` | Update settings table row |

### Steps

1. **`lib/models/settings.dart` — add clamp** in `fromMap` at the `audioInterruptProbability` key:
   ```dart
   audioInterruptProbability: ((map['audio_interrupt_probability'] as num?)
       ?.toDouble() ?? 0.5).clamp(0.0, 1.0),
   ```

2. **`lib/services/audio_interrupt_service.dart` — remove probabilistic gate.**
   In `_checkThreshold()`, delete lines 92–96:
   ```dart
   // DELETE THIS BLOCK:
   if (_rng.nextDouble() >= _interruptProbability) {
     _resetAccumulator();
     return;
   }
   ```

3. **`lib/services/audio_interrupt_service.dart` — repurpose probability in `_pickVerse()`.**
   Replace line 117:
   ```dart
   // Before:
   if (vow != null && _rng.nextBool()) return vow;
   // After:
   if (vow != null && _rng.nextDouble() < _interruptProbability) return vow;
   ```

4. **`lib/screens/settings/settings_screen.dart` — rename 3 strings:**
   - Line 63: `'Interrupt probability'` → `'Verse-of-week probability'`
   - Line 64: `'How often to interrupt with a verse'` → `'How often the verse of the week is chosen vs. a random memorized verse'`
   - Line 317 (dialog title): `'Interrupt probability'` → `'Verse-of-week probability'`

5. **`docs/features/audio.md`** — update the settings table row from "Interrupt probability slider (10%–90%, default 50%)" to "Verse-of-week probability slider (10%–90%, default 50%) — controls how often the verse of the week is selected during interrupts".

6. **Add tests** for `_pickVerse` probability behavior (none exist currently):
   - With `_interruptProbability = 1.0`: 100 calls → verse-of-week always returned (when present)
   - With `_interruptProbability = 0.0`: 100 calls → verse-of-week never returned, random memorized verse returned
   - With `_interruptProbability = 0.5`: statistical check that both verse-of-week and random verses are returned across 100 calls

---

## Acceptance Criteria

- [ ] `flutter test` passes including new `_pickVerse` probability tests
- [ ] Settings → Audio slider label reads "Verse-of-week probability"
- [ ] Dialog title also reads "Verse-of-week probability" when slider is tapped
- [ ] Audio interrupt always fires once the time threshold is crossed (probabilistic gate removed)
- [ ] Probability at 100% → verse-of-week consistently selected during interrupts
- [ ] Probability at 0% → random memorized verse consistently selected during interrupts

---

## Pre-Implementation Review

**Medium — Add `.clamp(0.0, 1.0)` to `AppSettings.fromMap`** (Step 1 above). SharedPreferences is unencrypted on Android; a tampered value > 1.0 or < 0.0 would make verse-of-week always or never selected. The `last_backup_at` guard in `settings.dart` (lines 104–113) already establishes this tamper-guard pattern in the codebase — follow it.

**Informational — Live service doesn't pick up probability changes mid-session.** `startTracking()` snapshots `_interruptProbability` at call time. Slider changes only take effect after audio is restarted. This is existing behavior and acceptable; no action needed.

**Informational — Behavior regression for users with probability = 0.** Previously, probability = 0 was a soft-disable path (interrupt never fired). After this change, interrupts always fire and verse-of-week is just never picked. Consider adding a note to the settings UI that the interrupt threshold toggle is the correct way to disable interrupts.
