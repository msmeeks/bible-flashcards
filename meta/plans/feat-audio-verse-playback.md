# Plan: Audio — periodic memory-verse playback while other audio plays

**Issues:** #164

---

## Goal

Turn the one-shot audio-interrupt feature into periodic memory-verse playback on a user-set interval that, by default, inserts a verse only while another app is playing audio (e.g. an audiobook), ducking that audio and resuming it after.

---

## Context

Today the feature fires once after a fixed `audioInterruptAfterMinutes` (default 60) of cumulative tracked playback and picks a verse via the verse-of-week-weighted `selectInterruptVerse`. The user wants a recurring verse insert during long listening sessions. Android exposes `AudioManager.isMusicActive()` to detect other-app audio (no permission required), making a "only while other audio is playing" mode viable as the default.

**Design decisions locked during triage:**
- Verse selection unchanged — keep the VoW-weighted `selectInterruptVerse`; **keep `audioInterruptProbability`** (it is that selection weight, not a play/skip roll — a common misread).
- Request transient audio focus so other audio ducks/pauses, then release so it resumes.
- For the "while other audio playing" mode, sample `isMusicActive()` with a short debounce/retry at each interval mark; play if active, else skip to the next interval.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/models/settings.dart` | Keep `audioInterruptEnabled` + `audioInterruptProbability`; change `audioInterruptAfterMinutes` into a recurring interval ("every N minutes"); add a trigger-mode enum field (`whileOtherAudioPlaying` default \| `always`). Update `copyWith`, DB map read/write, and defaults/migration for existing rows. |
| `lib/services/audio_interrupt_service.dart` | Replace one-shot cumulative-threshold logic with a recurring interval scheduler that gates on trigger mode + debounced `isMusicActive`, requests audio focus, plays the selected verse via TTS, then releases focus. |
| `android/app/src/main/kotlin/.../MainActivity.kt` (+ new platform-channel handler) | Add a method channel exposing `AudioManager.isMusicActive()` and transient audio-focus request/release. |
| `lib/screens/settings/settings_screen.dart` | Interval control + trigger-mode selector, reusing existing settings widgets. |
| `docs/features/audio.md` | Document periodic playback, trigger modes, and audio focus. |

### Steps

1. **Settings model:** generalize `audioInterruptAfterMinutes` to a user-configurable interval; add trigger-mode enum (`whileOtherAudioPlaying` default, `always`). Keep `audioInterruptEnabled` and `audioInterruptProbability`. Provide `copyWith` + map serialization + a migration/default so existing rows load (`audioInterruptEnabled=false` still fully disables).
2. **Platform channel:** add a small Kotlin method channel — one method returning `audioManager.isMusicActive()` (boolean), plus request/abandon transient audio focus. Provide a testable Dart-side wrapper around the channel. No new runtime permission for `isMusicActive`.
3. **Service:** replace the cumulative one-shot with a recurring interval scheduler. On each fire: if mode is `whileOtherAudioPlaying`, sample `isMusicActive` with a short debounce/retry and skip the interval if inactive; if `always`, proceed unconditionally. Request transient audio focus, play the verse (selected via existing `selectInterruptVerse`, unchanged), then release focus so other audio resumes.
4. **Settings UI:** add an interval control and a trigger-mode selector, reusing existing settings row/chip components (design brief §7 — `FilterChip`/segmented selection; theme tokens only).
5. Keep the feature fully behind `audioInterruptEnabled`.

---

## Acceptance Criteria

- [ ] User can set the playback interval (N minutes) and it recurs, not one-shot.
- [ ] Trigger mode is user-selectable; default is `whileOtherAudioPlaying`.
- [ ] In `whileOtherAudioPlaying`, a verse plays only when other audio is active (debounced `isMusicActive`); the interval is skipped otherwise.
- [ ] In `always`, a verse plays each interval regardless of other audio.
- [ ] Playback requests transient audio focus and releases it so other-app audio ducks then resumes.
- [ ] Verse selection remains VoW-weighted via the existing selector; `audioInterruptProbability` still controls that weighting.
- [ ] Existing settings rows migrate to sensible defaults without crashing; `audioInterruptEnabled=false` fully disables the feature.
- [ ] Unit tests cover interval scheduling, trigger-mode gating (both modes), and debounce/skip; the platform channel has a testable Dart wrapper.

---

## Pre-Implementation Review

**Privacy (`meta/PRIVACY.md`):** verse selection is unchanged and local; the platform channel returns only a boolean (`isMusicActive`) and does not read what the other app is playing. No PII crosses the channel; data minimization satisfied.

**Security:** the new Kotlin method channel is the only new surface — keep it to the two methods (audio-active query, focus request/release), validate no arbitrary payload crosses, and do not expose it beyond the app. `isMusicActive` needs no permission.

**Design (`DESIGN_BRIEF.md`):** new settings controls must reuse existing settings row/selector patterns and theme tokens (no raw hex, brief §13); trigger-mode selection fits `FilterChip`/segmented per §7.

**Accessibility:** interval and trigger-mode controls need visible labels and `Semantics`; group preset chips with a `Semantics` group label per brief §7.
