# Plan: Add Verse / review-play UI polish and accessibility fixes

**Issues:** #84, #85, #86, #89, #90

---

## Goal

Fix five independent UI/accessibility/design issues in Add Verse and the review-play screen surfaced by SDLC review: a touch-target sizing risk, a color-only selection state, redundant screen-reader semantics, a misplaced dialog element, and duplicated banner markup.

---

## Context

These five findings touch different widgets in `add_verse_screen.dart` and `review_play_screen.dart` with no shared root cause, but are small enough to bundle into one cluster rather than five tiny PRs. #84 (SegmentedButton may compress below target size) overlaps with the `fix/translation-selection-consistency` cluster's standardization on `SegmentedButton<String>` — implement #84's sizing fix as part of that same control once it lands there, or independently if this cluster ships first; coordinate via `blocked_by` if needed.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/screens/settings/settings_screen.dart` | Ensure default-translation `SegmentedButton` segments meet 48×40 minimum at 375px width (#84) |
| `lib/screens/verses/add_verse_screen.dart` | Add `Semantics(selected:)` + non-color marker to ESV chip/control (#85); move `EsvCopyrightFooter` from `AlertDialog.actions` to `content` (#89); extract shared `InlineStatusBanner` widget for the three duplicated error/warning banners (#90) |
| `lib/screens/review/review_play_screen.dart` | Add `excludeSemantics: true` to the outer Stop/Pause `Semantics` wrapper, or drop it in favor of the `IconButton`'s `tooltip` (#86) |

### Steps

1. **#84:** Verify the default-translation control's rendered segment width at 375px. If compressed below target size, either move the control to its own full-width row below the title, or apply `style: SegmentedButton.styleFrom(minimumSize: Size(48, 40))`. If the `fix/translation-selection-consistency` plan has already converted Add Verse's chip to `SegmentedButton`, apply the same sizing fix there too.
2. **#85:** Add `Semantics(selected: _translation == 'ESV', ...)` to the ESV selection control in Add Verse, and add a non-color marker (e.g. a check icon) when selected, so selection state isn't conveyed by background color alone.
3. **#86:** In `review_play_screen.dart`, add `excludeSemantics: true` to the outer `Semantics(label: ...)` wrapping the Stop/Pause `IconButton` (which already has a `tooltip`), or remove the wrapper entirely and rely on the tooltip — pick whichever keeps existing tap/visual behavior unchanged.
4. **#89:** Move `EsvCopyrightFooter` in `add_verse_screen.dart`'s `AlertDialog` from `actions` into `content`, so it renders as body content rather than inside the button row, consistent with its placement in `review_show_screen.dart`.
5. **#90:** Extract a shared `InlineStatusBanner({required Severity severity, required String message})` widget (severity enum covering error/warning) and use it at all three current call sites (`_lookupError`, `_capWarning`, `_saveError`) in `add_verse_screen.dart`, preserving each banner's existing icon/color.

---

## Acceptance Criteria

- [ ] Default-translation control segments meet minimum touch-target size at 375px width
- [ ] ESV selection state in Add Verse is conveyed via semantics (and ideally a visual non-color marker), not background color alone
- [ ] Stop/Pause control in review-play announces its label exactly once to screen readers
- [ ] `EsvCopyrightFooter` renders in the Add Verse dialog's content area, not its actions row
- [ ] A single `InlineStatusBanner` widget renders all three error/warning banners in Add Verse with unchanged visual appearance
- [ ] Existing widget tests for Add Verse and review-play pass; new tests cover the selected-state semantics and single-announcement behavior
