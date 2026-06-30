# Plan: ESV Text Lookup and Storage

**Issues:** #67

---

## Goal

Users can select ESV as a translation in the Add Verse screen, look up verse text from api.esv.org, and save ESV verses to the local database — with a hard 500-verse storage cap, a separate consent gate, and full test coverage.

---

## Context

The app fetches verse text from `bible.helloao.org` for BSB, KJV, and WEB. ESV requires a separate API (api.esv.org), its own API key (injected at build time via `--dart-define-from-file=secrets.local`), and a distinct consent flow naming Crossway as the data recipient. Crossway's terms cap local ESV storage at 500 verses; the cap must be enforced at both lookup time (advisory warning) and save time (hard block) with an atomic database check to prevent double-save races.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/services/esv_lookup_service.dart` | New: HTTP client for api.esv.org, auth header, SSRF guard, LRU cache, LookupException surface |
| `lib/screens/verses/add_verse_screen.dart` | Add ESV option, consent dialog, cap warning, cap save block, extract shared consent helper |
| `lib/providers/verse_provider.dart` | Add `esvVerseCount` getter |
| `lib/database/database_helper.dart` | Add `insertEsvVerse` with atomic count check inside transaction |
| `lib/models/settings.dart` | Validate `defaultTranslation` against allowlist in `fromMap` |
| `meta/PRIVACY.md` | Add api.esv.org as network recipient, Crossway privacy policy link, 500-verse cap disclosure, Art. 9 note |
| `test/services/esv_lookup_service_test.dart` | New: service unit tests |
| `test/providers/verse_provider_test.dart` | Add `esvVerseCount` tests |

### Steps

1. **`lib/services/esv_lookup_service.dart` — new service:**
   - `static const _apiKey = String.fromEnvironment('ESV_API_KEY');`
   - `static bool get isAvailable => _apiKey.isNotEmpty;` — callers check this before rendering the ESV option
   - Allowed host: `api.esv.org` (independent SSRF constant — do not share with `BibleLookupService`)
   - Request params: `include-passage-references=false`, `include-verse-numbers=false`, `include-footnotes=false`, `include-headings=false`, `include-short-copyright=false`
   - Response: JSON `passages[0]` is the plain text string; strip leading/trailing whitespace
   - Same 10-second timeout, `LookupException` surface, 50-entry LRU session cache keyed `reference|ESV`
   - Reuse `bookNameToUsfm` from `book_name_variants.dart` for reference parsing; construct `?q=<reference>` param (URL-encoded)

2. **`lib/providers/verse_provider.dart` — add getter:**
   ```dart
   int get esvVerseCount =>
       _verses.where((v) => v.translation == 'ESV').length;
   ```

3. **`lib/database/database_helper.dart` — atomic cap check:**
   Add `insertEsvVerse(Verse verse, {int cap = 500})` that wraps insert in a transaction:
   ```dart
   await db.transaction((txn) async {
     final rows = await txn.rawQuery(
       "SELECT COUNT(*) AS c FROM verses WHERE translation = 'ESV'",
     );
     final count = rows.first['c'] as int;
     if (count >= cap) throw const LookupException('ESV verse limit reached (500).');
     await txn.insert('verses', verse.toMap(),
         conflictAlgorithm: ConflictAlgorithm.ignore);
   });
   ```
   `VerseProvider.addCustomVerse` calls `insertEsvVerse` when `verse.translation == 'ESV'`.

4. **`lib/models/settings.dart` — allowlist `defaultTranslation`:**
   In `fromMap`, apply same pattern as `backupCadence`:
   ```dart
   const validTranslations = {'BSB', 'KJV', 'WEB', 'ESV'};
   final rawTranslation = map['default_translation'] as String? ?? 'ESV';
   final defaultTranslation = validTranslations.contains(rawTranslation)
       ? rawTranslation : 'ESV';
   ```

5. **`lib/screens/verses/add_verse_screen.dart` — UI changes:**

   **Translation picker:** Keep the `SegmentedButton` for BSB/KJV/WEB. Add ESV as a visually distinct row below — an `ActionChip` with a trailing `Symbols.info_rounded` icon and annotation text `"Personal use · 500-verse cap"`. Conditionally omit the ESV chip entirely when `!EsvLookupService.isAvailable` (misconfigured build guard).

   **Consent — extract shared helper:**
   ```dart
   Future<bool> _ensureConsentFor({
     required String prefsKey,
     required String title,
     required String body,
   }) async {
     final prefs = await SharedPreferences.getInstance();
     if (prefs.getBool(prefsKey) == true) return true;
     if (!mounted) return false;
     final agreed = await showDialog<bool>(
       context: context,
       barrierDismissible: false,
       builder: (ctx) => AlertDialog(
         title: Text(title),
         content: Text(body),
         actions: [
           TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
           FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Continue')),
         ],
       ),
     );
     _searchFocusNode.requestFocus();
     if (agreed == true) { await prefs.setBool(prefsKey, true); return true; }
     return false;
   }
   ```
   ESV consent key: `'esv_lookup_consent_v1'`. Dialog body names `api.esv.org`, states the verse reference is sent, and notes "ESV lookups are limited to 500 total stored verses by Crossway's API terms."

   **Cap warning (pre-lookup, advisory):** In `_lookupVerse()`, before the network call:
   ```dart
   if (_translation == 'ESV') {
     final count = context.read<VerseProvider>().esvVerseCount;
     if (count >= 500) {
       setState(() => _lookupError =
           'You have $count ESV verses stored (the maximum). '
           'Delete an ESV verse to add more.');
       return;
     }
   }
   ```
   Display using `cs.warningContainer`/`cs.onWarningContainer` tokens (NOT `errorContainer`) — this is an advisory, not a hard failure. Use an always-in-tree `Semantics(liveRegion: true)` node (same pattern as existing `_lookupError`).

   **Cap save-block:** In `_saveVerse()`, before calling `addCustomVerse`:
   ```dart
   if (_translation == 'ESV') {
     final count = context.read<VerseProvider>().esvVerseCount;
     if (count >= 500) {
       setState(() => _saveError =
           'ESV storage limit reached ($count/500). Delete an ESV verse to add more.');
       return;
     }
   }
   ```
   Renders in existing `_saveError` card slot with `errorContainer`.

   **A11y fixes (existing gaps, fix alongside):**
   - `_dismissPreview()` and `_acceptPreview()` must call `_searchFocusNode.requestFocus()` after clearing `_preview`.
   - Add `Icon(Symbols.error_rounded, size: 16)` to the `_lookupError` text row so color is not the sole error indicator.
   - Add `Icon(Symbols.error_rounded, size: 16)` to the `_saveError` card.

