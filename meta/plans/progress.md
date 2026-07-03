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
