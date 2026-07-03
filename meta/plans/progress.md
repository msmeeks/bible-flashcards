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
