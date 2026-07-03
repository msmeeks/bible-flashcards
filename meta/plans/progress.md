# Iteration Progress

## 2026-07-02 — fix-persistent-app-shell.md (issues #104, #106)

Completed after 7 total attempts (6 prior stalled attempts had left the architectural
implementation nearly done but uncommitted; this pass diagnosed and fixed the actual
blocker rather than redoing the design).

What was already correct from prior attempts (verified, not rewritten):
- `MainScaffold` restructured with a nested `Navigator` per tab (keyed by
  `GlobalKey<NavigatorState>`) inside the `IndexedStack`, with `PopScope` on the outer
  `Scaffold` delegating system back to the active tab's nested navigator (falling back
  to `SystemNavigator.pop()` only when that navigator can't pop further).
- `app.dart` no longer registers named routes for sub-screens; all pushes go through
  the owning tab's nested navigator via `Navigator.of(context).push(...)`.
- `home_screen.dart`, `verses_screen.dart`, `settings_screen.dart`,
  `verse_detail_screen.dart` converted to the new push pattern; `verseId` is now a
  typed constructor param instead of `ModalRoute` arguments; redundant Settings cog
  removed from Home's AppBar.

Root cause of the "stalled" status (why 6 attempts never landed):
1. `test/screens/main_scaffold_test.dart`'s new "bottom navbar stays visible" widget
   test hung for the full 10-minute `flutter test` timeout. Cause: `VerseDetailScreen`
   logs engagement via `SharedPreferences`, and the test never called
   `SharedPreferences.setMockInitialValues()`, so that platform-channel call never
   resolved. Fixed by adding the mock in `setUp()`.
2. Once unblocked, the same test still hung — this time because the test's own
   `DatabaseHelper().insertVerse(...)` seed call was awaited directly instead of
   wrapped in `tester.runAsync()`, unlike every other real-async DB call in the file.
   Fixed by wrapping it, per the file's existing documented convention.
3. Once unblocked again, a real (fast) failure surfaced: the shared
   `test/helpers/fake_database_helper.dart` schema was missing the `engagement_log`
   table that `logEngagement()` needs, so `VerseDetailScreen.initState()` threw
   `SqfliteFfiException: no such table: engagement_log`. Added the missing table to
   the fake DB schema (mirrors the real schema in `database_helper.dart`).

Added one more test (TDD, via `/tdd`) for a blocker flagged in the plan's own
pre-implementation accessibility review: Android system back from verse detail
returns to the Verses list (nav bar still shows Verses selected) rather than exiting
the app. It passed against the existing `PopScope` implementation without further
code changes — confirming that part of the design was already correct.

Verification: `flutter analyze` clean (no new issues), `flutter test` 442/442 passing,
and `bash scripts/smoke_test.sh` (full unit suite + real emulator integration test)
passed end-to-end.

Not done in this pass (left for a follow-up if wanted): the plan also called out a
regression test for the audio mini-bar staying visible during sub-screen navigation,
and a test guarding that `showDialog` calls keep using the root navigator. Neither
blocks the acceptance criteria that were verified; flagging for future test coverage.

## 2026-07-02 — fix-book-variants-crash.md (issue #103)

Completed on the 2nd attempt (a prior interrupted session had left a red widget test
in place, uncommitted, plus a stray empty `prd.json.lock`; picked up from there
instead of restarting).

- Added an `isSubmitting` flag to the Add-variant dialog's `StatefulBuilder` state,
  guarded via `PopScope(canPop: !isSubmitting)` and `onPressed: isSubmitting ? null
  : ...` on the Add/Cancel buttons and the book dropdown/text field, matching the
  existing async-button spinner pattern from `add_verse_screen.dart` (18dp
  `CircularProgressIndicator`, `Semantics(liveRegion: true, ...)`).
  `isSubmitting` is reset in a `finally` block so any exception type re-enables the
  button, not just the already-handled `ArgumentError`.
