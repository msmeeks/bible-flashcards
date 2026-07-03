# Plan: Cover validation, error, and list-management branches of the Book Name Variants dialog

**Issues:** #122, #123
**Prerequisite:** complete `test-dedupe-async-settle-helper` first (touches the same test file's async-settle helper).

---

## Goal

`book_variants_screen_test.dart` covers the dialog's validation errors, DB-throw handling, Cancel, variant removal, empty-state, and the in-flight-dismiss guard — not just the double-tap fix it currently covers.

---

## Context

The test file is new (first widget test ever added for this rewritten screen) but only covers the double-tap/in-flight-spinner fix. Six other branches are unexercised: empty-book validation, empty-variant-text validation, the add call throwing (dialog stays open, submitting state resets), Cancel, variant removal + list reload, and the empty-list message. Separately, the `PopScope(canPop: !isSubmitting)` guard that blocks dismissal during an in-flight save is untested.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `test/screens/settings/book_variants_screen_test.dart` | Add the six validation/error/list-management tests from #122, plus the blocked-dismiss-during-submission test from #123. |

### Steps

1. Add: submit with no book selected → validation error, no variant added.
2. Add: submit with empty variant text → validation error, no variant added.
3. Add: `_db.addBookNameVariant` throws → dialog stays open, submitting state resets.
4. Add: Cancel closes without adding.
5. Add: `_removeVariant` deletes a row and the list reloads.
6. Add: empty-list "No custom variants yet" state renders.
7. Add: start submit, simulate a pop attempt while submitting, assert dialog still present.
8. Run `flutter test test/screens/settings/book_variants_screen_test.dart`.

---

## Acceptance Criteria

- [ ] All six validation/error/list-management cases from #122 have passing tests.
- [ ] The in-flight-dismiss guard from #123 has a passing test.
- [ ] All existing tests in the file still pass.
