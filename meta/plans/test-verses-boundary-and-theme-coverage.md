# Plan: Cover scroll-preservation boundary conditions and Lora font-family regression

**Issues:** #124, #126
**Prerequisite:** complete `test-dedupe-async-settle-helper` first (`verses_screen_test.dart` shares the deduped async-settle helper this plan builds on).

---

## Goal

The verses list's scroll-position preservation is tested at its actual boundary conditions (not just a mid-list case), and the app theme's text styles are verified to resolve to the bundled Lora font family.

---

## Context

Two independent, low-risk test-coverage gaps bundled together as trivial additions: the existing scroll-preservation test only covers a mid-list memorize action, leaving last-item/near-max-scroll/list-empties-to-zero cases unverified; and no test asserts the theme's `fontFamily` actually resolves to `'Lora'` after the switch away from Google Fonts to a bundled asset.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `test/screens/verses/verses_screen_test.dart` | Add three tests: memorizing the last item while scroll is near max extent (no throw, offset clamps); memorizing an item leaving a list shorter than the viewport; memorizing the last remaining item (empty-list state, no `RangeError`, no stale offset). |
| `test/theme/` (new or existing theme test file) | Add a test asserting `theme.textTheme.bodyLarge?.fontFamily == 'Lora'` (and similarly for another representative style) for both light and dark theme variants. |

### Steps

1. Add the three scroll-boundary tests to `verses_screen_test.dart`, reusing the shared async-settle helper from `test-dedupe-async-settle-helper`.
2. Add the Lora font-family assertion test(s) against `lib/theme/app_theme.dart`'s theme construction.
3. Run the affected test files and the full suite.

---

## Acceptance Criteria

- [ ] Test: memorizing the last item near max scroll extent does not throw; offset clamps correctly.
- [ ] Test: memorizing an item leaving a list shorter than the viewport renders without error.
- [ ] Test: memorizing the last remaining item reaches the empty-list state with no crash and no stale scroll offset.
- [ ] Test: theme text styles resolve to `fontFamily == 'Lora'` in both light and dark variants.
- [ ] All existing tests in both files still pass.
