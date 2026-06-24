# Privacy Policy — Bible Flashcards

## Summary
Bible Flashcards stores all core data exclusively on the user's device in encrypted SQLite. Two optional features make outbound network requests, both user-initiated and gated by explicit consent: verse lookup/pack import (HTTPS requests to bible.helloao.org) and Google Drive backup (transmits verse data and test history to the user's own Google Drive `appdata` folder, deletable from within the app).

## Data Collected

| Data | Storage | Purpose | Retention |
|---|---|---|---|
| Selected verses and memorization status | Local SQLite (encrypted) | Core app function | Until user deletes app |
| Test session history (scores, timestamps) | Local SQLite (encrypted) | Progress review | Until user deletes app or clears data |
| Verse of the week selection | Local SQLite (encrypted) | Core app function | Until changed or app deleted |
| Custom verses entered by user | Local SQLite (encrypted) | Core app function | Until user deletes them or app |
| User preferences (audio, theme, translation, notification time, notification type, lock-screen toggle) | SharedPreferences (local) | App configuration | Until user changes or uninstalls |
| Engagement log (date, event type, aggregate count) | Local SQLite (`engagement_log`) | Streak & activity history display | 90 days auto-purge; user-clearable via Settings → Activity History |
| Export file (JSON snapshot of above) | App internal storage (temporary) | User-initiated data transfer | Deleted immediately after share |
| Drive backup (same JSON, encrypted in transit) | Google Drive `appdata` folder | Optional cloud backup | Until user deletes backup from app or removes app access in Google account settings |

### engagement_log schema
- `date` — calendar date only (`YYYY-MM-DD`), no time component
- `event_type` — `'flashcard_tap'` or `'test_complete'`
- `count` — aggregate count per day per event type (no per-verse sequences)

**First-launch notice:** When `engagement_log` is introduced (DB migration to version 2), a one-time in-app dialog explains what is tracked and how to clear it. The flag `engagement_notice_shown` in `SharedPreferences` gates this dialog.

## Data NOT Collected
- No names, email addresses, or persistent account identifiers (Google account email used in-memory only for display; never stored on disk)
- No device identifiers or advertising IDs
- No usage analytics or crash reporting
- No location data
- No audio recordings persisted to disk — see Voice Recitation (Recite Mode) below for ephemeral, on-device microphone use
- No automatic network requests; all network calls (verse lookup, pack import, Drive backup) are user-initiated and require prior consent

## Special Category Data (GDPR Art. 9)
Test history (which verses were studied, when, accuracy) combined with verse content constitutes a profile of religious practice. This data is stored locally by default. If Drive backup is enabled, this data is transmitted to Google's servers. A DPIA assessment is required before enabling this feature for any user other than the app author. See Cloud Backup section below.

## PII Assessment
No PII is collected or processed in normal operation. Verse text and references are not personal information. Notification time preference is a local setting with no identifying value. The Google account email used for Drive OAuth is held in memory only and cleared on sign-out.

## Voice Recitation (Recite Mode)

Recite-mode tests offer an **opt-in** microphone button as an alternative to typing or self-rating; typed/self-rated recite remains the default and is always fully functional without granting microphone access.

- **Permission:** `RECORD_AUDIO` is requested at point-of-use (when the mic button is tapped), never pre-granted or requested at app launch. Denial keeps the typed/self-rated recite flow fully usable; a permanently-denied result routes the user to system settings via an in-app dialog.
- **On-device only:** Speech recognition is forced to run on-device (`onDevice: true`); if the platform cannot recognize locally, the attempt fails outright rather than sending audio to a cloud recognizer. No recitation audio leaves the device.
- **Ephemeral transcripts:** The recognized transcript is held only in ephemeral widget state, scored immediately against the verse text using the same on-device LCS algorithm as typed answers, and discarded the moment scoring completes. The transcript is never written to the database, SharedPreferences, or logs, and the raw audio itself is never captured to a file.
- **Retention:** None — same ephemeral-state policy as typed test input (see Test Modes feature doc).

## Notification Settings

Users may configure a daily reminder notification (off by default). The notification body is always generic — no verse text or reference is included.

**Lock screen visibility** (`showOnLockScreen`) defaults to `false` (`NotificationVisibility.private`). The user may opt in to show notification content on the lock screen. This is opt-in because religious practice is GDPR Art. 9 adjacent — enabling this reveals to lock-screen bystanders that the user uses a Bible memorization app. An explicit bystander warning is shown in the settings UI.

