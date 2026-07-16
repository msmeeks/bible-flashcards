# Audio

## Summary
The audio feature lets the user hear verse recitations during other activities. It plays the reference, pauses for the user to mentally recite, then plays the text. A periodic-playback feature inserts one memorized verse on a user-set interval — by default only while another app's audio is already playing, ducking it and resuming after — reinforcing passive memorization. (The legacy continuous "Audio review" shuffled-loop mode was retired — see #48.)

## Users / Use Cases
- **Solo user**: listens to verse audio while doing other tasks; periodically hears one memorized verse inserted into (or alongside) whatever else they're listening to, as a spaced-repetition prompt.

## Technologies
- `flutter_tts` — text-to-speech synthesis for reference and verse text (no bundled audio assets required)
- `audioplayers` — local MP3 playback for real ESV recordings during the text phase
- `flutter_local_notifications` — persistent notification and lock-screen controls; both notifications use `VISIBILITY_PRIVATE`
- Android `AudioManager` (via `SystemAudioService`, a first-party `MethodChannel`) — detects other-app audio and requests/releases transient audio focus so it ducks rather than stops; the project's first platform channel
- Provider — `AudioProvider` exposes playback state to UI

## Technical Overview
Playback is driven by `AudioService`, a TTS state machine that sequences: speak reference → timed pause → speak text. For ESV verses, the text phase plays the real Crossway recording (fetched/cached by `EsvAudioCacheService`) instead of TTS; any cache or network failure falls back to TTS silently. `AudioInterruptService` runs a recurring interval scheduler: every user-configured interval (default 60 min) it optionally checks — via the `SystemAudioService` platform channel — whether another app is currently playing audio before inserting one verse, requesting transient audio focus so that app ducks and resumes afterward.

## Key Files
| File | Purpose |
|---|---|
| `lib/services/audio_service.dart` | TTS state machine: reference → pause → text |
| `lib/services/audio_interrupt_service.dart` | Recurring interval scheduler: trigger-mode gating, audio-focus bracket, verse selection |
| `lib/services/system_audio_service.dart` | Dart wrapper over the `bible_flashcards/system_audio` platform channel (other-app-audio detection, transient audio focus) |
| `android/app/src/main/kotlin/com/example/bible_flashcards/MainActivity.kt` | Kotlin channel handler: `isMusicActive`, `requestTransientFocus`, `abandonFocus` via `AudioManager` |
| `lib/services/notification_service.dart` | Notification construction and action handling (playback + interrupt notifications) |
| `lib/providers/audio_provider.dart` | Exposes playback state and controls to UI |
| `lib/screens/settings/settings_screen.dart` | Audio section: periodic-playback toggle, interval dialog, trigger-mode chips, probability dialog |
| `lib/services/esv_audio_cache_service.dart` | Fetches/caches Crossway ESV MP3 recordings; SSRF-guarded redirect, SHA-256 cache keys, 250-file cap |

## Technical Detail

### AudioService State Machine
States are an enum; transitions are driven by `flutter_tts` completion callbacks.

```
idle
  → speakingReference  (play() called)
      → pausing        (reference TTS completes; timer set for pause duration)
          → speakingText  (pause timer fires)
              → completed (text TTS completes)
                  → idle  (only on explicit stop())
```

Pause duration is calculated from the character count of the verse text (approximation: characters ÷ average TTS character rate). `pause()` and `resume()` are simulated by cancelling/restarting the TTS call at the current state rather than by a native pause API.

### AudioProvider — Completed State Behaviour
When the state machine reaches `completed`:
- `isPlaying` → false; `isCompleted` getter → true.
- `_currentVerse` is **kept non-null** so the player bar remains visible.
- Notification is dismissed automatically.
- `resume()` is guarded: it returns immediately when `isCompleted` is true, preventing a no-op TTS restart.
- `_currentVerse` is only nulled on `idle` (explicit `stop()`).

