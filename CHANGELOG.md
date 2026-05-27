# Changelog

## [Unreleased]

## [2026-05-27] — Full App Implementation
- Home screen: verse-of-week card, quick-action buttons, recent memorized verse chips
- Verses screen: TabBar (Memorized | Available) with search; Add Verse and Verse Detail screens
- Test flow: setup screen (mode/format/direction pickers), active session (recite/type/fill-blank input), results screen, test history in Settings
- Scoring: word-level LCS algorithm; denominator = max(typed length, correct length); typed input discarded immediately after scoring and never persisted
- Fill-blank: every Nth content word masked; function words (≤ 3 chars) skipped
- Audio: replaced planned just_audio asset approach with flutter_tts state machine (speakingReference → pausing → speakingText → completed)
- AudioReviewService: shuffled continuous loop with generation counter to prevent race conditions on stop
- AudioInterruptService: repeating timer, configurable threshold (default 60 min), 50% probability per check (default 5-min interval)
- Notifications: both playback and interrupt notifications use VISIBILITY_PRIVATE — no verse text on lock screen
- Encryption: sqflite_sqlcipher with per-install key in Android Keystore via flutter_secure_storage; android:allowBackup="false"
- Settings screen: audio review toggle, interrupt toggle, probability slider, threshold picker, theme selector, clear history

## [2026-05-27] — Project Initialization
- Created project documentation structure (docs/, meta/)
- Defined PRD-based architecture: Flutter/Dart, SQLite, just_audio, flutter_local_notifications
- Documented verse management, test modes, and audio features
