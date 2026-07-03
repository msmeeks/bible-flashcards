# Plan: Cover persistent-shell core promise and root-level back-to-exit branch

**Issues:** #120, #121
**Prerequisite:** complete `test-dedupe-async-settle-helper` first (touches the same test file's async-settle helper).

---

## Goal

`main_scaffold_test.dart` verifies both that pushed sub-screen state survives a tab switch, and that the root-level (no-nested-history) back-press branch is actually exercised.

---

## Context

The persistent-shell redesign's whole point is that a tab's pushed sub-screen state survives switching away and back — no existing test covers this. Separately, the back-press handler's "no nested history, treat as root-level" branch (as opposed to "pop a sub-screen") is never exercised, so a regression that blackholed all back-presses would go unnoticed.

Note: if `fix-main-scaffold-tab-and-back-nav` (issue #115: back-press redirects to Home instead of exiting) lands before or alongside this plan, write the #121 test against whatever the resulting root-level behavior is at that point (Home-redirect or exit) rather than assuming the pre-#115 exit-only behavior.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `test/screens/main_scaffold_test.dart` | Add a test: push into `VerseDetailScreen` from the Verses tab, switch to Home, switch back to Verses, assert the detail screen (not the list) is still shown. Add a test: with the active tab's nested navigator having no history, trigger a back-press and assert the handler takes the root-level path (not silently swallowed) — asserting whatever that path currently does (exit, or Home-redirect if #115 has landed). |

### Steps

1. Confirm whether `fix-main-scaffold-tab-and-back-nav` has merged; if so, read its resulting back-press behavior before writing the #121 assertion.
2. Add the tab-switch-preserves-sub-screen test.
3. Add the root-level back-press branch test.
4. Run `flutter test test/screens/main_scaffold_test.dart`.

---

## Acceptance Criteria

- [ ] A test confirms sub-screen state on one tab survives switching to another tab and back.
- [ ] A test confirms the root-level back-press branch (no nested history) is exercised and behaves as currently implemented.
- [ ] All existing `main_scaffold_test.dart` tests still pass.
