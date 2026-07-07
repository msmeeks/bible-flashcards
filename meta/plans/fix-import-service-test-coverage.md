# Plan: Restore ImportService Validation Test Coverage

**Issues:** #142

---

## Goal

`ImportService`/`ImportException` validation paths (malformed/oversized/malshaped import JSON) are covered by unit tests again, closing a coverage regression left by an unrelated Drive-backup cleanup.

---

## Context

`test/services/import_service_test.dart` was deleted as part of the Google Drive backup removal, taking with it 11 unit tests that had nothing to do with Drive — they covered `ImportService`'s validation of oversized/invalid/malshaped import files. `ImportService` itself was never touched by that change. The replacement test (`test/screens/settings/data_management_screen_test.dart`) only checks button widget types, never the actual validation logic. This is a Blocker-severity coverage gap on a data-integrity-critical path (malformed import files silently succeeding or crashing would be a real user-facing risk).

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `test/services/import_service_test.dart` (new) | Recreate the non-Drive-specific test cases against current `ImportService` |

### Steps

1. Read the current `ImportService`/`ImportException` implementation to confirm validation entry points and exception messages are unchanged from before the deletion.
2. Recreate unit tests for each validation failure mode: oversized JSON payload, invalid JSON, wrong root type, wrong `source_app`, `schema_version` too high, missing, or wrong type, oversized `verses` array, oversized `test_results` array, `verses` not a list, and the exact exception messages thrown for each.
3. Do not recreate the `backupCadence`/`lastBackupAt`-specific test groups — those were legitimately Drive-specific and correctly removed.
4. Run the full test suite to confirm no regressions and that coverage of `ImportService` is restored.

---

## Acceptance Criteria

- [ ] Each validation failure mode listed above has a passing unit test exercising `ImportService` directly
- [ ] No Drive-specific test cases are reintroduced
- [ ] `flutter test` passes with the new file included
