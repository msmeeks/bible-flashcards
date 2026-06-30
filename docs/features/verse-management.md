# Verse Management

## Summary
Verse management covers the full lifecycle of a verse: pre-loaded Navigator memory packs, selecting the current verse of the week, tracking memorized verses, and adding custom verses. It is the foundation all other features build on.

## Users / Use Cases
- **Solo user**: browses available verses from packs, designates one as the verse of the week, marks verses as memorized, and optionally adds verses not in any pack.

## Technologies
- `sqflite_sqlcipher` — encrypted SQLite; key generated per-install and stored in Android Keystore via `flutter_secure_storage`
- JSON asset files — source of truth for Navigator pack content at install time
- Provider — `VerseProvider` exposes verse state to all screens

## Technical Overview
On first launch, the app seeds the SQLite database from bundled JSON pack assets. `DatabaseHelper` is a singleton that initialises the cipher key from Android Keystore on every open. Each verse row tracks: reference, text (all three versions), pack membership, memorized flag, memorized date, and a flag for whether it is the active verse-of-the-week. The UI exposes two primary lists and an add flow via named routes.

## Key Files
| File | Purpose |
|---|---|
| `assets/packs/navigators_pack.json` | Navigator TMS pack definitions (id, name, verses with reference/text/translation) |
| `lib/database/database_helper.dart` | Singleton; opens encrypted DB, runs migrations, exposes `getPackNames()` |
| `lib/models/verse.dart` | Verse domain model |
| `lib/models/verse_pack.dart` | VersePack model; `toMap`/`fromMap` serialize `verseIds` as JSON array |
| `lib/widgets/verse_card.dart` | `VerseCard` StatefulWidget + `FlashcardState` enum |
| `lib/screens/home/home_screen.dart` | Verse-of-week card, quick-action buttons, recent memorized chips |
| `lib/screens/verses/verse_detail_screen.dart` | Full verse display; renders VerseCard in `FlashcardState.both`; shows pack name |
| `lib/providers/verse_provider.dart` | Provider; exposes lists, current verse, `packNames` map, mutation methods |
| `lib/widgets/inline_status_banner.dart` | Shared `InlineStatusBanner` widget (error/warning, live-region announce) used by Add Verse's lookup-error/cap-warning/save-error banners |

## Technical Detail

### Encryption
`DatabaseHelper` calls `flutter_secure_storage` to read (or generate and store) a random 256-bit key on each DB open. The key never leaves the Keystore-backed secure element. `android:allowBackup="false"` in the manifest prevents the encrypted DB from appearing in cloud or ADB backups.

### Screen Structure and Routes
| Route | Screen | Description |
|---|---|---|
| `/` | `HomeScreen` | Verse-of-week card, quick actions, recent memorized chips |
| `/verses` | `VersesScreen` | TabBar: Memorized \| Available, search field |
| `/verses/add` | `AddVerseScreen` | Form to add a custom verse |
| `/verses/detail` | `VerseDetailScreen` | VerseCard (expanded) + translation picker + metadata + actions |

### VerseCard and FlashcardState
`VerseCard` (`lib/widgets/verse_card.dart`) is a `StatefulWidget`. It holds a `FlashcardState` and cycles through three states on each tap:

| State | Shows |
|---|---|
| `referenceOnly` | Reference + status chip only |
| `textOnly` | Verse text + translation label only |
| `both` | Reference, status chip, text, and translation label |

Cycle order: `referenceOnly` → `textOnly` → `both` → `referenceOnly`. An `expand_more` icon button (excluded from semantics) jumps directly to `both` from any partial state. `AnimatedSize` wraps the content; disabled when `MediaQuery.disableAnimations` is true to avoid a layout assertion in test mode.

`initialState` defaults to `referenceOnly`. `VerseDetailScreen` passes `FlashcardState.both` so the card opens fully expanded.

Accessibility: the card carries `Semantics(button: true)` with a human-readable label describing current state and what tapping will do. A `Semantics(liveRegion: true)` sibling node announces state changes to TalkBack separately from the button role.

### Pack Names (DB version 2)
The `packs` table (added in DB version 2) stores `id`, `name`, `description`, and `verse_ids` (JSON-encoded array). `DatabaseHelper.getPackNames()` returns `Map<String, String>` (id → name). `VerseProvider.loadVerses()` populates `packNames` from this call. `VerseDetailScreen._MetadataCard` reads `provider.packNames[verse.packId]` to display a human-readable pack name.