### AudioPlayerBar — Accessibility and Icon Fixes
- Icons use `material_symbols_icons` (`Symbols.*`) exclusively — legacy `Icons.*` references removed.
- Play/Pause button: `onPressed: null` and `Semantics(enabled: false)` when `isCompleted`; shows a dimmed state via `disabledBackgroundColor`/`disabledForegroundColor`.
- Disabled navigation buttons (prev, rewind, forward) carry explicit `Semantics(enabled: false, button: true)`.
- `Dismissible` wrapped in `Semantics` with a `CustomSemanticsAction(label: 'Dismiss player')` so screen readers can invoke stop.

### AudioInterruptService — Interval Scheduler
- Tracking is polled every 10 seconds internally (fixed, not user-configurable) via `Timer.periodic`, comparing accumulated tracked time (paused/resumed by `pauseTracking`/`resumeTracking`) against the user-set `interval` (`audioInterruptIntervalMinutes`).
- Once the interval elapses, the accumulator resets immediately — whether or not a verse ends up playing, the next interval is measured from that reset point, not from whenever playback finishes.
- A verse is then picked via the unchanged `pickVerseForInterrupt` (verse-of-week weighted by `audioInterruptProbability` — see Settings Model below).
- `triggerMode` gates whether it actually plays:
  - `whileOtherAudioPlaying` (default): samples `SystemAudioService.isMusicActive()` up to 3 times with a 300ms debounce between samples (both injectable in tests), returning true on the first positive so a momentary gap between tracks/chapters doesn't skip the interval. If still inactive after all samples, the interval is skipped — no verse, no focus request.
  - `always`: proceeds every interval without consulting `isMusicActive` at all.
- If proceeding, requests transient audio focus (`SystemAudioService.requestTransientFocus()`). A denial — something with a stronger claim holds focus, e.g. a phone call — means the interval is skipped silently. On grant: stops any current audio, shows the interrupt notification, awaits `AudioService.playVerse()` (which resolves only after the full reference→pause→text sequence), then abandons focus in a `finally` — so focus is held for the whole verse.
- A `_firing` re-entrancy guard stops the 10-second poll from starting a second playback if it ticks again mid-verse.
- **Two mid-flight cancellation guards** cover the user switching the feature off while an interval check is already in progress — sampling is asynchronous, so `stopTracking()` can land mid-check. Together they are what prevents "a verse played after I turned this off":
  - Inside the sampling loop (`_isOtherAudioActive`), checked after each sample: abandons the loop rather than waiting out the remaining debounce delays.
  - Between a completed sample and playback (`_checkInterval`): a positive sample and a `stopTracking()` can race, so the last word before `_playWithFocus` is a tracking check.
  - Both are covered in `audio_interrupt_service_test.dart`'s "mid-flight cancellation" group, which needs a **non-zero** `debounceDelay` to have a window to cancel in — the other groups use `Duration.zero`, which runs sampling to completion and leaves these guards unexercised. Cancellation is driven from inside the probe fake, so no timers or real sleeps are involved.
- Changing the interval or trigger mode in Settings calls `startTracking` again, since the running `Timer` closed over the previous values.
- Verse selection itself is unchanged by this feature, and recurrence is not new either — the prior threshold-based version already re-armed after each crossing. What's new here is the other-app-audio gate, the trigger mode, and the audio-focus bracket.

### System Audio Platform Channel
`SystemAudioService` (`lib/services/system_audio_service.dart`) wraps a new `bible_flashcards/system_audio` `MethodChannel` — the project's first platform channel — registered in `MainActivity.configureFlutterEngine` (Kotlin). Three no-argument methods:
- `isMusicActive()` → `AudioManager.isMusicActive`; whether another app is currently playing audio. No permission required.
- `requestTransientFocus()` → requests `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK` (via `AudioFocusRequest` on API 26+; the deprecated `requestAudioFocus` overload below that, since minSdk is 24) so other audio ducks rather than stops. Returns whether focus was granted.
- `abandonFocus()` → releases the held request so the other app returns to full volume.

All three fail closed on the Dart side: a `PlatformException` or `MissingPluginException` is swallowed and reported as `false` (or a completed future for `abandonFocus`), so an unreachable platform skips the interval rather than crashing or talking over the user.

