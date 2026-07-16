# Privacy Policy — Bible Flashcards

## Summary
Bible Flashcards stores all core data exclusively on the user's device in encrypted SQLite. Optional features make outbound network requests, each user-initiated and gated by explicit, separately-recorded consent: verse lookup/pack import (HTTPS requests to bible.helloao.org) and ESV verse lookup (HTTPS requests to api.esv.org, operated by Crossway).

## Data Collected

| Data | Storage | Purpose | Retention |
|---|---|---|---|
| Selected verses and memorization status | Local SQLite (encrypted) | Core app function | Until user deletes app |
| Test session history (scores, timestamps) | Local SQLite (encrypted) | Progress review | Until user deletes app or clears data |
| Verse of the week selection | Local SQLite (encrypted) | Core app function | Until changed or app deleted |
| Custom verses entered by user | Local SQLite (encrypted) | Core app function | Until user deletes them or app |
| User preferences (audio, theme, translation, notification time, notification type, lock-screen toggle, auto-advance verse of the week and its last-advanced date) | SharedPreferences (local) | App configuration | Until user changes or uninstalls |
| Lookup consent flags (`bible_lookup_consent_v1`, `esv_lookup_consent_v1`) | SharedPreferences (local) | Records that the user agreed to send verse references to the named third party | Until user clears app data |
| Engagement log (date, event type, aggregate count) | Local SQLite (`engagement_log`) | Streak & activity history display | 90 days auto-purge; user-clearable via Settings → Activity History |
| Export file (JSON snapshot of above) | App internal storage (temporary) | User-initiated data transfer | Deleted immediately after share |
| ESV verse audio cache (MP3 files) | App cache dir (`getApplicationCacheDirectory()/esv_audio/`) | Audio playback for ESV verses | Evicted once cache exceeds 250 files (oldest first); also subject to OS cache eviction under storage pressure; excluded from Android Auto Backup |
| Other-app audio state (a single boolean: is any other app playing audio right now) | In-memory only — never written to SQLite, SharedPreferences, or logs | Decide whether to insert a memory verse into audio the user is already listening to | None — the boolean is discarded when the interval check returns; see Periodic Verse Playback below |

### engagement_log schema
- `date` — calendar date only (`YYYY-MM-DD`), no time component
- `event_type` — `'flashcard_tap'` or `'test_complete'`
- `count` — aggregate count per day per event type (no per-verse sequences)

**First-launch notice:** When `engagement_log` is introduced (DB migration to version 2), a one-time in-app dialog explains what is tracked and how to clear it. The flag `engagement_notice_shown` in `SharedPreferences` gates this dialog.

## Data NOT Collected
- No names, email addresses, or persistent account identifiers
- No device identifiers or advertising IDs
- No usage analytics or crash reporting
- No location data
- No audio recordings persisted to disk — see Voice Recitation (Recite Mode) below for ephemeral, on-device microphone use
- **No capture or analysis of other apps' audio.** Periodic verse playback asks the operating system a yes/no question — is audio playing — and receives a yes/no answer. It does not record, listen to, sample, or identify what is playing: not the app, not the track, not the content. No microphone access is involved, and none is requested for this feature
- No history of what the user was listening to, or of when other audio was detected — the signal is never logged or accumulated
- No automatic network requests; all network calls (verse lookup, pack import) are user-initiated and require prior consent

## Special Category Data (GDPR Art. 9)
Test history (which verses were studied, when, accuracy) combined with verse content constitutes a profile of religious practice. This data is stored locally. ESV verse lookups send a Bible reference — itself religious-practice data — to Crossway, a commercial third party, each time a lookup is performed. A DPIA assessment is required before enabling this feature for any user other than the app author. See ESV Verse Lookup section below.

## PII Assessment
No PII is collected or processed in normal operation. Verse text and references are not personal information. Notification time preference is a local setting with no identifying value.

## Voice Recitation (Recite Mode)

Recite-mode tests offer an **opt-in** microphone button as an alternative to typing or self-rating; typed/self-rated recite remains the default and is always fully functional without granting microphone access.

