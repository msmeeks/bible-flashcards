# Plan: Preserve scroll position when tapping Memorize on the verse list

**Issues:** #105

---

## Goal

Tapping "Memorize" on the available verse list keeps the list at its current scroll position instead of jumping to the top.

---

## Context

`_AvailableTab` (`lib/screens/verses/verses_screen.dart:320-334`) is a `StatelessWidget` that builds a fresh `ListView.separated` with no `ScrollController` and no stable item `Key`s. Tapping "Memorize" (`~410-414`) calls `provider.markMemorized(verse.id)`, which rebuilds the list via `Consumer<VerseProvider>` with a shrunk verse array; without a controller or keys, the list's scroll-position-restore heuristics can't reliably preserve the offset, especially when the removed item was above the current viewport or pack headers regroup.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/screens/verses/verses_screen.dart` | Convert `_AvailableTab` from `StatelessWidget` to `StatefulWidget` holding a `ScrollController`, attached to the `ListView.separated` at line ~320. Assign a stable `Key` (e.g. `ValueKey(verse.id)` for verse tiles, `ValueKey('header-\$packId')` for pack headers) to each list item so Flutter's element diffing keeps unaffected items' elements/semantics nodes alive across the rebuild. In `_MemorizeButton`'s `onPressed` (~410-414), guard against double-tap the same way as the book-variants-crash fix (an `isMemorizing`-style in-flight guard), since the two sequential awaited calls (`setVerseOfWeek`, `markMemorized`) can otherwise race on a fast double-tap. |

### Steps

1. Per TDD workflow, write a widget test that scrolls the available list partway, taps Memorize on a visible item, and asserts the scroll offset is unchanged (within tolerance) after the rebuild.
2. Convert `_AvailableTab` to a `StatefulWidget`, add a `ScrollController`, wire it to the `ListView.separated`.
3. Add stable `Key`s to list items (verse tiles and pack headers).
4. Add an in-flight guard to `_MemorizeButton.onPressed` to prevent a double-tap race between `setVerseOfWeek`/`markMemorized`.
5. Consider (optional, only if screen-reader QA reveals a problem) a `SemanticsService.announce('${verse.reference} added to memorized', ...)` so screen reader users get confirmation the item was removed, since focus may otherwise silently drop after the tapped tile is removed from the tree.
6. Run the widget test from step 1; manually verify on the emulator: scroll down, tap Memorize, confirm no visual jump.

---

## Acceptance Criteria

- [ ] Scrolling down the available verse list and tapping Memorize keeps the list at the same visual scroll position
- [ ] No double-tap race causes duplicate/inconsistent "verse of week" state
- [ ] Existing list functionality (search, grouping by pack) is unaffected

---

## Pre-Implementation Review

**Security (informational):** `_MemorizeButton.onPressed` is `async` and currently unguarded against double-tap — the same bug class as the book-variants-crash cluster. Since this button is already being touched, add a cheap in-flight guard to avoid a duplicate-write race in `VerseProvider._verses`.

**Accessibility (Major):** A `ScrollController` alone preserves pixel offset but not screen-reader semantic focus — when the tapped tile is removed, TalkBack's traversal can silently reset to the top of the screen even if sighted users see no jump. Assign stable `Key`s to list items so Flutter's diffing keeps unaffected items' semantics nodes alive, and consider an explicit `SemanticsService.announce(...)` confirming the action succeeded.

**Accessibility (Minor):** After the tapped tile is removed, keyboard/D-pad focus that was on it falls back to an OS default rather than the next remaining Memorize button — a jarring focus-order break for switch-access/hardware-keyboard users. Not blocking, but worth a follow-up if QA surfaces it.

**Design:** No existing animation/transition to regress — the list currently has no `AnimatedList`/keyed transitions, so this fix introduces no visual-change risk.

**Privacy:** No PII concerns — `verse.id` is a deterministic, non-personal identifier; safe to use as a stable `Key`.
