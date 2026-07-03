# Plan: Fix tab-count drift, back-navigation UX, and semantics isolation in MainScaffold

**Issues:** #112, #115, #117

---

## Goal

The tab scaffold's navigator-key count always matches its destinations, back-press on a non-Home tab returns to Home before exiting, and inactive tabs are excluded from the accessibility/focus tree.

---

## Context

Three independent findings all land in `lib/screens/main_scaffold.dart`, the persistent-shell nested-navigator-per-tab widget introduced in the recent redesign: a hardcoded tab count that can drift from the destinations list, a back-button UX gap where pressing back on a non-Home tab root exits the app immediately instead of returning to Home first (an explicit product-decision call, resolved during triage in favor of the standard Android "back-to-Home-then-exit" convention — see the triage note on #115), and an `IndexedStack` that keeps inactive tabs' controls reachable via screen-reader swipe/keyboard tab-order even though they're visually hidden.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/screens/main_scaffold.dart` | (a) Derive the navigator-key list length from `_destinations.length` instead of a literal `5`. (b) In the back-press handler, when the active tab's nested navigator has no history to pop, switch to the Home tab (using the same mechanism as tapping a bottom-nav destination) instead of calling `SystemNavigator.pop()`, unless already on Home — only exit from Home's root. (c) Wrap each non-selected tab's `_tabNavigator(...)` child in `ExcludeSemantics(excluding: i != _selectedIndex, ...)` inside the `IndexedStack`. |
| `test/screens/main_scaffold_test.dart` | Add tests: back-press on non-Home tab root switches to Home without exiting; back-press on Home tab root triggers exit; a control inside a non-active tab is absent from the semantics tree and reachable again after switching to it. |

### Steps

1. Replace `List.generate(5, ...)` with `List.generate(_destinations.length, ...)`.
2. In the `PopScope`/back-press handler, add the Home-tab-redirect branch as described; keep the existing "pop nested navigator if it has history" branch unchanged.
3. Wrap each tab's `IndexedStack` child in `ExcludeSemantics`.
4. Add the three new tests described above.
5. Run `flutter test test/screens/main_scaffold_test.dart` and the full suite.

---

## Acceptance Criteria

- [ ] Navigator-key list length is derived from destinations, not a literal.
- [ ] Back-press on a non-Home tab root switches to Home instead of exiting.
- [ ] Back-press on the Home tab root (no nested history) exits the app.
- [ ] Back-press with nested history still pops that history first (unchanged).
- [ ] Inactive tabs' controls are excluded from the semantics tree; switching tabs restores their reachability.
- [ ] All new and existing `main_scaffold_test.dart` tests pass.

---

## Pre-Implementation Review

**Accessibility (sdlc-accessibility-reviewer, self-assessed at triage time):** #117 and #115 are themselves accessibility/UX fixes flagged by a prior a11y-focused review pass; no new a11y risk introduced — `ExcludeSemantics` is the standard Flutter pattern for this exact `IndexedStack` problem. #115's Home-redirect should not introduce a keyboard trap: back-press must remain effective (not silently swallowed) at every tab, which the acceptance criteria explicitly test for.
