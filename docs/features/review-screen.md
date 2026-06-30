# Review Screen

## Summary
A 5th bottom-nav destination, between Verses and Test, for casual review of memorized verses outside the scored test flow. The setup screen draws a session of verses; the Show presentation lists their references full-screen with tap-to-reveal text.

## Users / Use Cases
- **Solo user**: quickly skims a batch of memorized verses without going through a scored test session.

## Technologies
- Provider — reuses `VerseProvider.getRandomMemorizedVerses(count, includeVerseOfWeek)`
- Flutter UI — setup screen, fullscreen modal presentation

## Technical Overview
The setup screen (`ReviewScreen`) mirrors the Test screen's review-mode controls: a count slider with 5/10/20/All jump-chips (chips beyond the memorized count are hidden, not disabled) and a verse-of-week toggle (default on). A Show/Play format selector picks between two presentations: Show (tap-to-reveal text list) and Play (audio playback queue, see `docs/features/audio.md`). With zero memorized verses, all setup controls are replaced by an empty state.

Starting a session draws the verse list once via `getRandomMemorizedVerses` and passes it as a constructor argument into either `ReviewShowScreen` or — via `AudioProvider`'s queue — `ReviewPlayScreen`, pushed as a fullscreen modal route. Because the list is captured at push/queue time rather than re-derived inside the pushed screen, it stays fixed for the session even across rebuilds. In Show mode each verse renders as a `VerseCard`, reusing its existing reference/text reveal-on-tap interaction; no audio controls are shown there.

## Key Files
| File | Purpose |
|---|---|
| `lib/screens/review/review_screen.dart` | Setup screen: count slider/chips, verse-of-week toggle, Show/Play selector, empty state, Start action |
| `lib/screens/review/review_show_screen.dart` | Show presentation: fullscreen list of verse references, tap-to-reveal via `VerseCard` |
| `lib/screens/review/review_play_screen.dart` | Play presentation: fullscreen "Now Playing" audio queue UI, driven by `AudioProvider` (see `docs/features/audio.md`) |
| `lib/screens/main_scaffold.dart` | 5th `NavigationDestination` ("Review") wiring |
| `lib/providers/verse_provider.dart` | `getRandomMemorizedVerses(count, includeVerseOfWeek)` |
| `lib/widgets/verse_card.dart` | `VerseCard`/`FlashcardState` reveal interaction, reused as-is |
| `lib/widgets/esv_copyright_footer.dart` | ESV attribution footer rendered in both Show and Play screens when the session/queue contains an ESV verse — see `docs/features/esv-attribution.md` |

## Technical Detail

### ESV Attribution
`ReviewShowScreen` shows `EsvCopyrightFooter(hasEsvContent: verses.any((v) => v.translation == 'ESV'))` below the verse list (now wrapped in a `Column` with the list `Expanded` so the footer can sit beneath it). `ReviewPlayScreen` shows the same footer keyed off `audio.queue.any((v) => v.translation == 'ESV')`, using a new `AudioProvider.queue` read-only getter.

### Pause/Resume and Stop Button Semantics
The Pause/Resume and Stop `IconButton`s in `ReviewPlayScreen` are each wrapped in a `Semantics(label: ..., button: true)` node. Both now also set `excludeSemantics: true` plus an explicit `onTap` callback mirroring the button's real `onPressed` (#90). Without `excludeSemantics: true`, Flutter merges the child `IconButton`'s own (unlabeled) semantics into the parent node, which could leave the merged node without an announceable label for TalkBack; setting it true makes the wrapping `Semantics` the sole source of the node's label, and the added `onTap` keeps the node actionable since the child's tap handler is now excluded from the merge.

## Changelog
| Date | Change |
|---|---|
| 2026-06-26 | Wired `EsvCopyrightFooter` into Show and Play screens (#68); corrected stale doc note describing Play as inert — Play has had a full audio queue UI since #51/#60 |
| 2026-06-30 | Fixed Pause/Resume and Stop button semantics nodes losing their announceable label on merge with child `IconButton` semantics (#90) |
