# Review Screen

## Summary
A 5th bottom-nav destination, between Verses and Test, for casual review of memorized verses outside the scored test flow. The setup screen draws a session of verses; the Show presentation lists their references full-screen with tap-to-reveal text.

## Users / Use Cases
- **Solo user**: quickly skims a batch of memorized verses without going through a scored test session.

## Technologies
- Provider — reuses `VerseProvider.getRandomMemorizedVerses(count, includeVerseOfWeek)`
- Flutter UI — setup screen, fullscreen modal presentation

## Technical Overview
The setup screen (`ReviewScreen`) mirrors the Test screen's review-mode controls: a count slider with 5/10/20/All jump-chips (chips beyond the memorized count are hidden, not disabled) and a verse-of-week toggle (default on). A Show/Play format selector is shown but Play is inert this slice (no `onSelected` handler) — a future slice wires up an audio playback path. With zero memorized verses, all setup controls are replaced by an empty state.

Starting a session draws the verse list once via `getRandomMemorizedVerses` and passes it as a constructor argument into `ReviewShowScreen`, pushed as a fullscreen modal route. Because the list is captured at push time rather than re-derived inside the pushed screen, it stays fixed for the session even across rebuilds. Each verse renders as a `VerseCard`, reusing its existing reference/text reveal-on-tap interaction; no audio controls are shown.

## Key Files
| File | Purpose |
|---|---|
| `lib/screens/review/review_screen.dart` | Setup screen: count slider/chips, verse-of-week toggle, Show/Play selector, empty state, Start action |
| `lib/screens/review/review_show_screen.dart` | Show presentation: fullscreen list of verse references, tap-to-reveal via `VerseCard` |
| `lib/screens/main_scaffold.dart` | 5th `NavigationDestination` ("Review") wiring |
| `lib/providers/verse_provider.dart` | `getRandomMemorizedVerses(count, includeVerseOfWeek)` |
| `lib/widgets/verse_card.dart` | `VerseCard`/`FlashcardState` reveal interaction, reused as-is |