`_onUpgrade` (old < 2): creates the `packs` table inside a transaction, then seeds it from `assets/packs/navigators_pack.json` using `ConflictAlgorithm.ignore`.

### VersePack.toMap / fromMap
`verse_ids` column is stored as a JSON array string (`jsonEncode`/`jsonDecode`). Prior to DB version 2 this was CSV — any migration path must account for the format change.

### Accessibility — "Verse of the Week" heading
Both branches of `_VerseOfWeekSection` (verse present and verse absent) wrap the "Verse of the Week" heading `Text` in `Semantics(header: true)` so screen readers treat it as a section heading.

### Lists
- **Available verses**: all pack verses not yet memorized, grouped by pack/topic.
- **Memorized verses**: verses marked memorized, sorted by memorized date descending.

### Verse of the Week
Exactly one verse is flagged `is_verse_of_week = 1` at any time. Setting a new verse of the week clears the previous flag. The current verse is surfaced prominently on the home screen.

### Auto-Advance Verse of the Week
When `AppSettings.autoAdvanceVerseOfWeek` is enabled (Settings toggle, default off), `HomeScreen.initState` calls `VerseProvider.autoAdvanceVerseOfWeekIfNeeded(settings, onUpdate)` after the post-frame verse load. The decision logic lives in `VerseProvider.pickVerseForAutoAdvance` (`@visibleForTesting`), kept separate from the DB write so it's unit-testable without a real database: it returns null unless today is Sunday and the current ISO week hasn't already advanced, then picks a random non-current verse. `AppSettings.lastVerseAdvanceDate` persists through `SettingsProvider` (and therefore export/import and Drive backup) so the ISO-week guard survives app restarts; `AppSettings.fromMap` rejects far-future values as a tamper guard, matching `lastBackupAt`. ISO-week comparison is done by Monday-of-week equality, which correctly handles the Dec/Jan year boundary.

### Adding Custom Verses
Users can enter a reference and text manually. Custom verses are stored in the same table with no pack membership. Bible version must be specified at entry. `insertVerse` uses `ConflictAlgorithm.ignore` so duplicate inserts are silently dropped (same behaviour as seed inserts). `VerseProvider.addCustomVerse` routes to `DatabaseHelper.insertEsvVerse` when `translation == 'ESV'`, else to `insertVerse` (see "ESV Verse Lookup" below).

