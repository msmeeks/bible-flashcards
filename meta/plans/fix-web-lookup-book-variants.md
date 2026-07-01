# Plan: Resolve custom book-name variants before Add Verse web lookup

**Issues:** #108

---

## Goal

Entering a reference that uses a custom book-name variant (configured in Settings → Book Name Variants) on the Add Verse screen resolves correctly during web lookup, instead of failing with a "check spelling" error.

---

## Context

`_lookupVerse` in `lib/screens/verses/add_verse_screen.dart` (~lines 154-186) passes the reference straight to `_esvLookupService.lookup(reference)` / `_lookupService.lookup(reference, _translation)` (lines ~184-186) with no variant resolution. The same normalization already exists at save-time in `_normalizeAndAwaitConfirmation` (~lines 251-293), which loads custom variants via `DatabaseHelper().getCustomVariantLookup()` and resolves the book name before validating. That resolution step needs to run before the lookup call too, so search and save behave consistently.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/screens/verses/add_verse_screen.dart` | In `_lookupVerse`, before calling `_esvLookupService.lookup`/`_lookupService.lookup` (~184-186), load custom variants (`DatabaseHelper().getCustomVariantLookup()`, same silent-fallback-on-error pattern already used in `_normalizeAndAwaitConfirmation`) and resolve the reference's book-name portion via `bookNameToUsfm`/existing normalization helpers, reusing `lib/utils/reference_normalization.dart` where applicable. Ensure this happens *after* the existing `_ensureConsent()`/`_ensureEsvConsent()` gate and while `_isLookingUp` is already `true` (so a double-tap on Search during the new async DB read can't fire two concurrent lookups). If resolution fails (book name doesn't resolve even after checking variants), surface the existing unresolved-book message pattern from the save flow (`'Unrecognized book name. Add a custom variant in Book Name Variants settings, or fix the spelling.'`) via the existing `_lookupError` + `InlineStatusBanner` path — do not reuse the generic `'Invalid reference format...'` message for this distinct failure mode. Consider caching the single `getCustomVariantLookup()` result for reuse by `_normalizeAndAwaitConfirmation` later in the same add-verse flow rather than querying twice. |

### Steps

1. Per TDD workflow, write a test (widget or unit, depending on how lookup is invoked/mocked) that configures a custom book-name variant, enters a reference using it, triggers lookup, and asserts it succeeds rather than raising the spelling-error message.
2. Insert the variant-resolution step into `_lookupVerse` before the lookup service calls, after existing consent checks, reusing `getCustomVariantLookup()` + `bookNameToUsfm` (or `reference_normalization.dart` helpers as appropriate).
3. Route the new "unresolved book name" failure case through the existing `_lookupError`/`InlineStatusBanner(severity: BannerSeverity.error)` path with the save-flow's existing wording, not the generic format error.
4. Verify the consent-dialog copy (if it displays the reference text) reflects the resolved/canonical reference — the thing actually sent over the wire — not the raw user-typed variant.
5. Run the test from step 1; manually verify on the emulator: add a custom variant, search using it on Add Verse.

---

## Acceptance Criteria

- [ ] A reference typed using a configured custom book-name variant resolves and succeeds during web lookup on Add Verse
- [ ] A genuinely unrecognized book name still fails, with an error message that accurately says the book name isn't recognized (not a generic format error)
- [ ] Web lookup and save-time normalization behave consistently for the same input
- [ ] No new logging of raw reference text or resolved variant text

---

## Pre-Implementation Review

**Security (informational):** No new SSRF/injection surface — both lookup services already validate the outbound reference against a fixed pattern and pin the host before use; `bookNameToUsfm` only maps to a closed, hardcoded USFM code set. Confirm the existing silent-catch-and-fallback pattern around `getCustomVariantLookup()` doesn't produce inconsistent behavior between search-time and save-time failures (e.g. a transient DB error at search but not save, or vice versa).

**Security (informational):** Insert the new resolution step after existing consent checks and while `_isLookingUp` is already true/Search disabled, so a double-tap during the new async DB read can't fire two concurrent lookups (same double-tap class of bug flagged in the book-variants-crash cluster).

**Privacy (Medium):** Verify the consent dialog's disclosed content matches what's actually sent — the reference shown to the user in the consent copy must reflect the *resolved* reference, not the raw typed variant, since that's what reaches the network layer.

**Privacy (informational):** Preserve the existing "no verse reference or PII written to any log" invariant already documented in both lookup services when adding the new call site.

**Accessibility (Major):** The new failure mode (book name unresolved) must produce a distinct, accurate error message — reusing the generic "Invalid reference format" string for this case would violate WCAG 3.3.1 Error Identification. Route it through the existing `InlineStatusBanner` (already `Semantics(liveRegion: true)`-wrapped), not a new UI element.

**Design:** No new UI components — reuse the existing `_lookupError` + `InlineStatusBanner` error-messaging pattern already used elsewhere in this screen; keep error copy tone consistent with the existing `ArgumentError` message.
