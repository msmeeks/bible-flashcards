# Audio

## Summary
The audio feature lets the user hear verse recitations during other activities. It plays the reference, pauses for the duration the text would take to speak, then plays the text. An optional continuous audio review mode and a 50%-probability interruption feature reinforce passive memorization.

## Users / Use Cases
- **Solo user**: listens to verse audio while doing other tasks; enables audio review for passive review sessions; receives occasional audio interruptions as spaced-repetition prompts.

## Technologies
- just_audio — asset-based audio playback with silence gap insertion
- flutter_local_notifications — persistent notification and lock-screen controls for dismissing interruptions

## Technical Overview
Each verse has two bundled audio assets: a reference clip and a text clip. Playback is orchestrated by `AudioService`, which sequences: reference clip -> silence gap (duration = text clip length) -> text clip. Audio review mode loops indefinitely over a selected verse until stopped. The interruption system hooks into a running audio session and fires a review prompt after one hour of continuous play with 50% probability per check interval.

## Key Files
| File | Purpose |
|---|---|
| `assets/audio/<reference>/ref.mp3` | Spoken reference clip |
| `assets/audio/<reference>/text.mp3` | Spoken verse text clip |
| `lib/features/audio/audio_service.dart` | Playback sequencing: reference + gap + text |
| `lib/features/audio/review_mode.dart` | Continuous audio review loop logic |
| `lib/features/audio/interruption_service.dart` | Hour-threshold detection, 50% probability trigger |
| `lib/features/audio/notification_controls.dart` | Lock-screen / notification dismiss action |

## Technical Detail

### Playback Format
1. Play `ref.mp3` for the verse.
2. Insert silence of duration equal to `text.mp3` length (gives the user time to mentally recite).
3. Play `text.mp3`.

This is implemented as a `ConcatenatingAudioSource` in just_audio with a `SilenceAudioSource` in the middle.

### Audio Review Mode
- Toggle on/off from the main UI.
- When on: selects verse of the week OR a random memorized verse and plays it in the standard format, then repeats.
- The verse selection per iteration is independent (each loop picks fresh).

### Interruption Feature
- Only active when other audio (music, podcast) has been playing on the device for more than 60 minutes.
- On each check (interval TBD, e.g., every 5 minutes after the 60-minute mark): 50% probability of triggering.
- Trigger: requests audio focus, plays one verse using the standard format (verse of the week 50% / random memorized verse 50%), then releases audio focus.
- A persistent notification appears during interruption playback with a "Dismiss" action.
- Dismiss action: stops the interruption audio and returns audio focus to the prior app immediately.
- Lock-screen media controls also show the Dismiss action via `flutter_local_notifications` media style.

### Permissions
- `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_MEDIA_PLAYBACK` for background audio.
- `POST_NOTIFICATIONS` (Android 13+) for the dismissible notification.
- No internet or microphone permissions required.

## Changelog
| Date | Change |
|---|---|
| 2026-05-27 | Initial documentation |
