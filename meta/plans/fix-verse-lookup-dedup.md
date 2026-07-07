# Plan: Deduplicate and Batch Verse-Lookup-by-ID Logic

**Issues:** #140, #141

---

## Goal

Test result and history screens resolve the verses referenced by test results through one shared, batched code path instead of two duplicated, N+1 implementations.

---

## Context

`lib/screens/test/test_result_screen.dart` and `lib/screens/settings/test_history_screen.dart` both independently collect unique verse IDs from test results, resolve each via a `Future.wait` over per-ID `getVerseById` calls, and render an italic "$id (verse deleted)" fallback for verses that no longer exist. This is a DRY violation (#140) and generates one DB round trip per distinct verse rather than a single batched query (#141), which matters for history screens with unbounded result history.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/services/database_helper.dart` (or equivalent DB layer) | Add `Future<Map<String, Verse>> getVersesByIds(Set<String> ids)` using a single `WHERE id IN (...)` query |
| New shared helper (e.g. `lib/services/verse_result_lookup.dart`) | `Future<Map<String, Verse?>> resolveVersesForResults(List<VerseTestResult> results, DatabaseHelper db)` — collects unique IDs, calls the batch method, returns a map (missing IDs simply absent) |
| `lib/screens/test/test_result_screen.dart` | Replace inline `Future.wait` lookup logic with the shared helper; reuse shared deleted-verse fallback rendering |
| `lib/screens/settings/test_history_screen.dart` | Same replacement |

### Steps

1. Add the batched `getVersesByIds` method to the database layer, backed by a single `WHERE id IN (...)` query.
2. Extract the shared `resolveVersesForResults` helper that both screens will call, built on top of the batch method.
3. Extract the deleted-verse fallback rendering (italic "$id (verse deleted)") into a small shared widget/function so both screens render it identically.
4. Update both screens to use the shared helper and shared fallback rendering, removing the duplicated inline logic.
5. Update/add tests: one for the batch DB method (missing IDs excluded from the returned map), one for the shared resolution helper, and confirm both screens' existing widget tests still pass unmodified in behavior.

---

## Acceptance Criteria

- [ ] Both screens use the same shared resolution helper — no duplicated lookup logic remains
- [ ] Verse resolution for a screen's test results happens via a single batched `WHERE id IN (...)` query, not one query per verse
- [ ] Deleted-verse fallback rendering is identical between the two screens and driven by shared code
- [ ] No user-visible behavior change
