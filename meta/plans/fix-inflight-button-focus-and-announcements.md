# Plan: Restore keyboard/screen-reader focus and add blocked-dismiss announcement for in-flight actions

**Issues:** #118, #119

---

## Goal

Keyboard and TalkBack users don't lose their place when an in-flight primary action button disables itself, and get an accessible cue when a dismiss attempt is blocked during submission.

---

## Context

The app treats a hardware keyboard as first-class input. Two related a11y gaps were flagged on the same recently-touched dialogs/buttons: disabling a focused button (add-variant dialog submit, verse-list memorize button) while an async op runs clears focus with nothing to restore it; and blocking a dismiss attempt on the add-variant dialog during an in-flight save gives no accessible feedback beyond a visible spinner.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/screens/settings/book_variants_screen.dart` | Capture focus before disabling the submit button; re-request it once submission completes. Add a one-shot `SemanticsService.announce('Please wait…')` (or similar) when a dismiss attempt is blocked by `PopScope(canPop: !isSubmitting)`. |
| `lib/screens/verses/verses_screen.dart` (`_MemorizeButtonState`) | Capture focus before disabling the memorize button; re-request it once `_isMemorizing` clears. |
| `test/screens/settings/book_variants_screen_test.dart` | Add tests: focus is restored after submit completes; blocked dismiss during submission triggers an announcement. |
| `test/screens/verses/verses_screen_test.dart` | Add a test: focus is restored after the memorize action completes. |

### Steps

1. In both button widgets, capture `FocusManager.instance.primaryFocus` (or the specific `FocusNode`) before setting the disabling state, and re-request it in the completion callback (success and failure paths).
2. Add the blocked-dismiss announcement in the add-variant dialog's `PopScope`, firing once per blocked attempt (not on every rebuild while submitting).
3. Add the three tests described above.
4. Run the affected test files and the full suite.

---

## Acceptance Criteria

- [ ] Keyboard focus returns to a sensible control after the add-variant dialog's submit completes.
- [ ] Keyboard focus returns to a sensible control after the memorize button's async action completes.
- [ ] A blocked dismiss attempt on the add-variant dialog during submission triggers an accessibility announcement; a normal dismiss does not.
- [ ] All new and existing tests pass.

---

## Pre-Implementation Review

**Accessibility (sdlc-accessibility-reviewer, self-assessed at triage time):** both issues originate from an accessibility-focused review pass; the fixes are the standard Flutter remediation (capture/restore `FocusNode`, `SemanticsService.announce`) for exactly these gaps and don't introduce new a11y risk. Ensure the announcement doesn't fire repeatedly on rebuild — test explicitly for single-fire behavior.
