# Audio

## Summary
The audio feature lets the user hear verse recitations during other activities. It plays the reference, pauses for the user to mentally recite, then plays the text. A 50%-probability interruption feature reinforces passive memorization. (The legacy continuous "Audio review" shuffled-loop mode was retired — see #48.)

## Users / Use Cases
- **Solo user**: listens to verse audio while doing other tasks; receives occasional audio interruptions as spaced-repetition prompts.

## Technologies
- `flutter_tts` — text-to-speech synthesis for reference and verse text (no bundled audio assets required)
- `audioplayers` — local MP3 playback for real ESV recordings during the text phase
- `flutter_local_notifications` — persistent notification and lock-screen controls; both notifications use `VISIBILITY_PRIVATE`
- Provider — `AudioProvider` exposes playback state to UI

## Technical Overview
Playback is driven by `AudioService`, a TTS state machine that sequences: speak reference → timed pause → speak text. For ESV verses, the text phase plays the real Crossway recording (fetched/cached by `EsvAudioCacheService`) instead of TTS; any cache or network failure falls back to TTS silently. `AudioInterruptService` runs a repeating timer that fires a one-verse interruption with 50% probability once a configurable threshold of elapsed time is reached.

## Key Files
| File | Purpose |
|---|---|
| `lib/features/audio/audio_service.dart` | TTS state machine: reference → pause → text |
| `lib/features/audio/audio_interrupt_service.dart` | Timer-based interruption, 50% probability |
| `lib/features/audio/notification_controls.dart` | Notification construction and action handling |
| `lib/providers/audio_provider.dart` | Exposes playback state and controls to UI |
| `lib/features/settings/settings_screen.dart` | Toggles for interrupt, probability slider, theme |
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

### AudioInterruptService — Timer
- A repeating `Timer` fires every `checkInterval` (default 5 minutes).
- No interruptions fire until `thresholdDuration` of continuous app use has elapsed (default 60 minutes, user-configurable in Settings).
- On each timer tick after the threshold: `Random().nextDouble() < probability` (default 0.5). If true, `AudioService.play()` is called for one verse (verse-of-week 50% / random memorized verse 50%), then the timer pauses until that verse completes.

### Notifications
Both notification types use `VISIBILITY_PRIVATE` so no verse text appears on the lock screen.

| Notification | Title | Body | Action |
|---|---|---|---|
| Review playback | "Bible Review" | "Playing verse" | Stop |
| Interrupt playback | "Bible Verse" | "Tap to hear your verse" | Dismiss |

"Dismiss" stops the interruption immediately and returns audio focus to the foreground app.

### ESV Audio Branch
- Only activates when `verse.translation == 'ESV'`; all other translations always use TTS for both phases.
- `EsvAudioCacheService.getAudioPath(reference)` resolves the MP3 via a **two-request pattern**: first request hits `api.esv.org` with the `Authorization: Token <key>` header and `followRedirects = false` to read the `Location` header; second request fetches the MP3 from the redirect target **without** the auth header, and only after validating the target host against an allowlist (`audio.esv.org`) — this prevents the API key from ever reaching a CDN host, even a compromised or misconfigured one.
- Cache filename is `sha256(reference.toLowerCase().trim())` — never the raw reference — ruling out path traversal.
- Cache is capped at 250 files (oldest evicted first); concurrent `getAudioPath` calls for the same reference share one in-flight fetch.
- Gated on the `esv_lookup_consent_v1` preference flag (shared with ESV text lookup) — no separate audio consent prompt, since saving an ESV verse already required consenting to send the same reference to Crossway.
- `AudioService._playMp3AndWait` plays via `audioplayers`' `DeviceFileSource`; `stop()`/`pause()` explicitly stop and resolve the in-flight player completer (unlike TTS, `AudioPlayer.stop()` does not fire a completion event), so `resume()` always restarts the current text phase from the beginning — same restart-from-beginning behavior as TTS resume.
- Any exception from `EsvAudioCacheService` (offline, fetch failure, consent not yet granted) is caught and falls back to TTS silently — no error state, no user-visible interruption.

### Permissions
- `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_MEDIA_PLAYBACK` for background TTS/audio.
- `POST_NOTIFICATIONS` (Android 13+) for the dismissible notification.
- `INTERNET` for ESV audio fetches (`api.esv.org`, `audio.esv.org`) — only used for ESV verses with consent already granted; no internet required otherwise. No microphone permission required for this feature.

### Settings Exposed to User
- Interrupt toggle (on/off)
- Verse-of-week probability slider (10%–90%, default 50%) — controls how often the verse of the week is selected during interrupts
- Interrupt threshold (30 min / 60 min / 90 min, default 60 min)
- Theme selector (light / dark / system)
- Test history list and "Clear History" action

## Changelog
| Date | Change |
|---|---|
| 2026-05-27 | Initial documentation |
| 2026-05-27 | Updated with full implementation: replaced just_audio/asset clips with flutter_tts state machine, documented AudioReviewService generation counter, AudioInterruptService timer logic, notification VISIBILITY_PRIVATE decision, settings screen inventory |
| 2026-06-10 | Bug fixes: isCompleted getter; resume() guard; _currentVerse kept on completed/nulled on idle; player bar play button disabled + accessible; Symbols.* icons; Dismissible semantics |
| 2026-06-24 | Retired legacy continuous "Audio review" shuffled-loop mode and `AudioReviewService` entirely (#48); `audioReviewEnabled` removed from settings model/SharedPreferences |
| 2026-06-26 | Repurposed interrupt probability slider to control verse-of-week selection weight; interrupts now always fire once the threshold is crossed (#42) |
| 2026-06-26 | Added ESV audio playback: `EsvAudioCacheService` fetches/caches real Crossway recordings; `AudioService` plays them for the text phase of ESV verses via `audioplayers`, falling back to TTS silently on any failure (#70) |
