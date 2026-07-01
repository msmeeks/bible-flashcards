# Plan: Persistent app shell (navbar + audio mini-bar) across all screens

**Issues:** #104, #106

---

## Goal

The bottom navbar (Home, Verses, Review, Test, Settings) and the audio "now playing" mini-bar stay visible on every screen — including sub-screens like verse detail, add verse, test session, and settings sub-pages — instead of disappearing when the user drills in.

---

## Context

`MainScaffold` (`lib/screens/main_scaffold.dart:54-77`) is a single `Scaffold` holding an `IndexedStack` of the 5 tab roots, with `AudioPlayerBar` + `NavigationBar` in `bottomNavigationBar`. Sub-screens reached via `Navigator.of(context).pushNamed(...)` (named routes registered in `lib/app.dart`) push onto the **root** navigator — the same one `MainScaffold` lives in as route `/` — so a full-screen `MaterialPageRoute` completely covers `MainScaffold`, including its navbar and audio bar, even though `MainScaffold`'s state is preserved underneath.

**Critical architecture correction from review:** simply converting `pushNamed(...)` calls to `Navigator.push(context, MaterialPageRoute(...))` does **not** fix this — both push onto the same root navigator and produce identical full-screen covering. Confirmed independently by both the design and security reviewers. The actual fix requires a **nested `Navigator` per tab** living inside `MainScaffold`'s `IndexedStack`, so sub-screen pushes happen on that inner navigator while `MainScaffold`'s own `Scaffold` (navbar + audio bar) stays the outermost, always-visible layer.

