# Plan: Design Brief Typography and Button Convention Consistency

**Issues:** #155, #156

---

## Goal

The recite-aloud transcript caption uses the correct typography role, and the design brief documents the destructive-button convention already in consistent use across the app.

---

## Context

Two small design-consistency gaps surfaced by review: the "Heard: ..." transcript caption in the recite-aloud test session uses the serif `bodyMedium` role reserved for verse-preview text rather than the sans caption role (#155); and three destructive confirmation dialogs consistently use a filled, error-colored button for their affirmative action, but the design brief never names this as a documented convention (#156), risking future screens reinventing it inconsistently.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/screens/test/test_session_screen.dart` | Change the transcript caption's text style from `bodyMedium` to `bodySmall` |
| `meta/DESIGN_BRIEF.md` | Add a line under Buttons/Action Pairs documenting the destructive primary action convention |

### Steps

1. Change the "Heard: ..." caption's `textTheme.bodyMedium` to `textTheme.bodySmall`.
2. Add a line to `meta/DESIGN_BRIEF.md`'s Buttons/Action Pairs section: "Destructive primary action: `FilledButton` styled with `cs.error`/`cs.onError`."

---

## Acceptance Criteria

- [ ] The transcript caption renders with `bodySmall`, not `bodyMedium`
- [ ] `meta/DESIGN_BRIEF.md` documents the destructive-action button convention