- **Permission:** `RECORD_AUDIO` is requested at point-of-use (when the mic button is tapped), never pre-granted or requested at app launch. Denial keeps the typed/self-rated recite flow fully usable; a permanently-denied result routes the user to system settings via an in-app dialog.
- **On-device only:** Speech recognition is forced to run on-device (`onDevice: true`); if the platform cannot recognize locally, the attempt fails outright rather than sending audio to a cloud recognizer. No recitation audio leaves the device.
- **Ephemeral transcripts:** The recognized transcript is held only in ephemeral widget state, scored immediately against the verse text using the same on-device LCS algorithm as typed answers, and discarded the moment scoring completes. The transcript is never written to the database, SharedPreferences, or logs, and the raw audio itself is never captured to a file.
- **Retention:** None — same ephemeral-state policy as typed test input (see Test Modes feature doc).

## Notification Settings

Users may configure a daily reminder notification (off by default). The notification body is always generic — no verse text or reference is included.

**Lock screen visibility** (`showOnLockScreen`) defaults to `false` (`NotificationVisibility.private`). The user may opt in to show notification content on the lock screen. This is opt-in because religious practice is GDPR Art. 9 adjacent — enabling this reveals to lock-screen bystanders that the user uses a Bible memorization app. An explicit bystander warning is shown in the settings UI.

## ESV Verse Lookup (Optional)

This feature is **off by default** and only appears in builds compiled with an ESV API key. Enabling it requires explicit, separate consent from the bible.helloao.org lookup.

