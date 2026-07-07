# Plan: Consistent verse reference formatting on Test Summary and Test History

**Issues:** #137

---

## Goal

Test Summary and Test History screens always show a correctly formatted verse reference, for both bundled-pack and custom-added verses.

---

## Context

`test_result_screen.dart` currently derives a display reference by parsing `result.verseId` through `formatVerseReference` (`lib/utils/verse_reference_format.dart`), which looks up the id's book-slug segment against a hardcoded abbreviation dictionary. Bundled-pack verse ids use short slugs (`rom`, `phil`) that resolve fine, but custom verses added via Add Verse use ids built from the full normalized reference (e.g. `esv_romans_2_2`), whose `"romans"` segment isn't in the dictionary — so `formatVerseReference` falls back to returning the raw id unformatted.

`test_history_screen.dart` doesn't call `formatVerseReference` at all — it renders `result.verseId` raw (`Text(result.verseId, ...)`, line 262), so every row on that screen shows an unformatted slug regardless of verse origin.

The correct source of truth (used elsewhere in the app, e.g. `verses_screen.dart`) is the verse's own stored `reference` field, not something re-derived from its id. `DatabaseHelper.getVerseById(String id)` (`lib/database/database_helper.dart:280`) already returns the full `Verse?` including `.reference` and `.translation`.

## Files to Modify

| File | Change |
|------|--------|
| `lib/screens/test/test_result_screen.dart` | Replace `formatVerseReference(result.verseId)` (line 167) with a lookup via `DatabaseHelper().getVerseById(result.verseId)` and display `verse.reference` (+ translation if the current copy includes it) |
| `lib/screens/settings/test_history_screen.dart` | Replace raw `Text(result.verseId, ...)` (line 262) with the same lookup-based reference display |

## Steps

1. In both screens, resolve each result's verse via `DatabaseHelper().getVerseById(result.verseId)` for **all** results with a single `Future.wait` upfront, keyed into a `Map<String, Verse?>` before the list builds — not a per-row `FutureBuilder`. Per-row futures would fire N independent DB queries and cause visible flicker as each row resolves separately; resolving once keeps the list a single atomic render, consistent with `test_history_screen.dart`'s existing `_resultsFuture` pattern.
2. Display `verse.reference` where the reference is currently shown. If the map lookup returns `null` (verse since deleted), degrade gracefully: show the raw `result.verseId` with a visible marker distinguishing it from a real reference (e.g. italic + "(verse deleted)" suffix) rather than a bare raw id indistinguishable from a formatting bug — screen reader users need to know this is a missing-verse fallback, not a real reference. Do not throw or leave a blank widget.
3. Remove the now-unused `formatVerseReference` call sites in these two screens. Do not delete `formatVerseReference` itself or its tests (`test/utils/verse_reference_format_test.dart`) — it may still be depended on elsewhere; confirm via grep before considering removal, but removing it entirely is out of scope for this issue regardless.
4. While in `test_history_screen.dart`, note the existing separate `formatLabel` switch (lines ~245-250) checks `'fill_blank'` (snake_case) against `VerseTestResult.testFormat`, which actually stores the enum's `.name` (`fillBlank`, camelCase) — this is an adjacent, same-root-cause bug (same "didn't reuse the shared helper" pattern already fixed in `test_result_screen.dart` via `TestFormatLabel.tryFromName`). Fix it in the same pass by switching to `TestFormatLabel.tryFromName(result.testFormat)` for consistency, since it's a one-line fix in a file already being touched — but keep it as a clearly separate, minimal diff so it doesn't get mixed into the reference-formatting change if reviewed separately.

---

## Acceptance Criteria

- [ ] Test Summary screen shows a consistent, correctly formatted reference for every verse, regardless of bundled-pack or custom origin.
- [ ] Test History screen shows the same normalized reference format (previously showed the raw id).
- [ ] Neither screen relies on `formatVerseReference`'s id-parsing for its reference display.
- [ ] If a verse id can't be resolved to an existing verse, the screen shows a fallback rather than crashing.
