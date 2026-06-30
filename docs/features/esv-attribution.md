# ESV Copyright Attribution

## Summary
Crossway's ESV API terms require a visible copyright notice with an esv.org link on every screen that displays ESV scripture text. A reusable collapsible footer widget satisfies this requirement app-wide, and Settings carries the full legal notice plus a link to esv.org.

## Users / Use Cases
- **Solo user**: sees a small, dismissible ESV copyright notice wherever ESV verse text appears; can collapse it to a compact chip if it's distracting, and the choice persists; can read the full notice and follow a link to esv.org from Settings.

## Technologies
- `shared_preferences` — persists the footer's collapsed/expanded state across the whole app (single shared key, not per-screen)
- `url_launcher` — opens esv.org in an external browser from Settings
- `material_symbols_icons` — expand/collapse chevrons
- Flutter `Semantics`/`liveRegion` via `AnnounceOnChange` — accessible state announcements, fired once per real change

## Technical Overview
`EsvCopyrightFooter` (`lib/widgets/esv_copyright_footer.dart`) is a stateful widget taking a `hasEsvContent` flag and a required `onViewFullTerms: VoidCallback`; callers compute the flag from whatever verse(s) are visible on screen and supply the callback to navigate to Settings. It renders nothing if `hasEsvContent` is false or before the persisted collapse preference has loaded (avoiding a flash of the wrong state). The widget is wired into every screen that can display ESV verse text: Add Verse (preview), Verse Detail, Test session, Review Show, and Review Play. Settings carries the permanent, non-collapsible full notice plus an external link, independent of the per-screen footer. The footer no longer imports `SettingsScreen` directly — navigation is the caller's responsibility via `onViewFullTerms`, decoupling the widget from the screen layer.

## Key Files
| File | Purpose |
|---|---|
| `lib/widgets/esv_copyright_footer.dart` | Collapsible footer widget; loads/persists `esv_footer_collapsed_v1` via `shared_preferences`; takes `onViewFullTerms` callback instead of navigating itself |
| `lib/widgets/announce_on_change.dart` | Generic helper: flags a `Semantics` live region for exactly one frame after a tracked `value` actually changes, then clears it — prevents duplicate/spurious screen-reader announcements on unrelated rebuilds. Used by `EsvCopyrightFooter` and the Settings ESV notice |
| `lib/screens/verses/add_verse_screen.dart` | Renders footer in the save-confirmation dialog when an ESV preview is showing; passes `onViewFullTerms` that pushes `SettingsScreen` |
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
- **Collapsed**: a real `IconButton` (keyboard-focusable, guaranteed 48x48dp tap target) showing "ESV®" + a chevron-down icon. Was previously a bare `InkWell` (not focusable, no guaranteed tap target size).
- **Expanded**: full Crossway copyright sentence + a collapse `IconButton` + a "Full terms in Settings" `TextButton` calling `widget.onViewFullTerms`.

A single `Semantics` node wraps the whole footer (`container: true`, `explicitChildNodes: true`, `expanded: true/false`, `label` set to the announcement string), and `liveRegion` is driven by `AnnounceOnChange` keyed on the announcement text ("ESV copyright notice expanded/collapsed"). `AnnounceOnChange` flips `liveRegion` true for exactly one frame after the value actually changes, then resets it — so TalkBack announces the transition exactly once. Previously a duplicate hidden `Semantics(liveRegion: true)` sibling caused the same announcement to fire twice.

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

### AnnounceOnChange Helper
`lib/widgets/announce_on_change.dart` is a small generic widget (`value: String`, `builder: (context, liveRegion) => Widget`) factored out of the footer so the same one-shot-announcement pattern can be reused elsewhere. It detects a real change to `value` in `didUpdateWidget`, sets `liveRegion = true` for the widget's `build`, then schedules a post-frame callback to flip it back to `false`. Settings' ESV default-translation subtitle notice ("ESV is for personal, non-commercial use only.") also uses it, keyed on whether ESV is the currently effective default selection — so opening Settings with ESV already selected doesn't trigger a spurious announcement, only an actual change to/from ESV does.

## Changelog
| Date | Change |
|---|---|
| 2026-06-26 | Initial implementation (#68): `EsvCopyrightFooter` widget + wiring into Add Verse, Verse Detail, Test session, Review Show, Review Play; Settings "ESV Bible" section with full notice + esv.org link; `AudioProvider.queue` getter added to support Review Play's content check; AndroidManifest `<queries>` entry for `url_launcher` |
| 2026-06-26 | Hardening (#72, #74, #76): "ESV.org" link tap now guarded with try/catch + fallback SnackBar if `launchUrl` fails or finds no handler |
| 2026-06-28 | Accessibility hardening (#80, #81, #82, #83, #87): new `AnnounceOnChange` helper (`lib/widgets/announce_on_change.dart`) replaces the duplicate hidden live-region `Semantics` node, fixing double announcements; collapsed toggle is now a focusable 48x48dp `IconButton` instead of a bare `InkWell`; footer no longer imports `SettingsScreen` directly — takes a required `onViewFullTerms: VoidCallback` instead, updated at all 5 call sites; Settings' ESV default-translation notice also adopts `AnnounceOnChange` to avoid announcing on every Settings open |
