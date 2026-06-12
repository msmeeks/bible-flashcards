# Privacy Policy — Bible Flashcards

## Summary
Bible Flashcards collects no personal data and stores all data exclusively on the user's device. Optional verse lookup and pack import features make outbound HTTPS requests to bible.helloao.org; these are user-initiated and require explicit consent before the first network call.

## Data Collected

| Data | Storage | Purpose | Retention |
|---|---|---|---|
| Selected verses and memorization status | Local SQLite | Core app function | Until user deletes app |
| Test session history (scores, timestamps) | Local SQLite | Progress review | Until user deletes app or clears data |
| Verse of the week selection | Local SQLite | Core app function | Until changed or app deleted |
| Custom verses entered by user | Local SQLite | Core app function | Until user deletes them or app |

## Data NOT Collected
- No names, email addresses, or accounts
- No device identifiers or advertising IDs
- No usage analytics or crash reporting
- No location data
- No audio recordings (the user's voice is never captured; recite mode is self-scored)
- No automatic network requests; all network calls are user-initiated and require prior consent

## PII Assessment
No PII is collected or processed. Verse text and references are not personal information.

## Permissions Used

| Permission | Reason |
|---|---|
| `FOREGROUND_SERVICE` | Background audio playback |
| `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Audio classification for Android media session |
| `POST_NOTIFICATIONS` (Android 13+) | Dismissible interruption notification |
| `INTERNET` | Optional verse lookup and pack import; user-initiated only; requires explicit consent on first use |

No camera, microphone, contacts, or storage permissions are requested.

## Network Requests

Verse lookup sends HTTPS requests to `bible.helloao.org` (a free public Bible API). No other external hosts are contacted.

- Requests are user-initiated (tap Search); the app never auto-fetches.
- The user's IP address is visible to `bible.helloao.org` as the remote host for each request.
- The verse reference typed by the user is included as a path component in the lookup URL.
- No account, device identifier, or PII is sent.
- All traffic is HTTPS-only; cleartext is blocked at the OS level via `network_security_config.xml`.
- On first use, the app displays a consent dialog naming `bible.helloao.org` as the data recipient before any request fires. Consent is stored locally in `SharedPreferences`.

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
