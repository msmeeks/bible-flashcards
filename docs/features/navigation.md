# App Shell & Navigation

## Summary
Provides the persistent bottom navigation bar, the always-visible audio mini-bar, and the screen-to-screen navigation model shared by every tab. It exists so drilling into a sub-screen (verse detail, add verse, test session, history, etc.) never hides the navbar or an in-progress audio playback.

## Users / Use Cases
- **Solo user**: switches between Home/Verses/Review/Test/Settings tabs, drills into sub-screens within a tab without losing the navbar or audio controls, and uses the system back gesture/button to return up the current tab's history before exiting the app.

## Technologies
- Flutter `Navigator` (nested, one per tab) — gives each tab its own independent push/pop history
- `IndexedStack` — keeps all five tabs mounted simultaneously so switching tabs doesn't rebuild or lose state
- `PopScope` — intercepts the system back gesture at the outer `Scaffold` level

## Technical Overview
`MainScaffold` (`lib/screens/main_scaffold.dart`) is the single screen mounted at route `/`. It renders an `IndexedStack` of five tab roots (Home, Verses, Review, Test, Settings), each wrapped in its own `Navigator` keyed by a `GlobalKey<NavigatorState>`. Because each tab's root widget is built inside its own `Navigator`, any `Navigator.of(context).push(...)` call made from within that tab's widget tree resolves to the tab's nested `Navigator` rather than the app's root `Navigator` — sub-screens are pushed as pages *inside* the tab, underneath the `Scaffold`'s persistent `bottomNavigationBar` (audio bar + `NavigationBar`), so the shell never disappears. `lib/app.dart`'s `MaterialApp` therefore has effectively one named route (`/`); every other screen transition is an imperative push on a tab's Navigator.

## Key Files
| File | Purpose |
|---|---|
| `lib/app.dart` | `MaterialApp` root; single `/` route to `MainScaffold` (or first-launch engagement notice); theme/provider wiring |
| `lib/screens/main_scaffold.dart` | `IndexedStack` of 5 tab `Navigator`s, bottom nav bar, `AudioPlayerBar`, `PopScope` back-navigation routing |
| `lib/widgets/audio_player_bar.dart` | Persistent mini audio bar rendered above the `NavigationBar`, hidden when nothing is playing |

## Technical Detail

### Nested Per-Tab Navigators
`_tabNavigatorKeys` is a `List<GlobalKey<NavigatorState>>` of length 5 (one per tab), created once in `_MainScaffoldState` so each tab's navigation stack survives `MainScaffold` rebuilds and tab switches. `_tabNavigator(index, root)` wraps each tab's root screen in a `Navigator` whose single initial `MaterialPage` is keyed `ValueKey('tab-$index-root')` — the root page is never itself poppable. Screens within a tab push further pages via ordinary `Navigator.of(context).push(MaterialPageRoute(...))` calls; because `IndexedStack` keeps all tabs mounted (just not visible), each tab's push history is preserved when switching away and back.

### Back Navigation
The outer `Scaffold` is wrapped in `PopScope(canPop: false, ...)`. On a system back invocation, it checks whether the *currently selected* tab's nested `Navigator` can pop (`tabNavigator.canPop()`); if so it pops that nested Navigator, otherwise it calls `SystemNavigator.pop()` to exit the app. This means back navigation is always scoped to the active tab's own history, never to some other tab's stack.

### Persistent Audio Bar
`AudioPlayerBar` renders inside the `Scaffold.bottomNavigationBar` `Column`, above the `NavigationBar`, so it is visible on every tab and every pushed sub-screen — it does not need special-casing per screen since it lives in the one `Scaffold` that wraps the entire `IndexedStack`.

### Verses Tab Activation Count
`MainScaffold` tracks `_versesActivationCount`, incremented each time the user taps the Verses destination, and passes it to `VersesScreen(activationCount: ...)`. `VersesScreen.didUpdateWidget` uses a change in this count to force a rebuild (e.g. to refresh tab state) purely from re-selecting an already-active tab, distinct from any data reload.

### History (Design Iterations)
This architecture (nested per-tab `Navigator` inside an `IndexedStack`) was the intended design from the start, but landed only after 6 prior stalled attempts were diagnosed as **test infrastructure** failures, not architecture bugs: an unmocked `SharedPreferences` platform call hanging a widget test, a test DB seed call not wrapped in `runAsync`, and a missing `engagement_log` table in the fake test DB schema (`test/helpers/fake_database_helper.dart`). Fixing those three test issues (rather than the navigation code itself) unblocked verification of the already-correct implementation.

## Changelog
| Date | Change |
|---|---|
| 2026-07-02 | Initial documentation: persistent app shell via nested per-tab `Navigator` + `IndexedStack` (#104, #106) |
