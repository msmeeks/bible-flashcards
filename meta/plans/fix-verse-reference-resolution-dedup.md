# Plan: Deduplicate verse-reference resolution in Add Verse screen

**Issues:** #111, #125

---

## Goal

A user who fails to resolve a book name via the web-lookup ("Search") path sees the same "Open Book Name Variants settings" shortcut that a failed Save already shows, backed by one shared, tested implementation.

---

## Context

`add_verse_screen.dart` independently re-implements "fetch custom variants → normalize reference → handle unresolved-book failure" in both `_lookupVerse()` and `_normalizeAndAwaitConfirmation()`. The copies have drifted: only the save path sets the flag that reveals the Book Name Variants settings shortcut. The error string is duplicated (with a third, slightly different variant) across sites, and the bare `catch (_) {}` fallback around the custom-variant DB call is untested on the new lookup path.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/screens/verses/add_verse_screen.dart` | Extract a shared async helper (fetch custom variants + call `normalizeReferenceForSave` + classify failure) used by both `_lookupVerse()` and `_normalizeAndAwaitConfirmation()`; hoist the duplicated error strings to shared constants; ensure both call sites set the unresolved-book shortcut-visibility flag consistently. |
| `test/screens/verses/add_verse_screen_test.dart` | Add a test for the unresolved-book case via the web-lookup entry point (mirroring the existing save-path test at ~line 433); add a test that forces `DatabaseHelper().getCustomVariantLookup()` to throw during web lookup and asserts graceful fallback to built-in resolution. |

### Steps

1. Extract the fetch+normalize+classify logic in `_normalizeAndAwaitConfirmation()` and `_lookupVerse()` into one private helper returning the normalization result plus an "unresolved book" boolean.
2. Update both call sites to use the helper and to set the flag controlling the "Open Book Name Variants settings" shortcut identically on unresolved-book failure.
3. Replace the three inline copies of the error strings with shared constants.
4. Add the new web-lookup unresolved-book test (#111) and the throwing-custom-variant-lookup fallback test (#125).
5. Run `flutter test test/screens/verses/add_verse_screen_test.dart` and the full suite.

---

## Acceptance Criteria

- [ ] A failed web lookup due to an unresolved book name shows the "Open Book Name Variants settings" shortcut.
- [ ] One shared definition of the unresolved-book / invalid-format strings, used by both flows.
- [ ] A test covers the unresolved-book case via web lookup.
- [ ] A test covers `getCustomVariantLookup()` throwing during web lookup, asserting graceful fallback.
- [ ] Existing save-path behavior and tests are unchanged.
