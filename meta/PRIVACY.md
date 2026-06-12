# Privacy Policy — Bible Flashcards

## Summary
Bible Flashcards collects no personal data, uses no network, and stores all data exclusively on the user's device. There is nothing to transmit, share, or delete remotely.

## Data Collected

| Data | Storage | Purpose | Retention |
|---|---|---|---|
| Selected verses and memorization status | Local SQLite (encrypted) | Core app function | Until user deletes app |
| Test session history (scores, timestamps) | Local SQLite (encrypted) | Progress review | Until user deletes app or clears data |
| Verse of the week selection | Local SQLite (encrypted) | Core app function | Until changed or app deleted |
| Custom verses entered by user | Local SQLite (encrypted) | Core app function | Until user deletes them or app |
| User preferences (audio, theme, translation, notification time, notification type, lock-screen toggle) | SharedPreferences (local) | App configuration | Until user changes or uninstalls |

## Data NOT Collected
- No names, email addresses, or accounts
- No device identifiers or advertising IDs
- No usage analytics or crash reporting
- No location data
- No audio recordings (the user's voice is never captured; recite mode is self-scored)
- No network requests of any kind

## PII Assessment
No PII is collected or processed. Verse text and references are not personal information. Notification time preference is a local setting with no identifying value.

## Notification Settings

Users may configure a daily reminder notification (off by default). The notification body is always generic — no verse text or reference is included.

**Lock screen visibility** (`showOnLockScreen`) defaults to `false` (`NotificationVisibility.private`). The user may opt in to show notification content on the lock screen. This is opt-in because religious practice is GDPR Art. 9 adjacent — enabling this reveals to lock-screen bystanders that the user uses a Bible memorization app. An explicit bystander warning is shown in the settings UI.

## Permissions Used

| Permission | Reason |
|---|---|
| `FOREGROUND_SERVICE` | Background audio playback |
| `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Audio classification for Android media session |
| `POST_NOTIFICATIONS` (Android 13+) | Dismissible interruption notification and daily reminder |
| `SCHEDULE_EXACT_ALARM` | Daily reminder fires at the configured time (requires user consent via system Settings on API 31+; auto-granted below API 31) |

`SCHEDULE_EXACT_ALARM` is only used for the daily reminder. Permission is requested at point-of-use; if denied, the user is shown a message directing them to system settings — the app does not degrade otherwise.

No internet, camera, microphone, contacts, or storage permissions are requested.

## Third-Party SDKs
- `sqflite_sqlcipher` — local SQLite only, no network
- `flutter_local_notifications` — local notifications only, no remote push
- `flutter_timezone` — reads device timezone for accurate notification scheduling; data stays on-device
- `google_fonts` — runtime font fetching is disabled (`allowRuntimeFetching = false`); fonts must be bundled

None of these packages transmit data off-device in this configuration.

## Children
This app is not directed at children and does not require any age-gating given zero data collection.

## Changes
Any future change that introduces data collection will require updating this document and displaying an in-app notice before the change takes effect.

## Contact
This is a personal-use app with no external distribution at this time. No privacy contact is applicable.