- **What is transmitted:** The verse reference (e.g. "Romans 8:28") as a query parameter, the user's IP address, and an API key credential in the `Authorization` header
- **Destination:** `api.esv.org`, operated by Crossway (see [Crossway's Privacy Policy](https://www.crossway.org/privacy/))
- **Data processor:** Crossway, a commercial third-party data controller — not Google or any infrastructure already covered by other sections of this document
- **Storage cap:** Crossway's API terms permit storing at most 500 ESV verses locally. The app enforces this cap both as a pre-lookup advisory warning and as a hard block at save time, with an atomic database check to prevent double-save races
- **Consent record:** Stored locally under the `esv_lookup_consent_v1` preference key, isolated from the `bible_lookup_consent_v1` key used for bible.helloao.org — sharing keys would silently forward verse references to Crossway for users who only consented to the other provider
- **Encryption in transit:** HTTPS-only; cleartext is blocked at the OS level
- **Consent dialog disclosure:** Names `api.esv.org` as the recipient and states the 500-verse cap before the first ESV lookup fires

## ESV Audio Playback (Optional)

This feature plays the real Crossway recording for ESV verses during the text phase of audio playback; it only activates for verses already saved with translation `ESV` (i.e. after ESV Verse Lookup above has been used and consented to).

- **What is transmitted:** The verse reference and the user's IP address, sent twice across two requests — first to `api.esv.org` (with the `Authorization` API key header) to resolve the audio location, then to the CDN host (`audio.esv.org`) to fetch the MP3, **without** the API key header
- **Destination:** `api.esv.org` to resolve, `audio.esv.org` (Crossway's CDN) to fetch the recording; the CDN host is allowlisted in code so a redirect can never silently retarget another host
- **Data processor:** Crossway, same processor as ESV Verse Lookup
- **Consent record:** Reuses the `esv_lookup_consent_v1` preference key — by the time a user has ESV verses saved, they have already consented to send the same Bible reference to Crossway via text lookup, so a separate audio consent prompt is not shown
- **Local cache:** Fetched MP3s are cached on-device under `esv_audio/`, keyed by the SHA-256 hash of the lowercased, trimmed reference (never the raw reference string, to rule out path traversal). Capped at 250 files; oldest files are evicted first
- **Offline/error behavior:** Any cache or network failure falls back to on-device text-to-speech silently — no error is shown to the user, and no partial data is transmitted

## Periodic Verse Playback (Other-App Audio Detection)

Periodic verse playback is **off by default**. Once enabled, it plays a memorized verse at the configured interval. In its default trigger mode ("While other audio plays") it first checks whether another app is currently playing audio, so a verse lands inside an audiobook or podcast rather than out of silence; in "Anytime" mode no such check is performed at all.

- **What is read:** A single boolean from the Android `AudioManager` (`isMusicActive`), via a first-party platform channel (`bible_flashcards/system_audio`). It reveals only *whether* audio is playing — never which app, which track, or what content. Up to three samples are taken per interval check, spaced 300ms apart, so a brief gap between tracks does not read as silence
- **No permission required:** `isMusicActive` is an unprotected system query. This feature adds no Android permission — in particular it does not use, and cannot use, the microphone
- **Retention:** None. The boolean lives in a local variable for the duration of one interval check and is discarded when that check returns. It is never written to the database, SharedPreferences, or logs, and never transmitted
- **Audio focus:** While a verse plays, the app holds transient audio focus so the other app ducks and then resumes. This is a playback control, not a data flow — nothing is read from the other app
- **In-app disclosure:** The Settings row for the trigger mode states that the app checks whether another app is playing audio, and not what it is

### Why no first-enable notice is shown

The "Changes" clause below commits to an in-app notice for changes that introduce additional data collection. This feature does not meet that bar, and the judgment is recorded here so it need not be re-litigated:

1. **No permission is required** — nothing is requested of the user or the OS
2. **Nothing is persisted** — the boolean does not outlive the function call that read it
3. **Nothing is transmitted** — no network request is involved at any point
4. **Nothing is revealed beyond a yes/no** — the signal carries no information about what is playing

The feature is also opt-in and off by default, so no detection occurs until the user turns it on.

**Contrast with the two existing consent precedents.** Neither extends to this case, and the distinction is the reason:

- **`engagement_notice_shown`** (first-launch dialog) was triggered by data **persisted** to the database under a 90-day retention window — data a user could reasonably want to inspect or clear. Nothing is persisted here, so there is no data subject right to exercise over it: erasure, portability, and access are all vacuous for a boolean that no longer exists.
- **The ESV consent dialogs** were triggered by Art. 9 religious-practice data **transmitted to Crossway**, a third-party controller. There is no third party here and no transmission; the signal never leaves the process that read it.

A dialog for a discarded boolean would also dilute the two dialogs that guard real disclosures, which is the practical case against adding one.

## Permissions Used

| Permission | Reason |
|---|---|
| `FOREGROUND_SERVICE` | Background audio playback |
| `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Audio classification for Android media session |
| `POST_NOTIFICATIONS` (Android 13+) | Dismissible interruption notification and daily reminder |
| `SCHEDULE_EXACT_ALARM` | Daily reminder fires at the configured time (requires user consent via system Settings on API 31+; auto-granted below API 31) |
| `RECEIVE_BOOT_COMPLETED` | Re-registers the daily reminder alarm after device reboot or app update, via the plugin's `ScheduledNotificationBootReceiver` (not exported). Android clears scheduled alarms on reboot, so without this the reminder silently stops. No data is read, stored, or transmitted |
| `RECORD_AUDIO` | Optional mic button in recite-mode tests (on-device speech-to-text only); requested at point-of-use, not pre-granted; typed/self-rated recite works fully without it |
| `INTERNET` | Optional verse lookup/pack import; user-initiated, does not run without explicit consent |

`SCHEDULE_EXACT_ALARM` is only used for the daily reminder. Permission is requested at point-of-use; if denied, the user is shown a message directing them to system settings — the app does not degrade otherwise.

No camera, contacts, or storage permissions are requested.

## Network Requests

Verse lookup sends HTTPS requests to `bible.helloao.org` (a free public Bible API). ESV verse lookup, when available and enabled, sends HTTPS requests to `api.esv.org` (Crossway). ESV audio playback additionally sends HTTPS requests to `api.esv.org` and `audio.esv.org` (Crossway's CDN, allowlisted in code). No other external hosts are contacted.

- Requests are user-initiated (tap Search); the app never auto-fetches.
- The user's IP address is visible to the remote host (`bible.helloao.org`) for each request.
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
- `share_plus` — Android share sheet for export file; no data sent to the package author

None of these packages transmit data off-device in this configuration.

## Children
This app does not collect PII in its core functionality and is not directed at children under 13.

## Changes
Any future change that introduces additional data collection will require updating this document and displaying an in-app notice before the change takes effect.

## Contact
This is a personal-use app. For data subject requests (erasure, portability), use the in-app export feature.