The two bool-returning methods share a private `_invokeBool(method)` helper owning the invoke, the null-coalesce to false, and both catch clauses. `abandonFocus` deliberately stays separate: it returns void and its two catch clauses carry different explanatory comments, so folding it in would discard them to remove no real duplication.

Testing: `test/services/system_audio_service_test.dart` mocks the channel and covers all three methods plus their error paths. Because that only proves the Dart-side contract, `integration_test/system_audio_channel_test.dart` drives the real channel against the real `AudioManager` on a device to confirm the Kotlin side is registered and agrees on method names — run with `flutter test integration_test/system_audio_channel_test.dart -d <device>`.

### Settings Model — Interval, Trigger Mode & Migration
- `audioInterruptIntervalMinutes` (renamed from `audioInterruptAfterMinutes`) is a recurring "every N minutes" interval, not a one-shot threshold; UI presets are 15/30/45/60/90 min, default 60 (unchanged).
- `audioInterruptTriggerMode` (`AudioTriggerMode.whileOtherAudioPlaying` default \| `always`) has a tolerant `fromName` that falls back to the default on an unknown or null value.
- Migration: `AppSettings.fromMap` reads the new `audio_interrupt_interval_minutes` key, falling back to the legacy `audio_interrupt_after_minutes` key so existing installs keep their configured minutes; `SettingsProvider.load()` reads both keys and `_persist()` writes only the new ones (`audio_interrupt_interval_minutes`, `audio_interrupt_trigger_mode`). All settings — including this one — persist to `SharedPreferences`, not the encrypted SQLite verse database.
- `audioInterruptEnabled` and `audioInterruptProbability` are unchanged. **`audioInterruptProbability` is the verse-of-week selection weight** (how often the verse of the week is picked over a random memorized verse) — it is not a play/skip roll on whether a verse plays at all, a common misreading of the name.

### Notifications
Both notification types use `VISIBILITY_PRIVATE` so no verse text appears on the lock screen.

| Notification | Title | Body | Action |
|---|---|---|---|
| Review playback | "Bible Review" | "Playing verse" | Stop |
| Interrupt playback | "Bible Verse" | "Tap to hear your verse" | Dismiss |

"Dismiss" stops the interruption immediately and returns audio focus to the foreground app.

### ESV Audio Branch
- Only activates when `verse.translation == 'ESV'`; all other translations always use TTS for both phases.
- `EsvAudioCacheService.getAudioPath(reference)` resolves the MP3 via a **two-request pattern**: first request hits `api.esv.org` with the `Authorization: Token <key>` header and `followRedirects = false` to read the `Location` header; second request fetches the MP3 from the redirect target **without** the auth header, and only after validating the target host against an allowlist (`audio.esv.org`) — this prevents the API key from ever reaching a CDN host, even a compromised or misconfigured one. Both host checks now call the shared `assertAllowedHttpsHost` helper (`lib/services/net_security.dart`, see `docs/features/verse-management.md`); the service catches the resulting `StateError` and rethrows it as its own `EsvAudioException` so callers' existing catch clauses are unaffected.
- Cache filename is `sha256(reference.toLowerCase().trim())` — never the raw reference — ruling out path traversal.
- Cache is capped at 250 files (oldest evicted first); concurrent `getAudioPath` calls for the same reference share one in-flight fetch.
- Gated on the `esv_lookup_consent_v1` preference flag (shared with ESV text lookup) — no separate audio consent prompt, since saving an ESV verse already required consenting to send the same reference to Crossway.
- `AudioService._playMp3AndWait` plays via `audioplayers`' `DeviceFileSource`; `stop()`/`pause()` explicitly stop and resolve the in-flight player completer (unlike TTS, `AudioPlayer.stop()` does not fire a completion event), so `resume()` always restarts the current text phase from the beginning — same restart-from-beginning behavior as TTS resume.
- Any exception from `EsvAudioCacheService` (offline, fetch failure, consent not yet granted) is caught and falls back to TTS silently — no error state, no user-visible interruption.