Also remove the redundant settings cog/gear icon button in `HomeScreen`'s AppBar (`lib/screens/home/home_screen.dart:44-59`, cog at line ~53), since Settings is already a persistent navbar destination, and ensure the navbar highlights the correct tab even when the visible content is a sub-screen belonging to that tab's section.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/screens/main_scaffold.dart` | Introduce a nested `Navigator` (with its own `GlobalKey<NavigatorState>`) per tab inside the `IndexedStack`, so `MainScaffold`'s own `Scaffold`/`bottomNavigationBar` never gets covered by a sub-screen push. Track which of the 5 sections a currently-displayed sub-screen belongs to so `NavigationBar.selectedIndex` reflects it. |
| `lib/app.dart` | Remove named-route entries for sub-screens (`/verse-detail`, `/verse-add`, `/history`, etc.) that are being converted to pushes on the per-tab nested navigator. Keep root/tab routes only. |
| `lib/screens/verses/verses_screen.dart` | Convert `pushNamed` calls at lines ~43, 145, 215, 217 (`/verse-add`, `/verse-detail`) to pushes on the owning tab's nested navigator, passing `verseId`/args as typed constructor parameters instead of `RouteSettings.arguments`. |
| `lib/screens/home/home_screen.dart` | Convert `pushNamed` calls at lines ~130, 171, 245 similarly. Remove the redundant settings cog `IconButton` (~line 44-59) and its now-unused `Symbols.settings_rounded` import if unused elsewhere. Decide and document whether opening verse detail from Home (a Verses-owned screen) switches the highlighted tab to "Verses" or stays "Home" — pick one and make it consistent. |
| `lib/screens/settings/settings_screen.dart` | Convert `/history` (`pushNamed`, line ~271) to the same nested-navigator push pattern used by the already-converted `TestHistoryScreen`/`BookVariantsScreen`/`DataManagementScreen` (lines ~251, 285, 296) for consistency within the same list. |
| `lib/screens/verses/verse_detail_screen.dart` | Change from reading `ModalRoute.of(context)!.settings.arguments as String` (line ~35) to accepting `verseId` as an explicit constructor field — removes an unchecked cast and is a strict improvement while every call site is already being touched. |

### Steps

1. Write/adjust widget tests first (per TDD workflow) asserting: (a) navbar + audio bar remain visible after pushing into verse detail / add verse / history, (b) Android system back from a sub-screen returns to the correct originating tab (not app exit, not a different tab), (c) `NavigationBar`'s `Semantics(selected:)` matches the section owning the currently displayed sub-screen.
2. Restructure `MainScaffold` to hold a `Navigator` per tab branch inside the `IndexedStack`, keyed by `GlobalKey<NavigatorState>`, with `onGenerateRoute` building each tab's root screen.
3. Update `verse_detail_screen.dart` to take `verseId` as a constructor parameter; update all call sites.
4. Convert each `pushNamed` call site (verses_screen.dart, home_screen.dart, settings_screen.dart `/history`) to push on the correct nested navigator via the owning tab's `GlobalKey<NavigatorState>` or an `InheritedWidget`/provider exposing "current tab navigator."
5. Remove now-dead named-route entries from `app.dart`.
6. Remove the HomeScreen AppBar settings cog; confirm the four existing ad hoc `MaterialPageRoute` pushes to `SettingsScreen` from the ESV "view full terms" links (`verse_detail_screen.dart:115-116`, `add_verse_screen.dart:580-581`, `review_show_screen.dart:34-35`, `test_session_screen.dart:525-526`) still work and consider normalizing them to the same navigation helper for consistency.
7. Implement active-tab tracking so `NavigationBar.selectedIndex` reflects the section that owns whatever sub-screen is currently on top, reusing the existing MD3 `NavigationBar`/`NavigationDestination` `selected` styling — do not build a second, parallel highlight indicator.
8. Run the widget tests from step 1; add a regression test confirming the audio mini-bar keeps playing/visible when navigating from the flashcard screen into another sub-screen.

---

## Acceptance Criteria

- [ ] Bottom navbar and audio mini-bar (when audio is playing) remain visible on verse detail, add verse, test session, results, history, book name variants, and data management screens
- [ ] The settings cog/gear button no longer appears in any app bar; Settings remains reachable via the navbar
- [ ] The navbar highlights the correct tab when a sub-screen belonging to that section is displayed
- [ ] Android system back button from any sub-screen returns to the correct originating tab, never exits the app unexpectedly or lands on the wrong tab
- [ ] TalkBack announces the correct accessible name/selected state for the active tab, and moves focus into each newly pushed sub-screen

---

## Pre-Implementation Review

**Design (Critical):** Confirmed independently that a plain `pushNamed` → `MaterialPageRoute.push()` swap does not achieve a persistent shell — both target the same root navigator. A nested `Navigator` per tab inside `MainScaffold` is required; this plan's Implementation Notes reflect that correction.

**Design (Major):** Several `pushNamed` call sites beyond the originally-scoped files need the same treatment for consistency (`verses_screen.dart:43,145,215,217`; `home_screen.dart:130,171,245`; `settings_screen.dart:271`), otherwise some navigation paths keep the shell and others don't. Also reconcile the four existing ad hoc `MaterialPageRoute` pushes to Settings from ESV-terms links so there isn't a lingering "two ways to reach Settings."

**Design (Major):** `MaterialPageRoute`'s default platform transition doesn't match the Design Brief's `SharedAxisTransition` (300ms) spec; converting more call sites to bare `MaterialPageRoute` widens this pre-existing gap. Consider introducing a shared `AppPageRoute`/transition builder in this PR.

**Security (informational):** Prefer passing `verseId` as a typed constructor parameter over `ModalRoute.settings.arguments as String` while touching every call site anyway — removes an unchecked cast that could throw `TypeError` if a future caller passes the wrong type.

**Accessibility (Blocker):** Verify each sub-screen pushed onto the nested navigator is wrapped in its own `Scaffold`/`Material` so it gets a distinct `FocusScope` and receives initial TalkBack focus — do not push bare `Container`/`Column` widgets.

**Accessibility (Blocker):** Confirm Android back button pops the correct nested tab stack first, never trapping focus or exiting past the intended tab. Add a widget test for this exact path (Verses → verse detail → back → Verses list).

**Accessibility (Major):** Decide and test whether opening verse detail from Home (cross-tab navigation) changes the highlighted tab to "Verses" or keeps "Home" — whichever is chosen, cover it with a widget test asserting `NavigationDestination`'s `Semantics(selected:)` value (not just visual color, to avoid a WCAG 1.4.1 Use-of-Color-only failure).

**Privacy:** No PII/data-flow concerns — this is pure navigation plumbing. Note that the audio mini-bar will now keep playing/visible across screens it previously stopped/hid on; confirm this UX change is intended.

**Security (Medium):** During the transition, any `Navigator.of(context).pushNamed(...)` call site not yet converted to the nested-navigator pattern will silently resolve against whichever `Navigator` is nearest in the tree, rendering outside the persistent shell — reintroducing the exact bug this refactor fixes. Do a final audit pass over every call site listed in this plan after the refactor; prefer explicit `GlobalKey<NavigatorState>` references over implicit nearest-ancestor resolution for anything shell-critical.

**Security (Medium):** No `PopScope`/`WillPopScope` exists anywhere in the codebase today. `MainScaffold`'s back-button handling (delegating system back to `navigatorKey.currentState.pop()`) must not unconditionally pop the nested navigator — a naive implementation would silently bypass any future confirm-before-leaving/delete-confirmation dialog that relies on consuming the pop. Add a widget test asserting back-press respects an open dialog/PopScope guard on the pushed sub-screen, not just the nested-navigator stack.

**Security (Low/Informational):** Once a `Navigator` per tab exists, `showDialog` calls (e.g. the ESV consent dialog in `add_verse_screen.dart:107`, `barrierDismissible: false`) must keep relying on the default `useRootNavigator: true` behavior. No call site currently overrides this, but flag it as a guardrail — a future contributor passing `useRootNavigator: false` would make the consent dialog resolve against a tab's nested navigator instead of the root, which is the one place in this refactor where a navigator-resolution mistake has a real consequence (bypassing the required consent gate before an outbound network fetch).
