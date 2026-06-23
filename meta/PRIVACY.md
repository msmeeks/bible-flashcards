# Privacy Policy — Bible Flashcards

## Summary
Bible Flashcards stores all core data exclusively on the user's device in encrypted SQLite. An optional Google Drive backup feature transmits verse data and test history to the user's own Google Drive `appdata` folder — this is opt-in only, requires explicit consent, and can be deleted from within the app.

## Data Collected

| Data | Storage | Purpose | Retention |
|---|---|---|---|
| Selected verses and memorization status | Local SQLite | Core app function | Until user deletes app |
| Test session history (scores, timestamps) | Local SQLite | Progress review | Until user deletes app or clears data |
| Verse of the week selection | Local SQLite | Core app function | Until changed or app deleted |
| Custom verses entered by user | Local SQLite | Core app function | Until user deletes them or app |
| Export file (JSON snapshot of above) | App internal storage (temporary) | User-initiated data transfer | Deleted immediately after share |
| Drive backup (same JSON, encrypted in transit) | Google Drive `appdata` folder | Optional cloud backup | Until user deletes backup from app or removes app access in Google account settings |

## Data NOT Collected
- No names, email addresses, or persistent account identifiers (Google account email used in-memory only for display; never stored on disk)
- No device identifiers or advertising IDs
- No usage analytics or crash reporting
- No location data
- No audio recordings (the user's voice is never captured; recite mode is self-scored)

Network requests are made only when the user explicitly enables Google Drive backup. All other app functions remain fully offline.

## Special Category Data (GDPR Art. 9)
Test history (which verses were studied, when, accuracy) combined with verse content constitutes a profile of religious practice. This data is stored locally by default. If Drive backup is enabled, this data is transmitted to Google's servers. A DPIA assessment is required before enabling this feature for any user other than the app author. See Cloud Backup section below.

## PII Assessment
No PII is collected or processed in normal operation. Verse text and references are not personal information. The Google account email used for Drive OAuth is held in memory only and cleared on sign-out.

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
| `POST_NOTIFICATIONS` (Android 13+) | Dismissible interruption notification |
| `INTERNET` | Google Drive backup only (optional feature; no requests made without user opt-in) |

## Third-Party SDKs
- `sqflite_sqlcipher` — local encrypted SQLite only, no network
- `flutter_local_notifications` — local notifications only, no remote push
- `flutter_tts` — on-device text-to-speech only
- `google_sign_in` — OAuth 2.0 for Drive backup (optional); Google may collect SDK usage data per their terms
- `googleapis` — Drive API client for backup upload/download (optional)
- `share_plus` — Android share sheet for export file; no data sent to the package author

## Children
This app does not collect PII in its core functionality. The optional Drive backup feature requires a Google account, which is subject to Google's age requirements. This app is not directed at children under 13.

## Changes
Any future change that introduces additional data collection will require updating this document and displaying an in-app notice before the change takes effect.

## Contact
This is a personal-use app. For data subject requests (erasure, portability), use the in-app export and "Delete Drive Backup" features.
