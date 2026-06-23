# Web Lookup

## Summary
Lets users auto-fill verse text on the Add Verse screen by typing a reference and tapping Search. The app fetches the verse from `bible.helloao.org` over HTTPS. A first-use consent dialog fires before any network call; the user previews the result before it is applied to the form.

## Users / Use Cases
- **User (Add Verse screen)**: Types a reference (e.g. "Romans 8:28"), selects a translation (BSB/KJV/WEB), taps Search. Sees a preview card with Accept/Dismiss actions. On Accept the reference and text fields are populated. Can still edit manually before saving.

## Technologies
- `http` (Dart package) — HTTP client; injected via constructor for testability
- `shared_preferences` — persists first-use consent flag (`bible_lookup_consent_v1`)
- `network_security_config.xml` — OS-level cleartext block (Android)

## Technical Overview
`BibleLookupService` is the sole HTTP client. It validates the reference string against a regex, parses it into USFM book code + chapter + verse range, constructs a URL of the form `https://bible.helloao.org/api/{translationId}/{bookUsfm}/{chapter}.json`, and extracts matching verse rows from the JSON response. SSRF is prevented by asserting `scheme == https` and `host == bible.helloao.org` on every constructed URI. A 50-entry LRU-style in-memory cache (keyed `reference|translation`) bounds memory per screen instance and is cleared when the screen is disposed. The service is created and owned by `_AddVerseScreenState`; `dispose()` closes the HTTP client.

The Add Verse screen owns the full lookup flow: consent check → loading state → preview card → Accept/Dismiss → form population.

`DatabaseHelper.importPackFromJson` (separate concern on the same branch) provides a transactional batch import path for JSON packs, with per-field validation and `ConflictAlgorithm.ignore`.

## API Endpoints
| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `https://bible.helloao.org/api/{translationId}/{bookUsfm}/{chapter}.json` | None | Returns chapter JSON with `verses` array; each entry has `verse` (int) and `text` (string) |

Translation IDs: `BSB` → `BSB`, `KJV` → `eng_kjv`, `WEB` → `ENGWEBP`.

## Key Files
| File | Purpose |
|---|---|
| `lib/services/bible_lookup_service.dart` | HTTP fetch, reference parsing, USFM map, SSRF guard, session cache |
| `lib/screens/verses/add_verse_screen.dart` | UI: consent dialog, loading/preview/error states, form population |
| `lib/database/database_helper.dart` | `importPackFromJson` — batch JSON pack import with field validation |
| `android/app/src/main/AndroidManifest.xml` | `INTERNET` permission + `networkSecurityConfig` attribute |
| `android/app/src/main/res/xml/network_security_config.xml` | Blocks cleartext; trusts system CA only |
| `meta/PRIVACY.md` | Documents network requests, consent, IP disclosure, HTTPS-only policy |

## Technical Detail

### Reference parsing
Pattern: `^(.+?)\s+(\d+):(\d+)(?:-(\d+))?\s*$` — captures book name, chapter, start verse, optional end verse. Book name is lowercased and stripped of spaces/dots then looked up in a 150-entry static map of common abbreviations to USFM codes (full OT + NT coverage). Unknown book → `LookupException`.

### Consent flow
`_ensureConsent()` reads `bible_lookup_consent_v1` from `SharedPreferences`. If absent, shows a blocking `AlertDialog` naming `bible.helloao.org` and explaining IP visibility. On Continue, persists `true` and proceeds. On Cancel, aborts the lookup. Focus returns to the Search button after the dialog closes.

### Error handling
- `TimeoutException` (10 s deadline) → user-facing "Request timed out" message
- HTTP 404 → "Verse not found"
- Other non-200 → "Lookup failed (statusCode)"
- Bad JSON / missing verses → "Could not read response"
- All errors displayed inline below the reference field via an always-present `Semantics(liveRegion: true)` node so screen readers announce changes.

### Preview card
Rendered in `cs.secondaryContainer`. Has a `Semantics` wrapper with a full spoken description and a `FocusNode` that is requested programmatically on lookup success so keyboard/TalkBack users land on the preview automatically.

### importPackFromJson
Accepts `{ "verses": [...] }`. Per-row field validation: all five fields (`id`, `reference`, `text`, `translation`, `pack_id`) must be non-null non-empty strings; `reference` max 100 chars, `text` max 2000 chars, `id`/`translation`/`pack_id` within their column limits. Rows failing validation or causing a unique conflict are silently skipped. Returns count of successfully inserted rows. Wrapped in a single `db.transaction` for atomicity.

### Security notes
- SSRF: `_assertHttps` checks both scheme and host on every URI; any deviation throws `StateError` before a request fires.
- Cleartext: blocked at both the application layer (service assertion) and OS layer (`network_security_config.xml`).
- No verse reference or user input is written to any log.
- Cache key is never surfaced outside the service instance.