### ESV Attribution
`AudioProvider.queue` (a read-only `List<Verse>` getter over the internal queue) lets `ReviewPlayScreen` render `EsvCopyrightFooter` when the queue contains an ESV verse, without exposing a mutable reference. See `docs/features/esv-attribution.md` for the shared footer widget.

### Permissions
- `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_MEDIA_PLAYBACK` for background TTS/audio.
- `POST_NOTIFICATIONS` (Android 13+) for the dismissible notification.
- `INTERNET` for ESV audio fetches (`api.esv.org`, `audio.esv.org`) — only used for ESV verses with consent already granted; no internet required otherwise. No microphone permission required for this feature.
- No permission required for the system-audio channel — `AudioManager.isMusicActive` and audio-focus request/abandon are both permission-free APIs.

### Privacy — Other-App Audio Detection
`meta/PRIVACY.md` ("Periodic Verse Playback") is the authority here; the short version:

- The `isMusicActive` signal is a boolean held in a local variable for one interval check, then discarded. Never persisted, logged, or transmitted. Nothing is captured or analyzed — it is a system state query, not a recording.
- **No first-enable notice is shown, deliberately.** The rationale (no permission, nothing persisted, nothing transmitted, boolean discarded immediately, feature opt-in) is recorded in `meta/PRIVACY.md` along with why the `engagement_notice_shown` and ESV-consent precedents don't extend to it. Don't add a consent dialog here without reading that section first.
- The "When to play" subtitle stands in for that notice, so it is load-bearing copy rather than decoration: it appears only in `whileOtherAudioPlaying` mode, since `always` never queries audio state. `test/android_manifest_test.dart` pins every manifest permission to a `meta/PRIVACY.md` row.

### Settings Exposed to User
- "Play verses periodically" toggle (on/off) — enabling requires a verse of the week to be set first
- "Play a verse every" — interval presets 15 / 30 / 45 / 60 / 90 min, default 60 min, recurring; disabled while the toggle is off
- "When to play" — trigger mode, "While other audio plays" (default) or "Anytime"; disabled while the toggle is off. In the default mode the subtitle discloses the detection mechanic ("Checks whether another app is playing audio, not what it is") — see Privacy above before changing this string
- Verse-of-week probability slider (10%–90%, default 50%) — the verse-of-week **selection weight**, not a play/skip roll on whether a verse plays at all
- Theme selector (light / dark / system)
- Test history list and "Clear History" action

### Audio Rows — Disabled State & Semantics
Both dependent rows are gated on the "Play verses periodically" master switch. `ListTile.enabled: false` only dims the row, which carries the state by **contrast alone** — unreliable for a low-vision user and entirely invisible to a screen reader. So the dependency is also stated in text and in the semantics tree:

- **Subtitle qualifier.** With the switch off, each row swaps its descriptive subtitle for the dependency: `Turn on "Play verses periodically" to choose an interval` / `... to choose when`.
- **Trigger-chip group** (key `trigger-mode-group`) passes `enabled: settings.audioInterruptEnabled` to the same `Semantics` node that carries its group label and `explicitChildNodes: true` (the latter required by Design Brief §7 for preset chip rows), so the group reports `hasEnabledState` + not-`isEnabled`.
- **Interval row** (key `interval-row`) and the sibling **verse-of-week probability row** (key `probability-row`) are each one `MergeSemantics` + `Semantics(button: true)` around the whole `ListTile`, matching the "Notification type" and "Theme" rows. Previously the trailing value sat in its own `MergeSemantics` around a bare `Text` — a no-op that emitted the value as a static node detached from the control that changes it. The merged label carries the live value (e.g. "Play a verse every … 45 min").
- Trailing values use `tt.labelMedium`, not `tt.bodyMedium`: `bodyMedium` maps to Lora, reserved for scripture text (Design Brief §4). It rendered correctly only by coincidence of the `ListTile` default.

Dialog commit semantics differ by input type and are specified in Design Brief §7: the interval dialog is a discrete preset chip list, so it commits on tap with Cancel as the sole escape; the probability dialog is a slider, so it follows Action Pairs with an explicit Save.

