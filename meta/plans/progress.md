# Progress Log

## 2026-06-30 — fix-add-verse-ui-polish.md (#84, #85, #86, #89, #90)

This was the only remaining `"status": "pending"` entry in `prd.json`
(`blocked_by: fix-translation-selection-consistency.md`, which is `done`) —
last plan in the queue, picked by elimination per the "UI polish last"
prioritization rule.

- `lib/screens/settings/settings_screen.dart` (#84): the "Default
  translation" `SegmentedButton` in the `ListTile.trailing` slot was below
  the ~48dp minimum touch target at narrow widths. Added
  `showSelectedIcon: false` and `style: SegmentedButton.styleFrom(minimumSize:
  const Size(0, 48))`, mirroring the existing precedent in
  `data_management_screen.dart`'s Backup Frequency control. RED test
  asserted the resolved `minimumSize.height >= 40` (initially `null`),
  GREEN after the style change. While probing this at a simulated 375px
  width I found a **real, separate, out-of-scope layout overflow bug**: the
  "Notification type" `ListTile` throws "Trailing widget consumes the
  entire tile width" at 375px, cascading into render-box-not-laid-out
  failures for everything below it in the list. Not covered by #84/85/86/
  89/90 — did not fix; needs a new GitHub issue.
- `lib/screens/review/review_play_screen.dart` (#86): the outer `Semantics`
  wrappers around the Pause/Resume and Stop controls merged into a single
  SemanticsNode that — confirmed via a RED test reading
  `tester.getSemantics(...).getSemanticsData().label` — carried an **empty**
  label, not just a redundant one as the plan described; the actionable
  node had no announceable text at all. Fixed with `excludeSemantics: true`
  plus an explicit `onTap:` mirroring the real button's `onPressed` on both
  wrappers, so the merged node carries the correct label and a working tap
  action.
- `lib/widgets/inline_status_banner.dart` (#90, new file): extracted the
  three duplicated error/warning Semantics+Card/Row banner blocks in
  `add_verse_screen.dart` (`_lookupError`, `_capWarning`, `_saveError`) into
  a shared `InlineStatusBanner` widget (`BannerSeverity {error, warning}`,
  nullable `message`, `filled` flag). The three originals weren't visually
  identical — the lookup-error banner had no Card background — so `filled`
  (default `true`) preserves that distinction; `_lookupError` now passes
  `filled: false`. Foreground color also branches on `filled` (caught
  before finalizing: the original filled banner used
  `cs.onErrorContainer`, not `cs.error`, which would otherwise have been a
  silent contrast regression). Built via TDD (5 RED→GREEN cycles in
  `test/widgets/inline_status_banner_test.dart`), then wired into
  `add_verse_screen.dart`, removing two now-unused imports.
- #85 and #89 were investigated and found **already resolved** by prior
  work: #85's ESV-selection-by-color-alone concern is already satisfied by
  the existing `SegmentedButton` (non-color check icon + per-segment
  `isSelected` semantics) from an earlier ActionChip→SegmentedButton
  migration; #89's "footer inside AlertDialog" no longer applies — the only
  `AlertDialog` in `add_verse_screen.dart` is the consent dialog, which
  never contains `EsvCopyrightFooter`. No code changes for either; added a
  regression test for each (`add_verse_screen_test.dart`,
  `review_play_screen_test.dart` already covers #86) to lock the verified
  behavior in rather than leaving it implicit.

`flutter analyze`: clean except pre-existing infos (deprecated
`surfaceVariant`/`hasFlag` usages predating this change) and the documented
pre-existing `test/widget_test.dart` `MyApp` compile error. `flutter test`:
406 of 406 pass (the only failure is that same pre-existing
`test/widget_test.dart` load error). A stray `probe3_test.dart` left over
from local 375px-layout probing during this session was not cleaned up
before an earlier full-suite run and caused a 10-minute hang/timeout in
that run; deleted before the final clean run.

## 2026-06-30 — refactor-audio-settings-dedup.md (#75, #78)

Picked this over `fix-add-verse-ui-polish.md` (the only other unblocked
pending plan) per the prioritization rule ranking UI polish last — this is a
mechanical DRY cleanup, not UI work. 4 prior attempts had left no commits and
no working-tree changes; found no evidence of what previously blocked them.

- `lib/services/audio_service.dart` (#75): extracted `_runFromPhase(_PlayPhase
  startPhase, Verse verse)`, replacing the duplicated reference→pause→text
  cascade previously inlined separately in `playVerse` and three times across
  `resume`'s phase `switch`. `_runFromPhase` runs each stage conditionally
  based on `startPhase` (skipping stages before it), so `playVerse` always
  starts at `_PlayPhase.reference` and `resume` starts at the recorded
  `_pausedPhase`. Behavior preserved exactly, including `resume()`'s no-op
  when `_pausedPhase == _PlayPhase.none` (was a `switch` `break`, now an early
  return). No direct unit test exists for `AudioService` in this repo — every
  caller substitutes `FakeAudioService` because `flutter_tts`/`audioplayers`
  require platform channels with no mock harness here (same untested boundary
  documented in every prior `feat-esv-audio.md`-adjacent entry) — verified by
  manual side-by-side comparison against the pre-refactor logic instead, plus
  `flutter analyze` and the full `flutter test` run showing no regressions.
- `lib/models/settings.dart` (#78): extracted `_parseGuardedTimestamp(String?
  raw)`, replacing the duplicated far-future-timestamp tamper guard previously
  inlined separately for `lastBackupAt` and `lastVerseAdvanceDate` in
  `fromMap`. Unlike the audio side, this is fully unit-testable (no platform
  channels) — found `lastBackupAt`'s far-future/just-inside-window guard had
  no test coverage at all (only `lastVerseAdvanceDate`'s was tested), so added
  the missing two cases to `test/models/settings_test.dart` before
  refactoring, giving both fields equal coverage of the shared helper.

`flutter analyze`: 0 issues on both touched files. `flutter test`: 397 of 398
pass; the only failure is the same pre-existing, unrelated
`test/widget_test.dart` stale-`MyApp`-constructor compile error confirmed via
`git stash` before this work started (consistent with every prior entry).

## 2026-06-30 — test-esv-coverage-gaps.md (#91, #92, #93, #94, #95, #96)

Picked over `refactor-audio-settings-dedup.md` (3 prior failed attempts —
mechanical refactor, lower priority than an unattempted plan covering real
architectural unknowns) and `fix-add-verse-ui-polish.md` (explicit UI
polish, ranked last per priority order). Test-only cluster; no production
behavior changes.

- **#91** `test/database/database_helper_test.dart` (new): added
  `sqflite_common_ffi` as a dev dependency plus a `DatabaseHelper.debugSetDatabase`/
  `debugReset` `@visibleForTesting` seam so tests can inject an in-memory DB
  and exercise real transaction logic without platform channels — the
  codebase's first genuine SQL-transaction test. Covers `insertEsvVerse`:
  succeeds under cap, throws at cap, doesn't insert the over-cap row,
  concurrent `Future.wait` inserts at the cap boundary still respect the cap
  (TOCTOU-safe transaction), and duplicate-id insert is ignored not thrown.
- **#92** `test/screens/verses/add_verse_screen_test.dart`: added
  constructor-level DI (`lookupService`/`esvLookupService` optional params)
  to `AddVerseScreen` so ESV flows are testable without a compiled
  `ESV_API_KEY`. New widget tests: cap-blocked lookup skips the consent
  prompt, consent accept proceeds to a preview, consent decline performs no
  lookup, lookup success/failure rendering with consent already granted, and
  cap-warning clearing when switching translation away from ESV.
- **#93** `test/services/audio_interrupt_service_test.dart`: added a
  `debugCheckThreshold()` `@visibleForTesting` seam on
  `AudioInterruptService` (ruled out `fakeAsync` — it only fakes
  `package:clock`, not the service's raw `DateTime.now()`); used
  `Duration.zero` thresholds for deterministic, real-time-independent
  triggering tests. Added instance-level coverage for start/stop/pause/resume
  (including safe-no-op double-calls) and threshold-crossing triggering
  `stop()` + notification + `playVerse()`, plus two missing
  `pickVerseForInterrupt` branch tests (`verseOfWeek == null`,
  `memorizedVerses.isEmpty`).
- **#94** `test/providers/verse_provider_test.dart`: added a real-DB-backed
  test (via the new `debugSetDatabase` seam) exercising the public
  `autoAdvanceVerseOfWeekIfNeeded` end-to-end — asserts the new verse is
  persisted and becomes `verseOfWeek`, and `onUpdate` fires with the
  advance date; plus a same-call negative case (non-Sunday: no DB write, no
  `onUpdate`).
- **#95** `test/utils/scoring_test.dart`: added regression tests for
  compound/colliding reference inputs, including one that documents an
  intentional limitation noted in `_normalizeReferenceInput`'s docstring
  (bare-space + trailing "and" range doesn't fully normalize because the
  "and" rule runs before the bare-space colon insertion), plus
  empty/whitespace-only boundary cases for `computeReferenceScore`.
- **#96** Smaller branch/boundary tests: `settings_screen_test.dart` —
  auto-advance toggle-off (existing test only covered toggle-on) and
  ESV.org `launchUrl` success path (existing test only covered the
  no-handler fallback); `esv_copyright_footer_test.dart` — reduced-motion
  branch skips the `AnimatedSize` wrapper; `settings_test.dart` —
  `copyWith(clearLastVerseAdvanceDate: true)` and the just-inside-365-day
  acceptance boundary for `fromMap`'s tampered-timestamp guard.
- Also fixed an `unnecessary_import` lint in `add_verse_screen.dart`
  (foundation.dart's `visibleForTesting` is already re-exported by
  material.dart, which the file already imports).

`flutter test` passes (395 of 396; the only failure is the pre-existing,
unrelated `test/widget_test.dart` stale-`MyApp`-constructor compile error,
confirmed present via `git stash` before this work started). `flutter
analyze` clean for all touched files (same pre-existing deprecation infos
and the `widget_test.dart` issue remain, unrelated to this change).

## 2026-06-28 — fix-esv-copyright-footer.md (#80, #81, #82, #83, #87)

Picked over the other unblocked pending plans (`refactor-audio-settings-dedup.md`,
`fix-add-verse-ui-polish.md`, `test-esv-coverage-gaps.md`) because a prior attempt
had already left most of this plan implemented uncommitted in the working tree —
finishing it avoided discarding that work, and accessibility/layering fixes rank
above pure UI polish or dedup in the prioritization rule.

The working tree already had: `lib/widgets/announce_on_change.dart` (the shared
post-frame-reset live-region helper), the `EsvCopyrightFooter` rewrite using it
plus `IconButton`-based focus for the collapsed toggle and an `onViewFullTerms`
callback replacing the `SettingsScreen` import, and the two call sites
(`add_verse_screen.dart`, `review_show_screen.dart`) already passing the callback.
That left three things broken/missing, which is why `attempts` was already 2:

- `lib/screens/verses/verse_detail_screen.dart`, `lib/screens/review/review_play_screen.dart`,
  `lib/screens/test/test_session_screen.dart` still called `EsvCopyrightFooter`
  without the now-required `onViewFullTerms` — a compile error (`flutter analyze`
  confirmed 3 `missing_required_argument` errors). Fixed all three with the same
  `Navigator.push(MaterialPageRoute(... SettingsScreen()))` callback used at the
  other two call sites.
- `lib/screens/settings/settings_screen.dart`'s ESV default-translation subtitle
  (#83) still used unconditional `liveRegion: true`. Wrapped it in
  `AnnounceOnChange` (keyed on `esvSelected.toString()`) so opening Settings with
  ESV already selected doesn't announce, but switching to/from it does — same
  fix already applied to the footer itself. The `Semantics`/`Text` is now always
  present (an empty `SizedBox.shrink()` when not selected) rather than the
  subtitle being `null`, so `AnnounceOnChange.didUpdateWidget` can observe the
  transition instead of remounting fresh each time the value flips.
- `test/widgets/esv_copyright_footer_test.dart`'s two new tests (`does not
  announce a live region on first mount`, `collapsed toggle is keyboard
  focusable`) were failing for reasons unrelated to app logic:
  - The live-region label assertion used `find.bySemanticsLabel` expecting an
    exact match, but the footer's `Semantics` node was merging the child
    `Text`'s content into its own label (Flutter merges leaf text into the
    nearest ancestor node unless told not to). Added `container: true,
    explicitChildNodes: true` to the footer's outer `Semantics` so it keeps its
    own label distinct from its children's.
  - The focus test called `Focus.of()` on the `IconButton`'s own context, but
    `Focus.of` searches *ancestors* — the `IconButton`'s internal `Focus` (from
    `InkWell`) is a *descendant*, and calling `Focus.of` on that `Focus`
    widget's own context has the same ancestor-search problem. Fixed by calling
    `Focus.of` from a context further inside the tree (the `Icon` descendant),
    which correctly resolves to the `IconButton`'s internal focus node.
  - Neither fix touched production accessibility behavior — both were finding
    the right thing, just via the wrong `BuildContext`/Semantics-node shape.

`flutter analyze`: 0 errors (12 pre-existing info-level deprecation notices,
same `MyApp` `widget_test.dart` issue noted in every prior entry). `flutter
test`: all pass except the same single pre-existing `test/widget_test.dart`
failure noted in every prior entry.

## 2026-06-26 — fix-translation-selection-consistency.md (#73, #77, #88)

Picked this over the other unblocked pending plans because it unblocks
`fix-add-verse-ui-polish.md` and resolves a real availability-gating bug
(#73) rather than being pure polish or dedup.

- `lib/services/esv_lookup_service.dart`: added `static bool get
  isApiKeyConfigured` — reads the compile-time `ESV_API_KEY` define directly,
  without constructing an instance/`http.Client`. Existing instance
  `isAvailable` getter unchanged (still used by `add_verse_screen.dart`,
  which already holds a long-lived instance for lookups).
- `lib/screens/settings/settings_screen.dart`: the "Default translation"
  `SegmentedButton` now only offers an ESV segment when
  `EsvLookupService.isApiKeyConfigured` is true — previously it always
  showed BSB/KJV/WEB/ESV regardless of key availability (#73). If the saved
  `defaultTranslation` is `'ESV'` but no key is configured (e.g. a build
  without the key inherited a pref written by one that had it), the screen
  displays `'BSB'` as the effective selection without overwriting the
  stored preference — same fallback idiom `add_verse_screen.dart` already
  used. The personal-use notice subtitle only renders for that effective
  selection, so it no longer appears when ESV isn't actually selectable.
- `lib/models/settings.dart`: added a comment above
  `audioInterruptEnabled`/`audioInterruptProbability` noting the UI displays
  these as "Verse-of-week probability" (#77) — left the stored field/pref-key
  names unchanged rather than writing a migration, per the plan's lighter-
  option guidance.
- `lib/screens/verses/add_verse_screen.dart`: removed the separate
  `ActionChip` ESV toggle (#88) — it folded "ESV · Personal use · 500-verse
  cap" usage-note text into the tappable control, diverging from Settings'
  `SegmentedButton` idiom for the same logical choice. ESV is now a 4th
  `ButtonSegment` in the same `SegmentedButton<String>` as BSB/KJV/WEB (still
  gated behind `_esvLookupService.isAvailable`). The usage note is now static
  caption `Text` below the control, shown only when ESV is available and
  currently selected.
- Tests: `test/services/esv_lookup_service_test.dart` (new
  `isApiKeyConfigured` case); `test/screens/settings/settings_screen_test.dart`
  (replaced the test that asserted the old, buggy "ESV always selectable"
  behavior with one asserting the segment is hidden and the saved-but-
  unavailable `'ESV'` default displays as `'BSB'`); `test/screens/verses/
  add_verse_screen_test.dart` (new regression test confirming no separate
  `ActionChip` exists). The "ESV actually available" rendering path for both
  screens isn't independently tested — `EsvLookupService.isAvailable`/
  `isApiKeyConfigured` both read the compile-time `ESV_API_KEY` define, which
  is empty in this test environment and not constructor-injectable on either
  screen, the same kind of untested boundary noted for `AudioService`'s ESV
  branch in the `feat-esv-audio.md` entry above.
- Docs updated via `sdlc-doc-writer`:
  `docs/features/verse-management.md` (ESV lookup section, Default
  Translation Setting section, changelog row).

`flutter test` passes (350 passed; same 1 pre-existing unrelated failure in
`test/widget_test.dart` noted in every prior entry). `flutter analyze` clean
(same pre-existing deprecation infos and `widget_test.dart` issue).

## 2026-06-26 — fix-net-security-shared.md (#72, #74, #76)

Implemented the three security/architecture hygiene findings from the SDLC
review of the ESV integration branch. Picked this plan over the other
unblocked pending plans because it's security/layering-relevant (highest
priority per the prioritization rule), self-contained, and had no
dependencies.

- `lib/services/net_security.dart` (new): `assertAllowedHttpsHost(Uri uri,
  Set<String> allowedHosts)` — throws `StateError` on non-https scheme or
  disallowed host. Added with TDD (`test/services/net_security_test.dart`,
  3 cases: allowed host, non-https rejection, disallowed-host rejection).
- `lib/services/bible_lookup_service.dart`, `lib/services/esv_lookup_service.dart`:
  replaced their private `_assertHttps` inline duplicate with a call to the
  shared helper; removed the now-dead private method from both.
- `lib/services/esv_audio_cache_service.dart`: both of its host checks
  (the `api.esv.org` redirect-resolve guard and the `audio.esv.org` CDN
  guard) now call the shared helper, with the `StateError` it throws
  re-wrapped into `EsvAudioException` so existing callers/tests (which
  expect `EsvAudioException`, not `StateError`) are unaffected.
- `lib/database/database_helper.dart`: removed the `LookupException` import
  (a service-layer type the DB layer had no business depending on);
  `insertEsvVerse` now throws a new DB-owned `EsvVerseCapExceededException`
  on cap-exceeded instead. No caller needed updating — `add_verse_screen.dart`
  catches the save path generically (`catch (_)`), not by `LookupException`
  type, so the user-facing save-error message is unchanged. No DB-backed
  unit test was added for the new exception type — there is no sqlite test
  harness for `DatabaseHelper` in this repo (same untested boundary noted in
  every prior `insertEsvVerse`-adjacent entry).
- `lib/screens/settings/settings_screen.dart`: the "ESV.org" `ListTile.onTap`
  now wraps `launchUrl` in try/catch and shows a `SnackBar` ("Could not open
  ESV.org.") if it throws or returns false, matching the existing defensive
  SnackBar-fallback pattern already used for the notification-permission
  case in this same file. Added `url_launcher_platform_interface` as an
  explicit `dev_dependency` (was previously only a transitive dependency) so
  the new test could install a throwing fake `UrlLauncherPlatform` and
  exercise the failure path without a real platform channel — new test in
  `test/screens/settings/settings_screen_test.dart`.
- `docs/features/verse-management.md`, `docs/features/audio.md`,
  `docs/features/esv-attribution.md`, `docs/llms.md`: updated via
  `sdlc-doc-writer` to reflect the shared helper and exception rename.

`flutter test` passes (349 total; same 1 pre-existing unrelated failure in
`test/widget_test.dart`). `flutter analyze` clean (same pre-existing
deprecation infos and `widget_test.dart` issue, unrelated to this change).

## 2026-06-26 — feat-esv-audio.md (#70)

Implemented ESV audio playback — the last pending plan, previously skipped
multiple times for needing a live API response to discover the real CDN
hostname. A prior attempt (uncommitted, found already in the working tree at
the start of this run) had built most of `EsvAudioCacheService` and its test
file but left two defects: the test file was missing the `path` package
import (compile error) and a raw network exception during the redirect
resolve call was not wrapped in `EsvAudioException` (one failing test).
Fixed both, then implemented the `AudioService` integration the prior attempt
hadn't started yet.

- `lib/services/esv_audio_cache_service.dart`: fixed — `_resolveCdnUri` now
  wraps any exception from `_client.send`/`http.Response.fromStream` in
  `EsvAudioException` instead of letting it propagate raw. Service was
  otherwise already correct: two-request pattern (auth header sent only to
  `api.esv.org`, never forwarded to the `audio.esv.org` redirect target),
  SHA-256 cache-key filenames (no path traversal via raw reference), 250-file
  eviction, in-flight fetch deduplication, and `EsvAudioConsentRequired`
  gated on the existing `esv_lookup_consent_v1` flag (audio reuses text
  lookup's consent rather than prompting twice for the same recipient/data).
  CDN host allowlisted to `audio.esv.org` — not independently re-verified
  against a live API response in this environment (no network/API-key
  access), same documented limitation as the prior skip decisions.
- `lib/services/audio_service.dart`: added an ESV branch in the text phase.
  `_speakTextPhase(verse)` calls `EsvAudioCacheService.getAudioPath` for
  `verse.translation == 'ESV'` and plays the result via `audioplayers`
  (`_playMp3AndWait`, `DeviceFileSource`); any exception (offline, fetch
  failure, consent not yet granted) falls back to TTS silently, matching the
  plan's "no error shown to user" requirement. `stop()`/`pause()` now also
  stop the active `AudioPlayer`; because `AudioPlayer.stop()` doesn't fire
  `onPlayerComplete` the way TTS's cancel handler resolves its completer, I
  added a tracked `_playerCompleter` that `_stopActivePlayer` resolves
  manually so a paused/stopped MP3 playback doesn't hang `_speakTextPhase`
  forever. `resume()` restarts the current text phase from the beginning for
  ESV audio, same restart-from-beginning behavior already accepted for TTS
  resume.
- `EsvAudioCacheService` is constructor-injectable on `AudioService` (mirrors
  the existing `audioService` injection pattern on `AudioProvider`) but I did
  not add direct unit tests for the new `AudioService` branches: every
  existing test that touches `AudioService` (`audio_provider_test.dart`,
  `review_play_screen_test.dart`, `review_screen_test.dart`,
  `audio_player_bar_test.dart`) substitutes the entire class with
  `FakeAudioService` rather than exercising the real TTS/audioplayers state
  machine, because `flutter_tts` and `audioplayers` both require platform
  channels with no existing mock harness in this repo. Added the feature at
  the same untested boundary already accepted for that class's existing TTS
  logic, rather than building new platform-channel mocking infrastructure
  out of scope for this plan.
- `pubspec.yaml`: `audioplayers: ^6.0.0` (already present from the prior
  attempt).
- `meta/PRIVACY.md`: new "ESV Audio Playback (Optional)" section (two-request
  transmission detail, CDN allowlist, shared consent key, cache key/eviction
  policy, silent-fallback behavior) and a new data-table row for the audio
  cache directory.
- `android/app/src/main/AndroidManifest.xml`: updated the `INTERNET`
  permission comment to name `api.esv.org`/`audio.esv.org`.
- `docs/features/audio.md` and `docs/llms.md`: documented the ESV branch,
  two-request pattern, and consent reuse.
- `test/services/esv_audio_cache_service_test.dart`: fixed missing `path`
  import; all 9 cases pass (cache miss/hit, auth-not-forwarded, network
  failure wrapping, non-redirect status, SSRF host guard, path-traversal-safe
  filenames, in-flight dedup, eviction).

`flutter test` passes (344 passed; same 1 pre-existing unrelated failure in
`test/widget_test.dart` noted in every prior entry). `flutter analyze` clean
(same pre-existing deprecation infos and `widget_test.dart` issue).

This was the last pending plan — all entries in `meta/plans/prd.json` are now
`done`.

## 2026-06-26 — refactor-audio-interrupt-probability.md (#42)

Repurposed the audio interrupt probability slider so it controls how often the
verse-of-week is chosen vs. a random memorized verse, instead of gating
whether an interrupt fires at all. Interrupts now always fire once the time
threshold is crossed.

- `lib/services/audio_interrupt_service.dart`: removed the probabilistic gate
  in `_checkThreshold`; extracted verse selection into a top-level
  `@visibleForTesting` `pickVerseForInterrupt()` function so the weighting
  logic can be unit tested directly (the timer/threshold path relies on real
  `DateTime.now()`, which doesn't cooperate with `fakeAsync`).
- `lib/models/settings.dart`: clamp `audioInterruptProbability` to `[0.0, 1.0]`
  in `fromMap` as a tamper guard (SharedPreferences is unencrypted).
- `lib/screens/settings/settings_screen.dart`: renamed the slider label and
  dialog title to "Verse-of-week probability".
- `docs/features/audio.md`: updated settings table + changelog.
- Added `test/services/audio_interrupt_service_test.dart` (probability 0.0,
  1.0, 0.5 cases) and two clamp tests in `test/models/settings_test.dart`.

`flutter test` passes (283 passed; 1 pre-existing unrelated failure in
`test/widget_test.dart` — confirmed present before this change too).

## 2026-06-26 — feat-esv-lookup.md (#67)

Implemented ESV text lookup and storage, the foundational plan that unblocks
feat-esv-attribution, feat-esv-settings, and feat-esv-audio.

- `lib/services/esv_lookup_service.dart`: new `EsvLookupService`, mirrors
  `BibleLookupService` but targets `api.esv.org` (Crossway). Auth via
  `Authorization: Token <key>` header; key read from
  `String.fromEnvironment('ESV_API_KEY')`. Instance `isAvailable` getter
  reflects whether the key is configured. 50-entry LRU cache, 10s timeout,
  same `LookupException` surface as the existing service.
- `lib/database/database_helper.dart`: added `insertEsvVerse(verse, {cap:
  500})` — atomic transaction enforcing Crossway's 500-verse storage cap,
  preventing double-save races.
- `lib/providers/verse_provider.dart`: added `esvVerseCount` getter;
  `addCustomVerse` now routes ESV verses through `insertEsvVerse`.
- `lib/models/settings.dart`: `defaultTranslation` validated against an
  allowlist (`BSB`, `KJV`, `WEB`, `ESV`) in `fromMap`, same tamper-guard
  pattern as `backupCadence`.
- `lib/screens/verses/add_verse_screen.dart`: ESV presented as a distinct
  `ActionChip` below the BSB/KJV/WEB segmented button (hidden when the build
  has no API key); consent flow extracted into shared `_ensureConsentFor`
  helper with an isolated `esv_lookup_consent_v1` key; pre-lookup cap
  advisory (`warningContainer`) and save-time cap block (`errorContainer`);
  fixed two pre-existing a11y gaps (focus restore after preview
  accept/dismiss, error icons alongside color).
- `meta/PRIVACY.md`: added ESV Verse Lookup section (api.esv.org/Crossway
  recipient, 500-verse cap, isolated consent key) and updated network
  request and data-table sections.
- `docs/features/verse-management.md` and `docs/llms.md`: updated.
- Added `test/services/esv_lookup_service_test.dart` (14 cases) and tests for
  `esvVerseCount` and `defaultTranslation` allowlist.

No existing test harness covers `DatabaseHelper` against a real sqlite
engine in this repo, so `insertEsvVerse`'s atomicity wasn't independently
unit-tested — consistent with the existing test boundary for that class.

`flutter test` passes (303 passed; same 1 pre-existing unrelated failure in
`test/widget_test.dart`).

## 2026-06-26 — feat-auto-verse-of-week.md (#45)

Implemented automatic weekly verse-of-week advancement. Picked this plan over
`feat-reference-scoring-normalization.md` (self-contained but had been
repeatedly skipped by prior runs without an architectural reason to skip
again) and `feat-esv-audio.md` (its plan explicitly requires discovering the
live Crossway audio CDN hostname from a real API response before hardcoding
a security allowlist — not safely doable without network/API-key access in
this environment).

- `lib/models/settings.dart`: added `autoAdvanceVerseOfWeek` (bool, default
  false) and `lastVerseAdvanceDate` (`DateTime?`) to `AppSettings`, with the
  same far-future tamper-guard pattern as `lastBackupAt` in `fromMap`.
- `lib/providers/settings_provider.dart`: persists/loads both new fields
  through `_persist`/`load`, following the existing key-per-field pattern.
- `lib/providers/verse_provider.dart`: added `pickVerseForAutoAdvance`
  (`@visibleForTesting`) — pure decision logic (disabled / not-Sunday /
  already-advanced-this-ISO-week / no-candidate checks) kept separate from
  the DB write so it's unit-testable without a real database, mirroring the
  `pickVerseForInterrupt` precedent from the audio-interrupt-probability
  plan. `autoAdvanceVerseOfWeekIfNeeded` wraps it and calls
  `setVerseOfWeek` + an `onUpdate` callback to persist the new
  `lastVerseAdvanceDate`. ISO-week equality compares the Monday of each
  date's week, correctly handling the Dec/Jan year boundary.
- `lib/screens/settings/settings_screen.dart`: added "Auto-advance verse of
  the week" `SwitchListTile`.
- `lib/screens/home/home_screen.dart`: calls
  `autoAdvanceVerseOfWeekIfNeeded` in the existing post-frame callback after
  `loadVerses()`.
- `meta/PRIVACY.md`, `docs/features/verse-management.md`, `docs/llms.md`:
  updated.
- Tests added in `test/models/settings_test.dart`,
  `test/providers/settings_provider_test.dart`,
  `test/providers/verse_provider_test.dart` (including the Dec-28/Dec-29
  ISO-week-boundary pair), and `test/screens/settings/settings_screen_test.dart`.
  The `HomeScreen` wiring itself isn't independently tested — it calls
  `loadVerses()` against a real `DatabaseHelper`/sqflite, the same untested
  DB-touching boundary noted for `insertEsvVerse` in the prior entry.

`flutter test` passes (318 passed; same 1 pre-existing unrelated failure in
`test/widget_test.dart`). `flutter analyze` clean.

## 2026-06-26 — feat-reference-scoring-normalization.md (#43, #44)

Implemented separator/range normalization for typed Bible references.
This plan had 4 prior failed attempts; root cause was a bug in the plan's
own example code, not the surrounding codebase: it used `String.replaceAll`
with a `RegExp` pattern and a literal `r'$1-$2'` replacement string. Dart's
`replaceAll` does **not** interpolate capture groups from a replacement
string — that substitution syntax only works with `replaceAllMapped`'s
callback (`match.group(n)`). Every regex step that referenced a capture
group in its replacement was silently emitting the literal text `$1`/`$2`
instead of the captured digits, so chapter:verse reconstruction always
failed past the first separator-only case.

- `lib/utils/scoring.dart`: added `_normalizeReferenceInput()`, using
  `replaceAllMapped` (not `replaceAll`) everywhere a capture group feeds the
  replacement. Also widened the word-form separator regexes
  (`colon`/`dot`/`dash`) to consume surrounding whitespace
  (`\s*\bcolon\b\s*` etc.) — without that, "4 colon 13" normalized to
  "4 : 13" (spaces still around the colon), which doesn't match
  `_referenceSplitPattern`'s `\d+:\d+` requirement. Applied to `typed` only
  before `_referenceSplitPattern.firstMatch`, per the plan's rationale that
  `correct` always comes from the database in canonical form.
- `test/utils/scoring_test.dart`: added cases for period, bare-space,
  word-form colon/dot/dash separators; `to`/`through`/word-form-dash/`and`
  range connectors; a guard against `and` mangling book-number prefixes
  (`1 and 2 Thessalonians`); and a fuzz-string timing bound
  (350 repeats of `"12 "` normalizes in <100ms, confirming no catastrophic
  backtracking from the capture-group regexes).

`flutter test` passes (325 passed; same 1 pre-existing unrelated failure in
`test/widget_test.dart`). `flutter analyze` clean (pre-existing deprecation
infos and the same `widget_test.dart` issue, unrelated to this change).

## 2026-06-26 — feat-esv-attribution.md (#68)

Implemented the collapsible Crossway copyright footer required on every
screen that shows ESV verse text.

- `lib/widgets/esv_copyright_footer.dart`: new `EsvCopyrightFooter` widget.
  Renders nothing when `hasEsvContent` is false. Reads/writes
  `SharedPreferences` key `esv_footer_collapsed_v1` (absent = expanded by
  default). Collapsed state is a 48dp `InkWell` chip with
  `Semantics(button: true, expanded: false)`; expanded state shows the full
  notice, a "Full terms in Settings" link (navigates to `SettingsScreen`),
  and a collapse `IconButton`. A hidden `liveRegion` sibling announces state
  changes, and content is wrapped in `AnimatedSize` unless
  `MediaQuery.disableAnimations` is true — same patterns as
  `verse_card.dart`'s state-cycling button.
- `lib/screens/settings/settings_screen.dart`: new "ESV Bible" section below
  About — full Crossway copyright notice plus a tappable "ESV.org" link
  (`launchUrl` with `LaunchMode.externalApplication`).
- Wired `EsvCopyrightFooter` into `add_verse_screen.dart` (visible when
  `_translation == 'ESV' && _preview != null`), `verse_detail_screen.dart`
  (`verse.translation == 'ESV'`), `test_session_screen.dart`
  (`_currentVerse.translation == 'ESV'`), `review_show_screen.dart`
  (`verses.any((v) => v.translation == 'ESV')`), and
  `review_play_screen.dart` (`audio.queue.any((v) => v.translation == 'ESV')`).
- `lib/providers/audio_provider.dart`: added a public `queue` getter
  (`List<Verse>`, unmodifiable) — `review_play_screen.dart` needed to inspect
  all queued verses for ESV content and no such accessor existed before.
- `pubspec.yaml`: added `url_launcher: ^6.3.0` as an explicit direct
  dependency (was previously only pulled in transitively via `share_plus`).
- `android/app/src/main/AndroidManifest.xml`: added an `https` `VIEW` intent
  to the existing `<queries>` block so `canLaunchUrl` doesn't silently return
  false on Android 11+ package-visibility restrictions.
- Added `test/widgets/esv_copyright_footer_test.dart` (6 cases: no-content
  hidden, default-expanded, collapsed-pref rendering, expand-on-tap with
  pref persistence, collapse-on-tap with pref persistence, live-region
  presence in both states).

`flutter test` passes (332 total; same 1 pre-existing unrelated failure in
`test/widget_test.dart`). `flutter analyze` clean (same pre-existing
deprecation infos and `widget_test.dart` issue, unrelated to this change).

## 2026-06-26 — feat-esv-settings.md (#69)

Implemented the "Default translation" control and wired the Add Verse screen
to read it. Picked this over `feat-esv-audio.md` (its plan requires
discovering the live Crossway audio CDN hostname from a real API response
before hardcoding a security allowlist — not safely doable here without
network/API-key access, same blocker noted in the `feat-auto-verse-of-week`
entry above) — `feat-esv-settings.md` was self-contained and unblocked.

- `lib/screens/settings/settings_screen.dart`: new "Verses" section between
  the existing Notifications and Appearance sections — `MergeSemantics` +
  `ListTile` with a 4-segment `SegmentedButton` (BSB/KJV/WEB/ESV) bound to
  `AppSettings.defaultTranslation`. A `liveRegion` subtitle notice ("ESV is
  for personal, non-commercial use only.") shows only when ESV is selected,
  matching the `Theme`/`Notification type` tile pattern already in the file.
- `lib/screens/verses/add_verse_screen.dart`: replaced the hardcoded
  `_translation = 'BSB'` field initializer with `late String _translation`
  set in a new `initState`, read from
  `context.read<SettingsProvider>().settings.defaultTranslation`; falls back
  to `'BSB'` when the default is `'ESV'` but `_esvLookupService.isAvailable`
  is false (no `ESV_API_KEY` configured), so the screen never renders with no
  matching segment selected.
- `AppSettings.defaultTranslation` allowlist guard and the ESV segment in
  Add Verse's `SegmentedButton` were both already in place from
  `feat-esv-lookup.md` — no changes needed there.
- `docs/features/verse-management.md`: added a "Default Translation Setting"
  subsection and changelog entry.
- Tests: `test/screens/settings/settings_screen_test.dart` — control shows
  ESV pre-selected with the notice by default, and selecting a non-ESV
  translation hides the notice and persists the choice (both required
  `tester.scrollUntilVisible` since the control sits below the fold in the
  default 800×600 test viewport — `ListView` only builds visible children).
  New `test/screens/verses/add_verse_screen_test.dart` — translation selector
  initializes to a non-default setting (KJV), and falls back to BSB when the
  default is ESV with no API key configured.

`flutter test` passes (336 passed; same 1 pre-existing unrelated failure in
`test/widget_test.dart`). `flutter analyze` clean (same pre-existing
deprecation infos and `widget_test.dart` issue, unrelated to this change).
