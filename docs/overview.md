# Bible Flashcards — Project Overview

## Purpose
A personal Android app for memorizing and reviewing Bible verses. The primary user is a single person working through structured Navigator memory packs at a pace of one verse per week, with built-in testing and audio review to reinforce retention.

## Users
- **Solo user (owner)**: selects verses, tracks memorization progress, runs tests, and uses audio review during other activities.

No accounts, no server, no multi-user support — the app is entirely local.

## Architecture
The app is a single Flutter application targeting Android (Google Pixel 9 Pro, Android 16). All data is stored locally in SQLite. Audio files are bundled as assets. There is no network layer.

```
lib/
  main.dart
  data/          # SQLite schema, DAOs, repository layer
  models/        # Verse, Pack, TestResult domain objects
  features/
    verse_management/
    test_modes/
    audio/
  widgets/       # Shared UI components
assets/
  packs/         # JSON definitions for Navigator memory packs
  audio/         # Pre-recorded verse audio files (reference + text)
```

Data flows: UI -> repository -> sqflite -> SQLite file on device. Audio playback: UI -> AudioService -> just_audio -> asset file.

## Tech Stack

| Technology | Role |
|---|---|
| Flutter / Dart | UI framework and app logic |
| sqflite | Local SQLite database for verses, progress, test history |
| just_audio | Audio playback with gap/pause control |
| flutter_local_notifications | Lock-screen and notification-tray controls for audio interruption dismissal |
| provider or riverpod | State management (TBD during implementation) |

## Bible Versions
ESV, CSB, and NLT. The user selects one version per pack when adding it. Verse text for each version is stored in the asset pack definitions.

## Navigator Memory Packs
Pre-loaded JSON asset files defining the Topical Memory System (TMS) verses. Each pack entry includes: reference, verse text per supported version, and pack/topic metadata.

## Key Constraints
- Android-only (no iOS, web, or desktop targets)
- Fully offline — no internet permission required
- No user accounts or cloud sync
- Audio files are bundled assets (no streaming)