## Changelog
| Date | Change |
|---|---|
| 2026-05-27 | Initial documentation |
| 2026-05-27 | Updated with full implementation: replaced just_audio/asset clips with flutter_tts state machine, documented AudioReviewService generation counter, AudioInterruptService timer logic, notification VISIBILITY_PRIVATE decision, settings screen inventory |
| 2026-06-10 | Bug fixes: isCompleted getter; resume() guard; _currentVerse kept on completed/nulled on idle; player bar play button disabled + accessible; Symbols.* icons; Dismissible semantics |
| 2026-06-24 | Retired legacy continuous "Audio review" shuffled-loop mode and `AudioReviewService` entirely (#48); `audioReviewEnabled` removed from settings model/SharedPreferences |
| 2026-06-26 | Repurposed interrupt probability slider to control verse-of-week selection weight; interrupts now always fire once the threshold is crossed (#42) |
| 2026-07-15 | Audio rows state their master-switch dependency in text and semantics; interval/probability rows merged into one button-role node with the live value; trailing values moved off the Lora-mapped role (#176, #177, #179, #183, #184) |
| 2026-06-26 | Added ESV audio playback: `EsvAudioCacheService` fetches/caches real Crossway recordings; `AudioService` plays them for the text phase of ESV verses via `audioplayers`, falling back to TTS silently on any failure (#70) |
| 2026-06-26 | Added `AudioProvider.queue` read-only getter and wired `EsvCopyrightFooter` into `ReviewPlayScreen` (#68) |
| 2026-06-26 | Internal hardening (#72, #74, #76): `EsvAudioCacheService`'s host/scheme checks now delegate to the shared `assertAllowedHttpsHost` guard, wrapping its `StateError` in `EsvAudioException` to preserve the existing exception contract |
| 2026-07-14 | Periodic verse playback (#164): renamed `audioInterruptAfterMinutes` → `audioInterruptIntervalMinutes` (recurring "every N minutes" interval; presets 15/30/45/60/90 min, default 60 unchanged); added `AudioTriggerMode` (`whileOtherAudioPlaying` default \| `always`) with tolerant `fromName`; `fromMap`/`SettingsProvider` migrate from the legacy `audio_interrupt_after_minutes` SharedPreferences key. `audioInterruptEnabled`/`audioInterruptProbability` unchanged. Settings reworked: "Play verses periodically" toggle, "Play a verse every" interval dialog, "When to play" trigger-mode chips |
| 2026-07-14 | Periodic verse playback (#164): added `SystemAudioService`, the project's first platform channel (`bible_flashcards/system_audio`), wrapping `AudioManager.isMusicActive` and transient-audio-focus request/abandon in Kotlin (`MainActivity`, no new permission; fails closed on channel errors). `AudioInterruptService` gates `whileOtherAudioPlaying` on a debounced (3× / 300ms) `isMusicActive` check, holds focus for the whole verse (denial skips silently), and guards mid-verse re-entrancy — recurrence itself isn't new, the prior threshold logic already re-armed after each crossing. Added `system_audio_service_test.dart`, expanded `audio_interrupt_service_test.dart`, a 375px settings layout test, and `integration_test/system_audio_channel_test.dart` for the real channel |
| 2026-07-15 | #173/#174/#175: `meta/PRIVACY.md` now accounts for other-app audio detection (Data Collected row, "Data NOT Collected" foreclosure of audio capture, and the recorded rationale for shipping without a first-enable notice) and for `RECEIVE_BOOT_COMPLETED`. The "When to play" subtitle discloses the mechanic in-app, only in the mode that performs the check. `test/android_manifest_test.dart` now fails if a declared permission has no PRIVACY.md row. No behavior changed |
| 2026-07-15 | #172/#187/#188: covered `AudioInterruptService`'s two mid-flight cancellation guards (previously dead to the suite — removing either failed no test) via a non-zero debounce delay and probe-driven cancellation; covered `AppSettings.fromMap`'s trigger-mode fallback for garbage/unknown/null persisted values, which is all that stands between a corrupted preference and a `StateError` on settings load; folded `SystemAudioService`'s two bool paths into one `_invokeBool` helper (`abandonFocus` left alone — it differs in return type and comments). No behavior changed |
