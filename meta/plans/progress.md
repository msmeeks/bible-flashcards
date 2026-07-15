# Iteration Progress

Append-only log of plan work on `integration/2026-07-14-test-modes` (PR #167).

---

## 2026-07-14 22:35 — `feat-audio-verse-playback.md` (#164) — done

Turned the audio interrupt into periodic memory-verse playback that, by default,
only inserts a verse while another app is playing audio, ducking it and letting
it resume.

**Chosen over the other two pending plans** because it carried the only real
architectural unknowns (first platform channel in the project, audio-focus
lifecycle, a persisted-settings migration); `feat-test-modes.md` is mostly UI
polish and `fix-notifications.md` is a small, well-understood fix.

What shipped:

- **New platform channel** `bible_flashcards/system_audio` — the project's first.
  Kotlin handler in `MainActivity.configureFlutterEngine` exposes
  `isMusicActive`, `requestTransientFocus` (AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK,
  `AudioFocusRequest` on API 26+ / legacy overload down to minSdk 24) and
  `abandonFocus`. No new Android permission. No method takes arguments, so
  nothing crossing the channel needs validating.
- **`SystemAudioService`** Dart wrapper. Fails closed — a PlatformException or
  MissingPluginException reports "no other audio" / "focus denied" rather than
  throwing, so an unreachable platform skips the interval instead of crashing or
  talking over the user.
- **Settings**: new `AudioTriggerMode` enum (`whileOtherAudioPlaying` default |
  `always`); `audioInterruptAfterMinutes` renamed to
  `audioInterruptIntervalMinutes`. Migration reads the legacy
  `audio_interrupt_after_minutes` pref key so existing installs keep their
  configured minutes. `audioInterruptEnabled` / `audioInterruptProbability`
  unchanged (probability is the verse-of-week *selection weight*, not a
  play/skip roll).
- **`AudioInterruptService`**: gates each interval on trigger mode, debounces
  `isMusicActive` (3 samples / 300ms, both injectable) so a gap between tracks
  doesn't skip, holds focus for the whole verse (`playVerse` resolves only after
  reference→pause→text) and releases it in a `finally`. Re-entrancy guard stops
  the 10s poll starting a second playback mid-verse. Focus denial ⇒ stay silent.
- **Settings UI**: "Play verses periodically" switch, interval picker
  (15/30/45/60/90), and a "When to play" ChoiceChip pair. Changing interval or
  mode restarts tracking, since the running timer captured the old values.

Corrections to the plan (code was source of truth):

- The plan said the old behavior "fires once after a fixed threshold". It did
  not — the old timer already re-armed after each crossing. The genuinely new
  work is the other-app audio gate, the trigger mode, and audio focus. Docs say
  so explicitly rather than claiming a one-shot→recurring conversion.
- The plan said settings are stored via a DB map; they are actually
  SharedPreferences. Migration was written against the real storage.

Incidental fix (pre-existing, unrelated to #164): the "Notification type"
`SegmentedButton` sat in a `ListTile` trailing slot and threw "Trailing widget
consumes the entire tile width" at a 375px viewport — a real defect on ~360dp
Android phones. Now full-width under the title. Found because the new 375px
layout test rendered the whole screen; confirmed pre-existing by reproducing it
on a clean tree.

Verification:

- 553 unit/widget tests pass; `flutter analyze` reports 0 errors/warnings
  (10 pre-existing deprecation infos).
- New `integration_test/system_audio_channel_test.dart` drives the **real**
  channel against the **real** AudioManager on-device
  (`flutter test integration_test/system_audio_channel_test.dart -d <device>`) —
  unit tests mock the channel, so this is the only thing proving the Kotlin side
  is registered and agrees on method names. `requestTransientFocus` returning
  true is the load-bearing assertion: the error path can only return false.
- Visual smoke on the Pixel 9 emulator: Settings renders correctly, new controls
  disabled while the feature is off.

Known issue, **not** caused by this work: `integration_test/app_smoke_test.dart`
fails at `home-choose-verse-button` ("Found 0 widgets"). Reproduced identically
on a clean tree at this commit's base. It taps `format-chip-recite`, so it likely
belongs with `feat-test-modes.md` (#165 removes Recite). Left for that plan.