## Cloud Backup (Optional)

This feature is **off by default**. Enabling it requires explicit consent.

- **What is transmitted:** All locally stored verses, test history (scores and timestamps), and app settings
- **Destination:** The user's own Google Drive `appdata` folder (hidden from the user's Drive file browser; accessible only by this app)
- **Data processor:** Google LLC (see [Google's Privacy Policy](https://policies.google.com/privacy) and [Data Processing Terms](https://workspace.google.com/terms/dpa/))
- **Encryption in transit:** HTTPS/TLS. Not end-to-end encrypted — Google can access the data under its Terms of Service, including for safety, compliance, and law enforcement purposes
- **Token storage:** OAuth access tokens stored in Android Keystore-backed secure storage only (`flutter_secure_storage`); never in plain SharedPreferences or logs
- **Retention:** The app keeps only the 3 most recent backups; older ones are deleted automatically on each new backup write
- **User deletion:** Use "Delete Drive Backup" in Settings → Data & Backup to remove all backup files from Google's servers. You can also revoke access at [Google Account Security](https://myaccount.google.com/permissions)
- **Consent record:** Timestamp and disclosure version are stored locally when consent is given

## Permissions Used

| Permission | Reason |
|---|---|
| `FOREGROUND_SERVICE` | Background audio playback |
| `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Audio classification for Android media session |
| `POST_NOTIFICATIONS` (Android 13+) | Dismissible interruption notification and daily reminder |
| `SCHEDULE_EXACT_ALARM` | Daily reminder fires at the configured time (requires user consent via system Settings on API 31+; auto-granted below API 31) |
| `RECORD_AUDIO` | Optional mic button in recite-mode tests (on-device speech-to-text only); requested at point-of-use, not pre-granted; typed/self-rated recite works fully without it |
| `INTERNET` | Optional verse lookup/pack import and optional Google Drive backup; both user-initiated, neither runs without explicit consent |

`SCHEDULE_EXACT_ALARM` is only used for the daily reminder. Permission is requested at point-of-use; if denied, the user is shown a message directing them to system settings — the app does not degrade otherwise.

No camera, contacts, or storage permissions are requested.

## Network Requests

Verse lookup sends HTTPS requests to `bible.helloao.org` (a free public Bible API). Drive backup, when enabled, sends requests to Google's servers. No other external hosts are contacted.

- Requests are user-initiated (tap Search, or explicitly enable Drive backup); the app never auto-fetches.
- The user's IP address is visible to the remote host (`bible.helloao.org` or Google) for each request.
- The verse reference typed by the user is included as a path component in the lookup URL.
- No account, device identifier, or PII is sent to `bible.helloao.org`.
- All traffic is HTTPS-only; cleartext is blocked at the OS level via `network_security_config.xml`.
- On first use, the app displays a consent dialog naming `bible.helloao.org` as the data recipient before any lookup request fires. Consent is stored locally in `SharedPreferences`.

## Third-Party SDKs
- `sqflite_sqlcipher` — local encrypted SQLite only, no network
- `flutter_local_notifications` — local notifications only, no remote push
- `flutter_timezone` — reads device timezone for accurate notification scheduling; data stays on-device
- `google_fonts` — runtime font fetching is disabled (`allowRuntimeFetching = false`); fonts must be bundled
- `flutter_tts` — on-device text-to-speech only
- `speech_to_text` — on-device speech recognition only (`onDevice: true`, no cloud fallback); optional recite-mode mic input
- `google_sign_in` — OAuth 2.0 for Drive backup (optional); Google may collect SDK usage data per their terms
- `googleapis` — Drive API client for backup upload/download (optional)
- `share_plus` — Android share sheet for export file; no data sent to the package author

None of these packages transmit data off-device in this configuration, except `google_sign_in`/`googleapis` when Drive backup is explicitly enabled by the user.

## Children
This app does not collect PII in its core functionality. The optional Drive backup feature requires a Google account, which is subject to Google's age requirements. This app is not directed at children under 13.

## Changes
Any future change that introduces additional data collection will require updating this document and displaying an in-app notice before the change takes effect.

## Contact
This is a personal-use app. For data subject requests (erasure, portability), use the in-app export and "Delete Drive Backup" features.