- While making the pre-existing (red) widget test pass, uncovered and fixed a second,
  related latent bug: `textController`/`bookFocusNode`/`variantFocusNode` were
  disposed synchronously right after `showDialog`'s future resolved, but the dialog
  route's exit transition still renders the about-to-be-removed content for one more
  frame — so any pump during that transition threw "FocusNode used after being
  disposed". Deferred disposal by one frame via
  `WidgetsBinding.instance.addPostFrameCallback`. Confirmed via `git stash` that this
  also reproduced against the pre-fix code (test hung/failed either way), so it
  wasn't a regression introduced by this change, just newly exposed by the test
  actually reaching completion instead of hanging.
- Added a second test (TDD) that directly double-invokes the Add button's `onPressed`
  callback synchronously (simulating a same-frame double-tap that races ahead of the
  `onPressed: null` disabled state) and asserts no exception is thrown and exactly one
  variant is persisted. Verified red against the pre-fix code via `git stash` before
  restoring the fix.

Verification: `flutter analyze` clean (no new issues), `flutter test` 444/444 passing,
and `bash scripts/smoke_test.sh` passed end-to-end.

## 2026-07-03 — fix-verse-list-scroll-position.md (issue #105)

Completed on the 4th attempt. A prior interrupted session (3 attempts) had left the
plan's core implementation done-but-unverified and uncommitted: `_AvailableTab`
converted to a `StatefulWidget` with a `ScrollController`, stable `Key`s on list items
(`ValueKey(verse.id)` / `ValueKey('header-$packId')`), and an in-flight guard on
`_MemorizeButton` against double-tap races. Its widget tests (scroll offset preserved
across a Memorize tap; button disables mid-flight) already passed. Verified the
pre-existing work rather than redoing it.

Manually reproducing the fix on the emulator (not just running the widget test)
surfaced that the bug was **not actually fixed**: tapping Memorize on a
mid-scroll-position item still snapped the list back to the top. Root cause: every
mutation (`markMemorized`, `setVerseOfWeek`, etc.) ends with `VerseProvider.loadVerses()`,
which sets `isLoading = true` and calls `notifyListeners()` *before* the DB refetch —
and `VersesScreen`'s `Consumer` unconditionally rendered a full-screen
`CircularProgressIndicator` whenever `isLoading` was true, tearing down the entire
`TabBarView` (and `_AvailableTab`'s `ScrollController`/state) on every reload, not just
the initial one. The widget test didn't catch this because in-memory sqlite queries
resolve fast enough that the transient `isLoading=true` frame never actually gets
rendered between `pump()` calls, so it's a false negative there — real on-device DB
timing does render that frame.

Fix: `VersesScreen`'s loading gate now only fires when there's no data yet
(`provider.isLoading && memorized.isEmpty && available.isEmpty`), so a refresh of
already-loaded data keeps the tabs mounted instead of blanking the screen. Added a
`VerseProvider.debugSetLoading()` testing seam (mirrors the existing `debugSetVerses`)
to deterministically test this without depending on DB-query timing, and a new widget
test that sets `isLoading = true` after data is already loaded and asserts the list
stays mounted (no spinner) — confirmed red against the pre-fix code, green after.

Re-verified manually end-to-end on the emulator after the fix: scrolled the Available
list, tapped Memorize on a mid-list verse, confirmed the list held its scroll position
and the verse moved to the Memorized tab.

Verification: `flutter analyze` clean (no new issues), `flutter test` 447/447 passing,
and `bash scripts/smoke_test.sh` passed end-to-end.

## 2026-07-03 — fix-web-lookup-book-variants.md (issue #108)

Completed on the 2nd attempt. A prior interrupted session had already written the two
failing widget tests (uncommitted) for this plan: one asserting a custom book-name
variant resolves during web lookup, one asserting an unresolvable book name surfaces
the distinct "Unrecognized book name" message rather than the generic format error.
Verified both were red against the pre-fix code, then implemented.

- `_lookupVerse` in `add_verse_screen.dart` now loads custom variants via
  `DatabaseHelper().getCustomVariantLookup()` and resolves the typed reference through
  the existing `normalizeReferenceForSave` helper (same one `_normalizeAndAwaitConfirmation`
  already used at save-time) before calling either lookup service, so search and save
  agree on book-name resolution. The DB read happens after the consent gate but while
  `_isLookingUp` is already `true`, so Search stays disabled during it (no double-tap
  race). An unresolved book name now surfaces via the existing `_lookupError`/
  `InlineStatusBanner` path with the save-flow's "Unrecognized book name..." wording
  instead of the generic "Invalid reference format" message.
- Fixed 3 pre-existing tests in `add_verse_screen_test.dart` that broke once a real
  (non-fake-clock) DB read entered the lookup path: they used bare `tester.tap` +
  `pump()`/`pumpAndSettle()`, which can't resolve a genuine async gap the way the
  file's own `_tapAndSettle` helper (already used elsewhere in this file, wrapping in
  `tester.runAsync`) does. Switched them to `_tapAndSettle`.

