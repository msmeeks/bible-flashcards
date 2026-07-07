# Plan: Fix Add-Verse Focus Restoration and Redundant Reference Resolution

**Issues:** #146, #147, #153

---

## Goal

Closing the save-confirmation dialog on Add Verse returns keyboard/screen-reader focus to the Save control (not Search), and tapping Save no longer triggers two independent, concurrent reference-resolution DB calls.

---

## Context

`lib/screens/verses/add_verse_screen.dart` has two related issues in the same area of code. First (#146, #147, WCAG 2.4.3/2.4.11): the save-confirmation dialog restores focus to the Search button's focus node on close — a pattern correctly used elsewhere for a Search-triggered consent dialog, but wrongly copied here since Save (not Search) opened this dialog. A stale comment also mislabels the restored target as "Save." Second (#153): tapping Save blurs the reference field, firing an async blur-triggered reference-normalization, while the save handler independently performs its own resolution concurrently — both hit the database and mutate state separately, which is wasted work and fragile if the two paths ever diverge.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/screens/verses/add_verse_screen.dart` | Add a dedicated Save focus node (or thread through the invoking control); restore focus to it after the save-confirmation dialog closes. Fix the stale comment. Have `_saveVerse` await/reuse the blur-triggered resolution instead of independently re-running it. |
| `test/screens/verses/add_verse_screen_test.dart` (or equivalent) | Add/extend tests for both fixes |

### Steps

1. Introduce a focus node dedicated to the Save control, distinct from the existing search focus node.
2. After the save-confirmation dialog closes, request focus on the new Save focus node instead of the search focus node. Confirm the Search-triggered consent-dialog flow is untouched and still restores focus to Search.
3. Update the comment near this code to name the correct restored control.
4. For the redundant resolution: make the blur handler's in-flight `Future` (or its completed result) accessible to the save handler, and have `_saveVerse` await/reuse it instead of calling the resolver independently. Handle the case where Save is tapped before the blur-triggered resolution has started/finished.
5. Add a widget test asserting focus lands on the Save control after the save-confirmation dialog closes, while the Search-triggered dialog still restores focus to Search.
6. Add a test (or count assertion via a spy/mock) confirming exactly one reference resolution occurs when Save is tapped after editing the reference field.

---

## Acceptance Criteria

- [ ] Closing the save-confirmation dialog moves focus to the Save control (verified by widget test)
- [ ] The Search-triggered dialog flow (e.g. consent dialog) still restores focus to Search, unaffected
- [ ] The stale comment now names the correct control
- [ ] Tapping Save after editing the reference field triggers exactly one reference resolution, not two
- [ ] Save still correctly awaits resolution completion before proceeding; no change in resolved values
