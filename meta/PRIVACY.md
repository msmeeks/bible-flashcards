# Privacy Policy — Bible Flashcards

## Summary
Bible Flashcards collects no personal data, uses no network, and stores all data exclusively on the user's device. There is nothing to transmit, share, or delete remotely.

## Data Collected

| Data | Storage | Purpose | Retention |
|---|---|---|---|
| Selected verses and memorization status | Local SQLite | Core app function | Until user deletes app |
| Test session history (scores, timestamps) | Local SQLite | Progress review | Until user deletes app or clears data |
| Verse of the week selection | Local SQLite | Core app function | Until changed or app deleted |
| Custom verses entered by user | Local SQLite | Core app function | Until user deletes them or app |
| Engagement log (date, event type, aggregate count) | Local SQLite (`engagement_log`) | Streak & activity history display | 90 days auto-purge; user-clearable via Settings → Activity History |

### engagement_log schema
- `date` — calendar date only (`YYYY-MM-DD`), no time component
- `event_type` — `'flashcard_tap'` or `'test_complete'`
- `count` — aggregate count per day per event type (no per-verse sequences)

**First-launch notice:** When `engagement_log` is introduced (DB migration to version 2), a one-time in-app dialog explains what is tracked and how to clear it. The flag `engagement_notice_shown` in `SharedPreferences` gates this dialog.

## Data NOT Collected
- No names, email addresses, or accounts
- No device identifiers or advertising IDs
- No usage analytics or crash reporting
- No location data
- No audio recordings (the user's voice is never captured; recite mode is self-scored)
- No network requests of any kind

## PII Assessment
No PII is collected or processed. Verse text and references are not personal information.

## Permissions Used

| Permission | Reason |
|---|---|
| `FOREGROUND_SERVICE` | Background audio playback |
| `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Audio classification for Android media session |
| `POST_NOTIFICATIONS` (Android 13+) | Dismissible interruption notification |

No internet, camera, microphone, contacts, or storage permissions are requested.

## Third-Party SDKs
- `just_audio` — local asset playback only, no analytics
- `sqflite` — local SQLite only, no network
- `flutter_local_notifications` — local notifications only, no remote push

None of these packages transmit data off-device in this configuration.

## Children
This app is not directed at children and does not require any age-gating given zero data collection.

## Changes
Any future change that introduces data collection will require updating this document and displaying an in-app notice before the change takes effect.

## Contact
This is a personal-use app with no external distribution at this time. No privacy contact is applicable.
