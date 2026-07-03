# Plan: Extract shared async-settle test helper

**Issues:** #116

---

## Goal

One shared test helper drains a pending sqflite round-trip in widget tests; no test file reimplements the sequence under its own name.

---

## Context

`test/screens/main_scaffold_test.dart` (`_settleAsync`) and `test/screens/settings/book_variants_screen_test.dart` (`_drainAsync`) implement byte-for-byte identical "pump, pump 100ms, real-delay 200ms, pump" sequences under different names; `test/screens/verses/verses_screen_test.dart` inlines the same pattern twice more. This is a prerequisite for the test-coverage plans that add more tests to these same files (`test-main-scaffold-coverage`, `test-book-variants-coverage`, `test-verses-boundary-and-theme-coverage`), so it should land first to avoid those plans editing the same duplicated helpers independently.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `test/helpers/` (new file, e.g. `async_settle.dart`) | Add `Future<void> pumpUntilAsyncSettled(WidgetTester tester)` implementing the shared pump/delay sequence. |
| `test/screens/main_scaffold_test.dart` | Replace `_settleAsync` with the shared helper. |
| `test/screens/settings/book_variants_screen_test.dart` | Replace `_drainAsync` with the shared helper. |
| `test/screens/verses/verses_screen_test.dart` | Replace the two inline copies (~lines 1800-1806, 1896-1901) with calls to the shared helper. |

### Steps

1. Create the shared helper in `test/helpers/`.
2. Replace all known duplicate/inline implementations with imports of the shared helper.
3. Run the full test suite to confirm no timing regression.

---

## Acceptance Criteria

- [ ] A single shared helper function exists in `test/helpers/`.
- [ ] All four known duplicate/inline call sites use it.
- [ ] All previously passing tests in the three affected files still pass.
