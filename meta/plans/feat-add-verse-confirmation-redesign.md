# Plan: Redesign Add Verse confirmation flow + save-to-Memorized option

**Issues:** #128, #129

---

## Goal

Adding a verse is faster (no redundant accept/dismiss step), always shows the exact reference/text that will be saved via a real confirmation dialog, and lets the user choose to save straight to the Memorized list.

---

## Context

`lib/screens/verses/add_verse_screen.dart` currently has two inline "Card" confirmation steps before a verse is actually saved: an Accept/Dismiss preview after search, and a Confirm & Save/Edit card showing the normalized reference. Both use `FilledButton.tonal` + `OutlinedButton`, which doesn't match the app's now-formalized Action Pairs convention (`meta/DESIGN_BRIEF.md`: primary = `FilledButton`, secondary = `OutlinedButton`). The redesign collapses both inline cards into: (a) direct auto-fill on search success, (b) live reference normalization on focus-loss, and (c) one real `AlertDialog` immediately before save. Issue #129 (save directly to Memorized) is bundled here because it's the same screen and same save path (`_commitSave`), touched by the same PR.

## Files to Modify

| File | Change |
|------|--------|
| `lib/screens/verses/add_verse_screen.dart` | Remove Accept/Dismiss card; add focus-loss reference normalization; replace Confirm & Save/Edit card with a real `AlertDialog`; add "save to Memorized" checkbox |

## Steps

1. **Remove Accept/Dismiss (#128).** In `_lookupVerse()` (lines 191-260), on success, write the fetched verse text directly into the verse text field/controller instead of setting `_preview` to show the inline card. Delete the preview `Card` (lines 429-476), `_preview` state, `_acceptPreview()`/`_dismissPreview()`, and `_previewFocusNode` if nothing else uses it.

2. **Live reference normalization on blur (#128).** Add a `FocusNode` (e.g. `_referenceFocusNode`) to the reference `TextFormField` (currently unattached, line 383). Add a listener: when focus is lost, run the existing `_resolveReference()` logic (lines 167-189) and either update the field text to the normalized form (e.g. "rom 8:28" → "Romans 8:28") or surface the existing unrecognized-book-name error inline. This replaces the need for the save-time normalization card to be the first time the user sees the resolved reference — it's now visible as soon as they leave the field.
   - **Do not reclaim focus to show the blur error.** If normalization fails on blur, surface the inline error text without calling `requestFocus()` back onto the reference field — forcing focus back while the user is deliberately tabbing away (e.g. toward Search or Save) creates a focus trap. Follow the existing pattern where `_referenceFieldError` only surfaces via `validate()`, not by seizing focus.

3. **Real confirmation dialog (#128).** Replace the Confirm & Save/Edit inline `Card` (lines 548-594) with an `AlertDialog` shown from `_saveVerse()`, mirroring the structure of the existing ESV consent dialog (`_ensureConsentFor()`, lines 105-139) for consistency of style within this screen. Content: normalized reference + full verse text. Actions: `FilledButton` "Save" (primary, right) that calls `_commitSave(reference)`, `OutlinedButton` "Cancel" (secondary, left) that dismisses without saving. This dialog is the one place that guarantees the user sees the exact reference/text being saved, even if they hand-edited the reference after normalization without re-triggering blur.
   - Remove `_pendingNormalizedReference` inline-card state/`_confirmFocusNode` in favor of the dialog's own local state.
   - `_commitSave` itself (lines 334-364, `VerseProvider.addCustomVerse`) is unchanged except for step 4's addition.
   - Leave the ESV cap check and consent-dialog flows untouched — out of scope per issue.
   - **On Cancel/dismiss, restore focus explicitly** (e.g. `_searchFocusNode.requestFocus()` or back to the Save button) — mirror `_ensureConsentFor`'s existing `requestFocus()` call after its dialog closes (line ~132-133), so focus doesn't land nowhere after the new confirm dialog is dismissed.

4. **Save-to-Memorized option (#129).** Add a `CheckboxListTile` (not a bare `Checkbox` + adjacent `Text` — `CheckboxListTile` gives label+control as one semantic node with a proper 48dp target) labeled "Add directly to Memorized", near the translation selector, bound to a new `bool _saveAsMemorized = false` state var. In `_commitSave`, pass `isMemorized: _saveAsMemorized, memorizedAt: _saveAsMemorized ? DateTime.now() : null` into the `Verse(...)` constructor (currently line ~342-349, which omits these fields so they default to `false`/`null`). No `DatabaseHelper`/`VerseProvider` changes needed — `is_memorized`/`memorized_at` columns and `Verse.toMap()` already support this.

5. While touching this screen's buttons for the Action Pairs convention, don't also fix the ESV consent dialog's `TextButton` "Cancel" (line 117-130) — that's explicitly covered by the app-wide sweep in the `fix/design-brief-button-audit` plan, not this one, to avoid duplicate edits to the same lines from two plans.

---

## Acceptance Criteria

- [ ] Tapping Search with a valid reference populates the verse text field directly on success; no intermediate Accept/Dismiss card.
- [ ] Losing focus on the reference field triggers normalization (or shows the unresolved-book error), independent of tapping Search.
- [ ] Tapping Save opens an `AlertDialog` showing the final normalized reference and full verse text, with `FilledButton` "Save" and `OutlinedButton` "Cancel".
- [ ] Canceling the dialog returns to the form unchanged (no save occurs).
- [ ] Confirming the dialog saves the verse exactly as before (same normalization/id-generation logic).
- [ ] The ESV cap check and consent-dialog flows are unaffected.
- [ ] User can choose, when adding/saving a verse, whether it goes to the available list (default) or straight to the Memorized list.