### ESV Verse Lookup
Mirrors the `BibleLookupService` pattern (`docs/features/web-lookup.md`) but targets `api.esv.org` (Crossway's ESV API) instead of `bible.helloao.org`, and is gated by an API key plus a hard 500-verse storage cap per Crossway's API terms.

`EsvLookupService` (`lib/services/esv_lookup_service.dart`) authenticates via `Authorization: Token <key>` header; the key comes from `String.fromEnvironment('ESV_API_KEY')`, injected at build time via `--dart-define-from-file=secrets.local`. The instance-level `isAvailable` getter reflects whether the key is non-empty — the UI hides the ESV option entirely when false, since there is no key to fall back on. A static `EsvLookupService.isApiKeyConfigured` getter does the same compile-time check (`String.fromEnvironment('ESV_API_KEY').isNotEmpty`) without needing an instance/`http.Client` — use this in screens (e.g. Settings) that must gate UI before constructing the service. Reference parsing reuses the shared `bookNameToUsfm`/`bookDisplayNames` table from `lib/utils/book_name_variants.dart` (same source as `BibleLookupService`). SSRF guard now delegates to the shared `assertAllowedHttpsHost` helper in `lib/services/net_security.dart` (see "Shared HTTPS host allowlist" below); 50-entry LRU cache, 10s timeout, and `LookupException` error surface (timeout / 404 / non-200 / bad JSON) all match `BibleLookupService` exactly.

Storage enforces the 500-verse cap server-side of the app, not just in the UI: `DatabaseHelper.insertEsvVerse(Verse verse, {int cap = 500})` runs a single transaction that counts existing rows where `translation = 'ESV'` and throws `EsvVerseCapExceededException` (defined in `database_helper.dart`, not the service layer) if at cap *before* inserting — so a race between two concurrent adds can't push the count over. `VerseProvider.esvVerseCount` exposes the live count for UI checks.

On the Add Verse screen, ESV is now a 4th `ButtonSegment` in the same `SegmentedButton<String>` as BSB/KJV/WEB (gated behind `EsvLookupService.isAvailable`), not a separate `ActionChip` — the old chip duplicated the segmented control and embedded the usage note inside a tappable element (#88). The "ESV · Personal use · 500-verse cap" note is now a static caption `Text` below the `SegmentedButton`, shown only when ESV is both available and currently selected. Consent is isolated from the bible.helloao.org flow: a separate key `esv_lookup_consent_v1` (vs. `bible_lookup_consent_v1`) and its own dialog naming `api.esv.org` and disclosing the cap. Before firing a lookup, the screen checks `esvVerseCount >= 500` and shows a non-blocking advisory without making a network call; a second check at save time blocks if the cap was reached in the meantime. `AppSettings.fromMap` (`lib/models/settings.dart`) validates `defaultTranslation` against an allowlist (`BSB`, `KJV`, `WEB`, `ESV`), falling back to `ESV` for unrecognized/tampered values — same pattern used for `backupCadence`.

The lookup-error, cap-warning, and save-error banners on this screen (previously three near-identical inline `Semantics(liveRegion: true) + Card/Padding + Icon + Text` blocks) are now all instances of the shared `InlineStatusBanner` widget (`lib/widgets/inline_status_banner.dart`, #86) — see "Shared Inline Status Banner" below.

`meta/PRIVACY.md` documents api.esv.org/Crossway as a data recipient under its own section.

### Shared Inline Status Banner
`InlineStatusBanner` (`lib/widgets/inline_status_banner.dart`) replaces three duplicated error/warning banner blocks formerly inline in `add_verse_screen.dart` (#86). Takes `severity` (`BannerSeverity.error`/`.warning`), a nullable `message`, and `filled` (default `true`). Renders nothing when `message` is null but always wraps content in `Semantics(liveRegion: true, label: message ?? '')` so the node stays in the tree and screen readers announce the transition when the message changes — the same "always present, empty label when absent" pattern the old inline blocks used. `filled: true` renders on a tinted `Card` surface (cap-warning, save-error); `filled: false` renders bare (lookup-error, which was never `Card`-backed).

### Shared HTTPS Host Allowlist
`assertAllowedHttpsHost(Uri uri, Set<String> allowedHosts)` (`lib/services/net_security.dart`) is the single SSRF guard used by every outbound HTTP service — `BibleLookupService`, `EsvLookupService`, and `EsvAudioCacheService` (see `docs/features/audio.md`) all call it instead of duplicating inline scheme/host checks. It throws `StateError` on a non-HTTPS scheme or a host outside the allowlist; callers that need a different exception type (e.g. `EsvAudioCacheService`) catch the `StateError` and rethrow as their own type. `DatabaseHelper` no longer imports any service-layer exception type — `insertEsvVerse` throws its own `EsvVerseCapExceededException`, fixing a prior layering inversion where the DB layer reused a service-layer `LookupException`.

### ESV Attribution
Add Verse and Verse Detail render `EsvCopyrightFooter` when the relevant verse is ESV — Add Verse shows it in the save-confirmation dialog once an ESV preview is loaded; Verse Detail shows it whenever the displayed verse's translation is ESV. See `docs/features/esv-attribution.md` for the shared widget.

### Default Translation Setting
Settings has a "Default translation" control (`SegmentedButton`) under a "Verses" section, wired to `AppSettings.defaultTranslation`. The ESV segment is included only when `EsvLookupService.isApiKeyConfigured` is true (#73 fix — previously the segment always rendered regardless of whether a key was configured, including in the open-source/no-key build). When the stored preference is `'ESV'` but no key is configured, the screen displays `'BSB'` as the effective selection without overwriting the saved preference — same fallback `add_verse_screen.dart` already used. The "ESV is for personal, non-commercial use only." notice only shows when ESV is actually selected/available, not merely stored as the preference. Its `liveRegion` is driven by `AnnounceOnChange` (see `docs/features/esv-attribution.md`), keyed on whether ESV is the effective selection, so opening Settings with ESV already selected doesn't trigger a spurious announcement — only an actual change does.

The `SegmentedButton` sets `showSelectedIcon: false` and `style: SegmentedButton.styleFrom(minimumSize: const Size(0, 48))` (#84) so each segment meets the 48dp minimum touch target, mirroring the existing `DataManagementScreen` Backup Frequency control's sizing pattern. **Known issue (untracked):** the adjacent "Notification type" `ListTile` in `settings_screen.dart` overflows at 375px width — trailing widget consumes the full tile width — discovered as a side effect of this fix but out of scope; no GitHub issue or `meta/plans/` entry exists for it yet, only a note in `meta/plans/progress.md`.

### Unmarking a Memorized Verse
`VerseProvider.unmarkMemorized(id)` sets `isMemorized: false` and clears `memorizedAt`, then delegates to `DatabaseHelper.unmarkMemorizedVerse()`. That method runs a single SQLite transaction that:
1. Updates the verse row (clears memorized flag and date).
2. Deletes all `test_results` rows for that verse.

The atomic transaction satisfies GDPR data-erasure semantics — partial updates cannot leave orphaned test history. `VerseDetailScreen` wires the "Remove from Memorized" button to this call; previously the button existed in the UI but had no effect.

### Selecting Next Verse
From the available list, tapping a verse and confirming sets it as the verse of the week. It does not automatically mark the previous one as memorized — the user does that explicitly.

## Changelog
| Date | Change |
|---|---|
| 2026-05-27 | Initial documentation |
| 2026-06-26 | Auto-advance verse of the week (#45) |
| 2026-05-27 | Updated with full implementation: encryption details, DatabaseHelper singleton, screen/route table, Provider integration |
| 2026-06-10 | Bug fixes: unmarkMemorized() wired end-to-end (VerseDetailScreen → VerseProvider → DatabaseHelper atomic txn + test-history purge); insertVerse ConflictAlgorithm.ignore |
| 2026-06-12 | FlashcardState enum + VerseCard 3-state tap cycle; pack names via DB v2 packs table + getPackNames(); VersePack verseIds now JSON (was CSV); Semantics(header: true) on heading; VerseDetailScreen uses FlashcardState.both; corrected key file paths |
| 2026-06-26 | ESV verse lookup (#67): EsvLookupService (api.esv.org, key-gated, 500-verse cap), DatabaseHelper.insertEsvVerse atomic cap check, VerseProvider.esvVerseCount + addCustomVerse routing, AppSettings defaultTranslation allowlist, Add Verse screen ESV chip + isolated consent flow |
| 2026-06-26 | Default translation setting (#69): Settings "Verses" section with BSB/KJV/WEB/ESV SegmentedButton + personal-use notice; Add Verse screen initializes from the setting with ESV→BSB fallback when no API key |
| 2026-06-26 | Wired `EsvCopyrightFooter` into Add Verse (save dialog) and Verse Detail screens (#68) |
| 2026-06-26 | Internal hardening (#72, #74, #76): extracted shared `assertAllowedHttpsHost` SSRF guard (`lib/services/net_security.dart`) used by `EsvLookupService` and other HTTP services; `DatabaseHelper.insertEsvVerse` now throws DB-owned `EsvVerseCapExceededException` instead of reusing service-layer `LookupException`, removing the DB→service import |
| 2026-06-26 | Translation selection consistency fixes (#73, #77, #88): added static `EsvLookupService.isApiKeyConfigured`; Settings "Default translation" gates the ESV segment on it and falls back to displaying BSB (without overwriting the stored preference) when ESV is saved but no key is configured; Add Verse screen's separate ESV `ActionChip` replaced with a 4th `SegmentedButton` segment, usage note moved to a static caption below the control |
| 2026-06-30 | Add Verse UI accessibility polish (#84, #86, #90): Settings "Default translation" `SegmentedButton` now meets 48dp touch target (`showSelectedIcon: false` + `minimumSize`); Add Verse's three duplicated error/warning banners extracted into shared `InlineStatusBanner` widget; #85 (non-color ESV selection indicator) and #89 (ESV footer in AlertDialog) verified already resolved by prior commits, regression tests added; flagged untracked 375px overflow bug on Settings "Notification type" tile |