6. **`meta/PRIVACY.md` updates:**
   - Add `api.esv.org` (Crossway) to network recipients table; link to https://www.crossway.org/privacy/
   - Document what is sent: verse reference, IP address, API key credential in Authorization header
   - Add 500-verse cap note
   - Add Art. 9 note: verse study data sent to a commercial entity
   - Add `esv_lookup_consent_v1` to SharedPreferences data table

### Tests

`test/services/esv_lookup_service_test.dart` — follow `bible_lookup_service_test.dart` pattern:
- Success: returns `VerseLookupResult` with `translation == 'ESV'`
- HTTP 404 → `LookupException`
- Timeout → `LookupException('Request timed out...')`
- Bad JSON → `LookupException`
- Cache hit: second call returns without additional HTTP request
- Invalid reference format → `ArgumentError`
- Empty API key: `isAvailable` returns false

`test/providers/verse_provider_test.dart`:
- `esvVerseCount` is 0 when no ESV verses
- `esvVerseCount` counts only ESV-translation verses, ignores BSB/KJV/WEB

---

## Acceptance Criteria

- [ ] ESV appears as a distinct option below the BSB/KJV/WEB segmented button; annotated with "Personal use · 500-verse cap"
- [ ] ESV chip is hidden in builds without `ESV_API_KEY` set
- [ ] First ESV search triggers consent dialog naming api.esv.org; subsequent lookups skip it
- [ ] Successful ESV lookup shows preview card; accepted verse saves with `translation = 'ESV'`
- [ ] With 500 ESV verses stored: lookup shows warning (`warningContainer`) without making a network call
- [ ] Save button blocks with `errorContainer` error if cap reached at save time
- [ ] Error messages include current verse count
- [ ] BSB/KJV/WEB lookup behavior is unchanged
- [ ] `flutter test` passes; new tests cover all service and provider paths
- [ ] `meta/PRIVACY.md` updated with api.esv.org, Crossway privacy policy link, cap disclosure

---

## Pre-Implementation Review

**Security — HIGH: Empty API key guard.** `EsvLookupService.isAvailable` must be checked before rendering the ESV option. The service's `lookup` method must assert/throw if `_apiKey.isEmpty`.

**Security — HIGH: Consent key isolation.** ESV consent must use `'esv_lookup_consent_v1'` — never reuse `'bible_lookup_consent_v1'`. Sharing keys would silently forward verse references to Crossway for users who only consented to helloao.org.

**Security — MEDIUM: Atomic cap enforcement.** The `insertEsvVerse` transaction prevents double-insert races that could exceed the 500-verse Crossway ToS cap.

**Security — MEDIUM: API response defaults include headings/footnotes.** Pass all suppression parameters explicitly on every request or stored text will contain footnote markers that break LCS test scoring.

**Privacy — HIGH: Consent record quality.** Follow the Drive backup pattern: record `esv_consent_at` (ISO-8601) and `esv_consent_version` in `AppSettings` for GDPR Art. 7(1) demonstrability. (The SharedPreferences boolean is acceptable for helloao.org; Crossway is a commercial data controller.)

**Privacy — MEDIUM: Consent dialog must disclose the 500-verse cap** per GDPR transparency requirements.

**A11y — BLOCKER: Focus after preview dismiss/accept.** Both `_dismissPreview` and `_acceptPreview` must call `_searchFocusNode.requestFocus()` after clearing the preview node from the tree.

**A11y — BLOCKER: Cap warning liveRegion.** The warning must live in an always-in-tree `Semantics(liveRegion: true)` node (same pattern as `_lookupError` at line 229), or TalkBack will miss it.

**A11y — MAJOR: Error color-only indicators.** Add `Symbols.error_rounded` icon to both `_lookupError` text and `_saveError` card.

**Design — MAJOR: ESV not a peer segment.** ESV carries asymmetric constraints (consent + cap) that BSB/KJV/WEB do not. It must be presented as a distinct annotated row, not a fourth `ButtonSegment`.

**Design — MAJOR: Cap advisory uses `warningContainer`.** Pre-lookup advisory is a warning, not an error. Use `cs.warningContainer`/`cs.onWarningContainer`. Save-block uses `errorContainer` (hard failure).

**Design — MAJOR: Shared consent helper.** Extract `_ensureConsentFor(...)` to prevent the two consent dialogs drifting over time.
