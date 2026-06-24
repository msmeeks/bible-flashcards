# LLM Context Index

Load this file first. Then load only the specific doc files relevant to your task.

## Project docs
- [overview.md](overview.md) — project purpose, users, roles, architecture, tech stack
- [features/verse-management.md](features/verse-management.md) — encrypted SQLite, Navigator packs (DB v2 packs table, pack names), VerseCard FlashcardState 3-state cycle, memorized list, home/verses/add/detail screens
- [features/test-modes.md](features/test-modes.md) — test setup/session/results flow, LCS scoring, fill-blank algorithm, opt-in on-device speech-to-text for recite mode, privacy decision on typed/voice input
- [features/audio.md](features/audio.md) — flutter_tts state machine, AudioReviewService generation counter, AudioInterruptService timer, audio notification bodies
- [features/notifications.md](features/notifications.md) — daily reminder scheduling, timezone init, lock-screen toggle, notification channels, SCHEDULE_EXACT_ALARM
- [features/web-lookup.md](features/web-lookup.md) — BibleLookupService HTTP fetch, reference parsing, consent dialog, preview card, importPackFromJson batch import
- [features/tracking.md](features/tracking.md) — engagement_log schema, TrackingProvider streak/chart computations, HistoryScreen charts + table toggle, first-launch consent, Settings clear
- [features/data-management.md](features/data-management.md) — export/import JSON backup (share sheet, Save Locally via SAF file_picker, Google Drive), ImportService validation caps, DataManagementScreen dialogs

## Setup & tooling
- [../scripts/setup-mac.sh](../scripts/setup-mac.sh) — one-command macOS bootstrap script (Flutter, Java 17, Android SDK, emulator)
- [../DEVELOPER.md](../DEVELOPER.md) — manual setup steps, troubleshooting, project structure

## Design & dev
- [../meta/DESIGN_BRIEF.md](../meta/DESIGN_BRIEF.md) — UI design system and component patterns
- [../meta/BRAND_VOICE.md](../meta/BRAND_VOICE.md) — tone, language, user-facing copy guidelines
- [../meta/PRIVACY.md](../meta/PRIVACY.md) — data handling, PII policy
- [../CHANGELOG.md](../CHANGELOG.md) — project changelog
