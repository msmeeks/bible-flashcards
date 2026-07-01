# Plan: Fix double-tap crash in Book Name Variants "Add" dialog

**Issues:** #103

---

## Goal

Rapidly double-tapping "Add" in the Book Name Variants dialog no longer crashes the app with a cascading widget-tree corruption.

---

## Context

The "Add" `FilledButton.onPressed` in `lib/screens/settings/book_variants_screen.dart` (~lines 84-113) is `async` but never disabled while `await _db.addBookNameVariant(book, text)` is pending. A second tap before the first completes starts a concurrent invocation; the first invocation's dialog-pop disposes `textController`/`bookFocusNode`/`variantFocusNode` (lines ~119-121), and the second invocation then touches those disposed objects, throwing `Null check operator used on a null value` and cascading into ~40 further widget-tree assertion failures.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/screens/settings/book_variants_screen.dart` | Add an `isSubmitting` boolean in the `StatefulBuilder`'s state (via `setS`). Guard the top of `onPressed` with an early `if (isSubmitting) return;`, set `isSubmitting = true` before the `await`, and reset it to `false` in a `finally` block (not just the success path) so any exception type — not only the already-handled `ArgumentError` — still re-enables the button. Disable the button visually (`onPressed: isSubmitting ? null : ...`) and swap its child for a sized `CircularProgressIndicator` (matching the existing async-button pattern in `add_verse_screen.dart:360-376`/`554-570`: ~18-20dp, `strokeWidth: 2`, colored `cs.onPrimary`, wrapped in `Semantics(liveRegion: true, label: 'Adding variant, please wait')`). Also disable/guard the Cancel button and dialog barrier dismissal while submitting to prevent a race between a cancel-triggered pop and the add's own pop. |

### Steps

1. Per TDD workflow, write a widget test that simulates two rapid taps on "Add" and asserts no exception is thrown and only one variant is added (or the appropriate error surfaces once).
2. Add the `isSubmitting` flag and early-return guard at the top of `onPressed`.
3. Wrap the `await _db.addBookNameVariant(...)` call in `try { ... } finally { setS(() => isSubmitting = false); }`, keeping the existing `catch (e)` handling for `ArgumentError` inside the `try`.
4. Update the button UI: disable while submitting, show the loading spinner + `Semantics(liveRegion: true, ...)` per the established pattern, and disable/guard the Cancel action and barrier dismissal during submission.
5. Run the widget test from step 1; manually verify on the emulator via `bash scripts/emulator.sh start` by rapid double-tapping Add.

---

## Acceptance Criteria

- [ ] Rapid double-tapping "Add" no longer crashes or corrupts the widget tree
- [ ] Only one variant is added per successful submission, even under rapid double-tap
- [ ] The button shows a loading indicator and is disabled while the request is in flight, consistent with the app's existing async-button pattern
- [ ] Any exception during submission (not just `ArgumentError`) correctly re-enables the button
- [ ] Cancel and dialog-barrier dismissal are guarded against racing with an in-flight submission

---

## Pre-Implementation Review

**Security (Medium):** The `isSubmitting` flag must be reset via `try/finally`, not only on the success path — an uncaught exception type (e.g. a transient `sqflite` `DatabaseException`) would otherwise leave the button permanently disabled with no re-enable path.

**Security (informational):** No new authz/injection surface — `addBookNameVariant` already whitelists `bookCode` and validates/trims `variantText` via a `db.transaction`, so SQLite serializes concurrent calls correctly; the crash is purely a UI-state bug (disposed `FocusNode`/`TextEditingController`), not a data-integrity one.

**Design (Major):** Disabling the button without a matching loading spinner would be inconsistent with the app's established async-button pattern (already used twice in `add_verse_screen.dart`). Mirror that pattern exactly, including the `Semantics(liveRegion: true, ...)` wrapper.

**Accessibility (Major):** Disabling the button alone gives screen reader users no explanation of *why* it went unresponsive. Must include the `Semantics(liveRegion: true, label: 'Adding variant, please wait')` announcement, not just `onPressed: null`.

**Accessibility (Major):** Ensure the button keeps the same widget identity/focus node while disabled (still a `FilledButton` with `onPressed: null`, not swapped for a different widget type), so keyboard/switch-access focus isn't stranded.

**Accessibility (Minor):** Guard `isSubmitting` at the very top of the `onPressed` closure (not only via the disabled `onPressed: null` state), since a double-tap within the same frame could still race before the first rebuild disables the button.

**Privacy:** No PII concerns — keep the existing `catch (e)` narrow to `ArgumentError.message` only; don't let the new guard surface raw exception text.
