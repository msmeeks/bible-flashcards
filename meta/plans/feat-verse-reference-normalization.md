# Plan: Normalize Verse Reference to Full Book Name + Standard Format on Save

**Issues:** #100

---

## Goal

Every verse saved from the Add Verse screen — whether typed manually or accepted from a web-lookup preview — is stored with a full book name and a standardized `Book Chapter:VerseStart[-VerseEnd]` reference format, and the user is shown the normalized form before it's committed.

---

## Context

`AddVerseScreen`'s save flow currently persists whatever is in the reference text field verbatim. Both `BibleLookupService` and `EsvLookupService` echo back the *original typed* reference string in their lookup result (not a canonical form), so abbreviated or inconsistently formatted references ("Phil 4:13", "1 Pt 5:7", "John 3.16") can end up stored exactly as typed, regardless of entry path. This undermines display consistency and the assumption `computeReferenceScore` (test scoring) already makes that the *stored* reference is canonical.

The app already has the building blocks: `bookNameToUsfm`/`bookDisplayNames`/`normalizeBookNameKey` (`lib/utils/book_name_variants.dart`) for book-name resolution (including user-added custom variants via `DatabaseHelper.getCustomVariantLookup()`), and `_normalizeReferenceInput()` (`lib/utils/scoring.dart`) for separator/range normalization, currently used only at test-scoring time. This issue applies the same resolution logic at save time instead.

If a book name can't be resolved even after checking custom variants, the save is blocked with a validation error directing the user to the Book Name Variants settings screen — chosen over silently saving unnormalized data, since that would reintroduce the exact inconsistency this issue fixes.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/utils/scoring.dart` (or new `lib/utils/reference_normalization.dart`) | Add a save-time normalization function: resolve the book-name span via `bookNameToUsfm`/`normalizeBookNameKey` (merging in custom variants from `DatabaseHelper.getCustomVariantLookup()`), render the *full* book name via `bookDisplayNames`, and apply separator/range normalization (reuse/adapt `_normalizeReferenceInput()`) to produce the canonical `Book Chapter:Verse[-End]` string. Return a result type distinguishing success (normalized string) from failure (unresolved book name), rather than throwing, so the caller can drive UI state cleanly. |
| `lib/screens/verses/add_verse_screen.dart` | On save, run the reference through the new normalization function. On success, show the normalized reference to the user for confirmation before committing (extend the existing preview `Card`/accept-dismiss flow already used for lookup previews — apply it to manually-typed references too, not just lookup results — so a silent "Rom 8:28" → "Romans 8:28" rewrite is never sprung on the user after the fact). On failure, block the save and surface an error using the existing `InlineStatusBanner` instance already used for `_lookupError`/`_saveError` on this screen, **and** set the reference `TextFormField`'s `validator`/`errorText` so the failure is also programmatically associated with the specific field (not just a generic banner) — screen readers need both the field-level association (WCAG 3.3.1/4.1.3) and the actionable "add a custom variant" guidance the banner provides. Error copy should follow the existing tone/shape (cf. `'Invalid reference format. Try e.g. "Romans 8:28".'`) and end with a directive pointing to Book Name Variants settings — ideally as a tappable link into that screen, mirroring the `onViewFullTerms`-style push-to-Settings pattern already used elsewhere in this file. |

### Steps

1. Write the save-time normalization function, covering: book-name resolution (built-in + custom variants), full-name rendering, and separator/range normalization — returning a clear success/failure result.
2. Wire it into `AddVerseScreen`'s save path for both manual entry and lookup-preview-accepted references.
3. On success, surface the normalized form for user confirmation before the save commits (reuse/extend the existing preview-accept UI rather than building a new one).
4. On failure, block the save; show the error via both the field's `validator`/`errorText` (screen-reader field association) and the existing `InlineStatusBanner` (actionable guidance + link to Book Name Variants settings).
5. Add unit tests covering: known-abbreviation resolution, custom-variant resolution, separator/range normalization, and the unresolved-book-name failure path.

---

## Acceptance Criteria

- [ ] Saving a verse manually with an abbreviated/variant book name stores the full book name form
- [ ] Saving a verse via web lookup (BSB/KJV/WEB/ESV) stores the normalized reference, not the raw typed lookup query
- [ ] Non-standard separators/ranges are normalized to the standard `Chapter:Verse[-End]` form at save time
- [ ] The user sees the normalized reference and confirms before it's committed — no silent rewrite after save
- [ ] A reference whose book name can't be resolved (even after checking custom variants) blocks the save, with the error both linked to the reference field (`errorText`) and surfaced via `InlineStatusBanner` with a path to Book Name Variants settings
- [ ] Custom book-name variants added via Settings are honored during save-time resolution
- [ ] Already-saved verses are untouched (no retroactive backfill)

---

## Pre-Implementation Review

**Security:** No concerns. Reused normalization regexes (`_normalizeReferenceInput`) are simple, bounded, non-backtracking patterns — no ReDoS risk. No SQL injection risk: storage already uses parameterized queries, and normalization only transforms a string before that same sink. Recommendation: cap reference field length (e.g. 200 chars) as cheap defense-in-depth, and ensure the normalized reference is rendered via `Text` widgets only (no markdown/HTML interpolation).

**Privacy:** No concerns — local-only transformation of data the user already chose to store, no new collection/logging/network calls. Confirm the normalization/validation code path has no `print`/`debugPrint`/crash-reporting calls that would echo the raw or unresolved reference string (verse content is user-authored text and must not appear in logs per project rule).

**Accessibility vs. Design — conflicting recommendations, resolved above:**
- Accessibility review: `InlineStatusBanner` alone is insufficient — it's not programmatically linked to the reference field, so screen-reader users navigating field-by-field won't discover which field failed (WCAG 3.3.1 Error Identification, 4.1.3 Status Messages). Recommends field-level `validator`/`errorText`.
- Design review: per the design brief's component patterns, this screen's existing `_lookupError`/`_saveError` `InlineStatusBanner` is the established pattern for save-blocking errors that need an actionable link (vs. plain `errorText`, previously only used for simple presence checks). Recommends keeping `InlineStatusBanner` and adding a tappable Settings link.
- **Resolution written into the plan above: do both.** Use `InlineStatusBanner` for the actionable "go fix this in Settings" guidance (consistent with the screen's existing error pattern), *and* also set the field's `validator`/`errorText` so the error is programmatically associated with the reference field for screen readers. This isn't contradictory — the two mechanisms serve different accessibility needs and can coexist.
- Design review, second finding: do not silently rewrite the reference on save — show the normalized form for confirmation first, reusing the existing lookup-preview accept/dismiss UI. (Reflected in the plan above.)
