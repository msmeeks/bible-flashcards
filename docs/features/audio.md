# Audio

## Summary
The audio feature lets the user hear verse recitations during other activities. It plays the reference, pauses for the user to mentally recite, then plays the text. An optional continuous audio review mode and a 50%-probability interruption feature reinforce passive memorization.

## Users / Use Cases
- **Solo user**: listens to verse audio while doing other tasks; enables audio review for passive review sessions; receives occasional audio interruptions as spaced-repetition prompts.

## Technologies
- `flutter_tts` — text-to-speech synthesis for reference and verse text (no bundled audio assets required)
- `flutter_local_notifications` — persistent notification and lock-screen controls; both notifications use `VISIBILITY_PRIVATE`
- Provider — `AudioProvider` exposes playback state to UI

## Technical Overview
Playback is driven by `AudioService`, a TTS state machine that sequences: speak reference → timed pause → speak text. `AudioReviewService` wraps `AudioService` in a shuffled continuous loop, using a generation counter to prevent stale callbacks from a previous loop from triggering playback after a stop. `AudioInterruptService` runs a repeating timer that fires a one-verse interruption with 50% probability once a configurable threshold of elapsed time is reached.

## Key Files
| File | Purpose |
|---|---|
| `lib/features/audio/audio_service.dart` | TTS state machine: reference → pause → text |
| `lib/features/audio/audio_review_service.dart` | Shuffled continuous loop with generation counter |
| `lib/features/audio/audio_interrupt_service.dart` | Timer-based interruption, 50% probability |
| `lib/features/audio/notification_controls.dart` | Notification construction and action handling |
| `lib/providers/audio_provider.dart` | Exposes playback state and controls to UI |
| `lib/features/settings/settings_screen.dart` | Toggles for review, interrupt, probability slider, theme |

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

### AudioReviewService — Generation Counter
Each call to `start()` increments an integer `_generation`. Every async callback (TTS completion, loop-advance) captures the generation value at dispatch time and checks it against the current value before proceeding. A stale callback (generation mismatch) is silently dropped. This prevents a stopped loop from inadvertently starting a new verse after the service has been torn down.

The loop is shuffled: all verses in the pool are randomised once per pass; when the list is exhausted it is reshuffled for the next pass.

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

### Permissions
- `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_MEDIA_PLAYBACK` for background TTS.
- `POST_NOTIFICATIONS` (Android 13+) for the dismissible notification.
- No internet or microphone permissions required.

### Settings Exposed to User
- Audio review toggle (on/off)
- Interrupt toggle (on/off)
- Interrupt probability slider (10%–90%, default 50%)
- Interrupt threshold (30 min / 60 min / 90 min, default 60 min)
- Theme selector (light / dark / system)
- Test history list and "Clear History" action

## Changelog
| Date | Change |
|---|---|
| 2026-05-27 | Initial documentation |
| 2026-05-27 | Updated with full implementation: replaced just_audio/asset clips with flutter_tts state machine, documented AudioReviewService generation counter, AudioInterruptService timer logic, notification VISIBILITY_PRIVATE decision, settings screen inventory |
| 2026-06-10 | Bug fixes: isCompleted getter; resume() guard; _currentVerse kept on completed/nulled on idle; player bar play button disabled + accessible; Symbols.* icons; Dismissible semantics |