Verification: `flutter analyze` clean (no new issues), `flutter test` 449/449 passing,
and `bash scripts/smoke_test.sh` (full unit suite + real emulator integration test)
passed end-to-end.

## 2026-07-03 — fix-main-scaffold-tab-and-back-nav.md (issues #112, #115, #117)

Completed on the 1st attempt.

- `_tabNavigatorKeys` now derives its length from `_destinations.length` instead of
  a hardcoded `5`, so the navigator-key list can't silently drift from the tab count.
- Back-press handling in `MainScaffold`'s `PopScope`: when the active tab's nested
  navigator has no history to pop, it now switches to the Home tab (`setState(() =>
  _selectedIndex = 0)`) instead of exiting, unless already on Home, in which case it
  still calls `SystemNavigator.pop()` as before.
- Each tab's `_tabNavigator(...)` child is now wrapped in `ExcludeSemantics(excluding:
  index != _selectedIndex, ...)` so inactive tabs' controls are excluded from the
  semantics tree.
- Added three tests (TDD): back-press on a non-Home tab root switches to Home
  (confirmed red before the `setState` branch existed); back-press on the Home tab
  root exits via `SystemNavigator.pop` (mocked `SystemChannels.platform`, confirmed
  already green — regression coverage for existing behavior); a control in an
  inactive tab is unreachable via `tester.getSemantics` and becomes reachable again
  after switching to that tab (this one was already green pre-fix — Flutter's
  `IndexedStack` already excludes non-selected children from
  `visitChildrenForSemantics` — so `ExcludeSemantics` is redundant defense-in-depth
  here rather than the actual fix; kept per the plan's explicit accessibility-review
  guidance and left the test in place as regression coverage).

Verification: `flutter analyze` clean (no new issues), `flutter test` 452/452 passing,
and `bash scripts/smoke_test.sh` (full unit suite + real emulator integration test)
passed end-to-end.

## 2026-07-03 — test-dedupe-async-settle-helper.md (issue #116)

Completed on the 1st attempt.

- Added `test/helpers/async_settle.dart` with `pumpUntilAsyncSettled(tester, {finalPump})`,
  extracting the shared "pump, pump 100ms, real-delay 200ms, pump" sequence used to drive
  a pending sqflite round-trip to completion in widget tests. The trailing pump duration
  differed across call sites (200ms vs 500ms), so it's an optional named parameter
  defaulting to 200ms rather than a hardcoded value, to avoid a timing regression at the
  500ms sites.
- Replaced `_settleAsync` in `test/screens/main_scaffold_test.dart` and `_drainAsync` in
  `test/screens/settings/book_variants_screen_test.dart` with the shared helper, and
  replaced one inlined copy of the same sequence in
  `test/screens/verses/verses_screen_test.dart`.
- The plan's cited line numbers for the "two inline copies" in `verses_screen_test.dart`
  (~1800-1806, 1896-1901) didn't correspond to the current 187-line file. Investigated
  directly: only one inline block matches the shared pattern byte-for-byte (the
  double-tap-race test); the other async block in that file (scroll-position test) is a
  distinct sequence (taps mid-block, uses a 50ms delay, no 100ms pump step) and was left
  as-is rather than forced into the shared helper's signature.

Verification: `flutter analyze` clean (no new issues), `flutter test` 452/452 passing,
and `bash scripts/smoke_test.sh` (full unit suite + real emulator integration test)
passed end-to-end.

## 2026-07-03 — fix-fill-blank-test-scoring-ux.md (issues #107, #36)

Recovered on the 7th attempt. A prior interrupted session had left the full
implementation done, tested, and passing, but uncommitted — `git status` at the start
of this session showed modified `scoring.dart`, `test_session_screen.dart`, and their
test files with no corresponding commit. Verified the work against the plan's
acceptance criteria and pre-implementation review notes rather than redoing it:

- `scoreBlankedBookNameTokens` in `scoring.dart` scopes lenient abbreviation matching
  strictly to a reference's book-name token span (via `referenceSplitPattern` +
  `bookNameToUsfm`), leaving verse-body and chapter/verse-number blanks on exact-match
  scoring.
- `_onBlankCheck` wires the new function in for reference prompts; typed text now
  persists after checking (no more `_blankControllers[i].clear()`), with the clear
  moved to `_onBlankRetry` instead so retries start fresh.
- `_buildFillBlankArea` drops the `labelText`/placeholder in favor of a
  `Semantics(label: 'Blank N of M', textField: true)` wrapper, reuses the existing
  `errorText` slot to show the expected word beneath incorrect blanks instead of a
  text label, and swaps `Icons.check`/`Icons.close` for
  `Symbols.check_circle_rounded`/`Symbols.cancel_rounded` (the app's existing Material
  Symbols standard), each wrapped in `Semantics(label: 'Correct'/'Incorrect')` so both
  outcomes are announced, not just failure.
- Added a `debugBlankIndices` constructor param on `TestSessionScreen` so tests can
  force which word indices get blanked instead of relying on random selection.

Verification: `flutter analyze` clean (no new issues), `flutter test` 464/464 passing,
and `bash scripts/smoke_test.sh` (full unit suite + real emulator integration test)
passed end-to-end.

## 2026-07-03 — fix-verse-reference-resolution-dedup.md (issues #111, #125)

Completed on the 5th attempt (4 prior attempts had left no uncommitted trace — working
tree was clean at the start of this session, only `prd.json`'s attempts counter showed
prior tries).

- Added `_resolveReference(rawReference)` to `add_verse_screen.dart`: fetches custom
  book-name variants (swallowing a DB-read failure and falling back to built-in
  resolution only), then normalizes via the existing `normalizeReferenceForSave`,
  returning a `({String? reference, bool unresolved})` record. Both `_lookupVerse()`
  and `_normalizeAndAwaitConfirmation()` now call this one helper instead of
  duplicating the fetch+normalize+classify logic.
- `_lookupVerse()` now sets `_referenceUnresolved = true` on an unresolved-book web
  lookup failure, the same flag the save path already set — so the "Open Book Name
  Variants settings" shortcut (a single existing widget gated on that one flag) shows
  after a failed Search, not just a failed Save. This was the actual behavior gap
  (#111); no new shortcut widget was needed since the existing one is flag-driven.
- Hoisted the three drifted error strings (`_invalidFormatMessage`,
  `_unresolvedBookMessage`, `_unresolvedBookFieldError`) to `static const` fields, used
  by both flows and the lookup service's `ArgumentError` catch.
- Added a test (TDD, confirmed red before the flag fix) asserting the shortcut appears
  after a failed web lookup. Added a second test (#125) that swaps in an in-memory
  database missing the `book_name_variants` table via `DatabaseHelper.debugSetDatabase`
  mid-test, forcing `getCustomVariantLookup()` to throw during web lookup, and asserts
  the lookup still succeeds via built-in resolution — this passed immediately (no code
  change needed), confirming the existing bare `catch (_) {}` fallback already worked
  correctly, it was just untested.

Verification: `flutter analyze` clean (no new issues), `flutter test` 466/466 passing,
and `bash scripts/smoke_test.sh` (full unit suite + real emulator integration test)
passed end-to-end.

## 2026-07-03 — fix-inflight-button-focus-and-announcements.md (issues #118, #119)

Recovered on what `prd.json` would have logged as attempt 1, though the working tree
at the start of this session already held a complete, uncommitted implementation from
an interrupted prior session (misfiled: a stray `attempts: 2` bump had landed on the
unrelated `fix-verses-navigation-boilerplate.md` entry instead, which was reset back to
0 here). Verified the existing diff against the plan's acceptance criteria rather than
redoing it.

- `book_variants_screen.dart`: the Add-variant dialog's submit button now captures
  whether it held focus before disabling itself for the async save, and re-requests
  focus on completion (success or failure) via a new `submitFocusNode`. The dialog's
  `PopScope` gained an `onPopInvokedWithResult` that fires a one-shot
  `SemanticsService.announce("Please wait for the current action to finish.")` only
  when a dismiss attempt is actually blocked (`!didPop && isSubmitting`) — a normal
  dismiss (not submitting) doesn't announce, and a second blocked attempt during the
  same in-flight window doesn't double-announce.
- `verses_screen.dart`'s `_MemorizeButtonState` gained the same
  capture-focus-before-disable / restore-on-completion pattern via a new `FocusNode`.
- Tests (already present, verified red-then-green against `git stash`): a "normal
  dismiss doesn't announce" case, a "blocked dismiss announces exactly once" case
  (asserted via a mocked `SystemChannels.accessibility` handler), and a
  "focus returns to the Memorize button after a failed action" case that drops the
  `verses` table mid-flight to force a real failure path rather than mocking it.

Verification: `flutter analyze` clean (no new issues), `flutter test` 469/469 passing,
and `bash scripts/smoke_test.sh` (full unit suite + real emulator integration test)
passed end-to-end.

## 2026-07-03 — fix-verses-navigation-boilerplate.md (issues #113, #114)

Completed on the 1st attempt.

- Added a shared `openVerseDetail(BuildContext context, String verseId)` helper in
  `verses_screen.dart` and pointed all four verse-detail navigation call sites at it:
  the search-result tile and the memorized-list tile in `verses_screen.dart`, and the
  recent-memorized chip in `home_screen.dart` (imported via `show openVerseDetail`).
- Removed `_MemorizedListTile.onLongPress`, which pushed the identical route as
  `onTap` — per the triage note on #114, dropped rather than replaced since there's no
  existing long-press/context-menu convention elsewhere in the app.
- Added two tests (TDD): tapping a memorized tile opens `VerseDetailScreen`, and
  long-pressing one still results in exactly one navigator push (verified via a
  `NavigatorObserver`), confirming the handler removal didn't leave long-press dead or
  double-firing. Note: Flutter's gesture arena only ever lets one recognizer win a
  given gesture, so a widget test can't reproduce the literal "duplicate push from one
  gesture" scenario — the real defect was redundant source code doing the same thing
  twice, not an observable double-navigation bug; the tests instead lock in that
  behavior is unchanged/non-broken by the cleanup.

Verification: `flutter analyze` clean (no new issues), `flutter test` 471/471 passing,
and `bash scripts/smoke_test.sh` (full unit suite + real emulator integration test)
passed end-to-end.

## 2026-07-03 — test-main-scaffold-coverage.md (issues #120, #121)

Completed on the 2nd attempt (an interrupted prior attempt had already landed the
root-level back-press branch tests, tracked by a stray `attempts: 1` bump with no
matching code — reset here by moving that increment into this entry).

- Verified `#121` (root-level back-press branch) was already covered by prior work:
  `system back on a non-Home tab root switches to Home instead of exiting` and
  `system back on the Home tab root exits the app`, both exercising the two outcomes
  of the "no nested history" branch in `MainScaffold`'s `PopScope` handler.
- Added the one missing case for `#120`: a test that pushes into `VerseDetailScreen`
  from the Verses tab, switches to Home, switches back to Verses, and asserts the
  detail screen (not the list) is still shown — confirming a tab's nested-navigator
  state survives switching away and back.

Verification: `flutter analyze` clean (no new issues), `flutter test` 472/472 passing,
and `bash scripts/smoke_test.sh` (full unit suite + real emulator integration test)
passed end-to-end.
