# LLM Context Index

Load this file first. Then load only the specific doc files relevant to your task.

## Project docs
- [overview.md](overview.md) — project purpose, users, roles, architecture, tech stack
- [features/navigation.md](features/navigation.md) — persistent app shell: `MainScaffold`'s nested per-tab Navigator + `IndexedStack` keeps the navbar/audio bar visible across sub-screen pushes, `PopScope` back-navigation routing (back-to-Home-then-exit convention), `ExcludeSemantics` isolation of inactive tabs
- [features/verse-management.md](features/verse-management.md) — encrypted SQLite, Navigator packs (DB v2 packs table, pack names), VerseCard FlashcardState 3-state cycle, memorized list, home/verses/add/detail screens, ESV verse lookup (EsvLookupService, 500-verse cap, isolated consent), default translation setting, auto-advance verse of the week (Sunday/ISO-week guard), shared `lib/services/net_security.dart` SSRF host-allowlist helper used by all outbound HTTP services, Add Verse confirmation redesign (direct auto-fill, focus-loss reference normalization, save-confirmation `AlertDialog`, save-directly-to-Memorized checkbox), custom-variant resolution reused at web-lookup time, Available-tab scroll-position preservation across Memorize taps, removed non-functional Verse Detail translation selector (#138)
- [features/test-modes.md](features/test-modes.md) — test setup/session/results flow (Type and Fill Blank formats only — Recite mode removed, #165), LCS scoring with apostrophe-insensitive normalization (`normalizeWords`, #161), word-level `diffWords` answer diff surfaced in Type mode via `_AnswerDiff` (#162), Type mode's explicit **Next**-button advance instead of auto-advance (#166), natural separator/range normalization for typed references, fill-blank algorithm, privacy decision on typed input, Book Name Variants settings screen (double-tap-safe Add dialog), Test Summary/History verse-reference display fix
- [features/review-screen.md](features/review-screen.md) — Review nav tab, count/verse-of-week setup controls, Show presentation with fixed-session verse list and tap-to-reveal, Play presentation (audio queue)
- [features/audio.md](features/audio.md) — flutter_tts state machine, ESV real-recording playback via EsvAudioCacheService (two-request redirect pattern, SHA-256 cache keys), AudioInterruptService recurring interval scheduler with trigger-mode gating (`whileOtherAudioPlaying` default / `always`, #164), SystemAudioService platform channel (`bible_flashcards/system_audio` — `isMusicActive`, transient audio focus request/abandon; project's first platform channel), audio notification bodies
- [features/esv-attribution.md](features/esv-attribution.md) — collapsible EsvCopyrightFooter widget wired into Add Verse/Verse Detail/Test/Review screens (via `onViewFullTerms` callback, no direct SettingsScreen coupling), persisted collapse state, Settings "ESV Bible" full notice + esv.org link, `AnnounceOnChange` helper for single-fire live-region announcements
- [features/notifications.md](features/notifications.md) — daily reminder scheduling, timezone init, lock-screen toggle, notification channels, SCHEDULE_EXACT_ALARM, runtime `POST_NOTIFICATIONS` request gating the schedule (#163), `DailyReminderResult` denied-permission reporting + inline denial banner, reboot survival via `ScheduledNotificationBootReceiver` (guarded by `test/android_manifest_test.dart`)
- [features/web-lookup.md](features/web-lookup.md) — BibleLookupService HTTP fetch, reference parsing, consent dialog, preview card, importPackFromJson batch import
- [features/tracking.md](features/tracking.md) — engagement_log schema, TrackingProvider streak/chart computations, HistoryScreen charts + table toggle, first-launch consent, Settings clear
- [features/data-management.md](features/data-management.md) — export/import JSON backup (share sheet, Save Locally via SAF file_picker), ImportService validation caps, DataManagementScreen dialogs; no cloud backup (Google Drive support fully removed, #130 — `GoogleDriveService` deleted, `LegacySettingsMigration.clearStaleDriveSignInFlag()` startup cleanup of the orphaned `drive_signed_in` secure-storage key); notes stale "Google Drive backup" Settings subtitle string
- [features/theming.md](features/theming.md) — light/dark Material 3 ThemeData (app_theme.dart), brightness-aware AppColors semantic tokens (success/warning), dark-theme badge/errorContainer contrast fix (#138), WCAG contrast test suite

## Setup & tooling
- [../scripts/setup-mac.sh](../scripts/setup-mac.sh) — one-command macOS bootstrap script (Flutter, Java 17, Android SDK, emulator)
- [../DEVELOPER.md](../DEVELOPER.md) — manual setup steps, troubleshooting, project structure

## Design & dev
- [../meta/DESIGN_BRIEF.md](../meta/DESIGN_BRIEF.md) — UI design system and component patterns
- [../meta/BRAND_VOICE.md](../meta/BRAND_VOICE.md) — tone, language, user-facing copy guidelines
- [../meta/PRIVACY.md](../meta/PRIVACY.md) — data handling, PII policy
- [../CHANGELOG.md](../CHANGELOG.md) — project changelog
