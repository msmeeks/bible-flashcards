# ESV Copyright Attribution

## Summary
Crossway's ESV API terms require a visible copyright notice with an esv.org link on every screen that displays ESV scripture text. A reusable collapsible footer widget satisfies this requirement app-wide, and Settings carries the full legal notice plus a link to esv.org.

## Users / Use Cases
- **Solo user**: sees a small, dismissible ESV copyright notice wherever ESV verse text appears; can collapse it to a compact chip if it's distracting, and the choice persists; can read the full notice and follow a link to esv.org from Settings.

## Technologies
- `shared_preferences` — persists the footer's collapsed/expanded state across the whole app (single shared key, not per-screen)
- `url_launcher` — opens esv.org in an external browser from Settings
- `material_symbols_icons` — expand/collapse chevrons
- Flutter `Semantics`/`liveRegion` — accessible state announcements

## Technical Overview
`EsvCopyrightFooter` (`lib/widgets/esv_copyright_footer.dart`) is a stateful widget taking a single `hasEsvContent` flag; callers compute that flag from whatever verse(s) are visible on screen. It renders nothing if `hasEsvContent` is false or before the persisted collapse preference has loaded (avoiding a flash of the wrong state). The widget is wired into every screen that can display ESV verse text: Add Verse (preview), Verse Detail, Test session, Review Show, and Review Play. Settings carries the permanent, non-collapsible full notice plus an external link, independent of the per-screen footer.

## Key Files
| File | Purpose |
|---|---|
| `lib/widgets/esv_copyright_footer.dart` | Collapsible footer widget; loads/persists `esv_footer_collapsed_v1` via `shared_preferences` |
| `lib/screens/verses/add_verse_screen.dart` | Renders footer in the save-confirmation dialog when an ESV preview is showing |
| `lib/screens/verses/verse_detail_screen.dart` | Renders footer when the displayed verse's translation is ESV |
| `lib/screens/test/test_session_screen.dart` | Renders footer when the current test card's verse is ESV |
| `lib/screens/review/review_show_screen.dart` | Renders footer when any verse in the fixed session list is ESV |
| `lib/screens/review/review_play_screen.dart` | Renders footer when any verse in the audio queue (`AudioProvider.queue`) is ESV |
| `lib/providers/audio_provider.dart` | `queue` getter (read-only `List<Verse>`) added so Review Play can inspect translations without mutating playback state |
| `lib/screens/settings/settings_screen.dart` | "ESV Bible" section: full Crossway copyright text + "ESV.org" link via `url_launcher` |
| `android/app/src/main/AndroidManifest.xml` | `<queries>` entry for `https` `ACTION_VIEW` intents, required for `url_launcher` package-visibility on Android 11+ |

## Technical Detail

### Collapse State
Persisted under a single SharedPreferences key (`esv_footer_collapsed_v1`) shared across all screens — collapsing the footer once collapses it everywhere it next appears, rather than per-screen. Defaults to expanded (`false`) when the key is absent. State is loaded asynchronously in `initState`; the widget renders `SizedBox.shrink()` until loaded to avoid a flash of the wrong (default-expanded) state.

### Collapsed vs Expanded
- **Collapsed**: a 48px-tall tappable row showing "ESV®" + a chevron-down icon. Tapping anywhere in the row expands.
- **Expanded**: full Crossway copyright sentence + a collapse icon button + a "Full terms in Settings" `TextButton` that pushes `SettingsScreen`.

Both states wrap content in `Semantics` (`button: true` for collapsed, `expanded: true/false`) and an always-present `Semantics(liveRegion: true)` sibling announces "ESV copyright notice expanded/collapsed" on every state change, independent of the visible content's own semantics tree — this guarantees TalkBack announces the transition even though the visible widget subtree is swapped out via `excludeSemantics`.

Transition between states is wrapped in `AnimatedSize` (200ms), skipped in favor of an instant swap when `MediaQuery.disableAnimations` is true (matches the reduced-motion pattern used elsewhere in the app, e.g. `VerseCard`).

### hasEsvContent Computation Per Screen
Each call site computes its own `hasEsvContent` from the verse(s) actually visible, not from a global "is ESV enabled" flag:
- Add Verse: `_translation == 'ESV' && _preview != null` — only shown once a successful ESV lookup preview is on screen, in the save-confirmation dialog.
- Verse Detail / Test session: single current verse's `translation == 'ESV'`.
- Review Show: `verses.any((v) => v.translation == 'ESV')` over the fixed session list.
- Review Play: `audio.queue.any((v) => v.translation == 'ESV')` over the audio queue, via the new `AudioProvider.queue` getter.

### Settings "ESV Bible" Section
Distinct from the per-screen footer — a permanent `ListTile` with the full Crossway-mandated copyright sentence ("Scripture quotations are from the ESV® Bible... © 2001 by Crossway... Used by permission. All rights reserved.") plus an "ESV.org" row that opens `https://www.esv.org` via `url_launcher` in an external browser (`LaunchMode.externalApplication`). This section is always visible regardless of whether the user has any ESV verses stored. The `launchUrl` call is wrapped in try/catch with a fallback `SnackBar` ("Could not open ESV.org.") shown if `launchUrl` throws or returns `false` (e.g. no browser handler available) — previously unguarded.

### AndroidManifest Queries
Android 11+ package-visibility restrictions require an explicit `<queries>` declaration for `url_launcher`'s `canLaunchUrl`/`launchUrl` to see installed browser apps; without it, `launchUrl` for an `https` URI can silently fail to find a handler on some devices.

## Changelog
| Date | Change |
|---|---|
| 2026-06-26 | Initial implementation (#68): `EsvCopyrightFooter` widget + wiring into Add Verse, Verse Detail, Test session, Review Show, Review Play; Settings "ESV Bible" section with full notice + esv.org link; `AudioProvider.queue` getter added to support Review Play's content check; AndroidManifest `<queries>` entry for `url_launcher` |
| 2026-06-26 | Hardening (#72, #74, #76): "ESV.org" link tap now guarded with try/catch + fallback SnackBar if `launchUrl` fails or finds no handler |
