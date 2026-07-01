# Plan: Fill-in-the-blank lenient book-name scoring + display cleanup

**Issues:** #107, #36

---

## Goal

Fill-in-the-blank test questions accept recognized book-name abbreviations the same way Type-mode already does, and the fill-blank UI shows only the user's typed text (no field labels/placeholders) plus the expected word beneath incorrect blanks, with check/X icons as the sole correct/incorrect indicator.

---

## Context

`_onBlankCheck` in `lib/screens/test/test_session_screen.dart:401-431` grades each blanked token with a bare exact-string match, so a blank landing inside a reference's book name (e.g. "Thessalonians" in "1 Thessalonians 5:19") rejects valid abbreviations ("Thess", "Th") that Type-mode already accepts via `_scoreAnswer()` → `computeReferenceScore` (lines ~124-135). Separately, issue #36 asks for pure UI cleanup: remove the `labelText: 'Blank N'` field labels and any placeholder text, stop clearing typed text after scoring (currently `_blankControllers[i].clear()` at line ~416), and replace textual "correct/incorrect" labeling with the expected word shown beneath wrong blanks — keeping the existing check/X `suffixIcon`. Both issues touch the same function and the same rendering block (`_buildFillBlankArea`, lines 661-777), so they ship as one cluster to avoid overlapping edits.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/utils/scoring.dart` | Add `scoreBlankedBookNameTokens(correctAnswer, answerTokens, blankedTokenValues, {customVariants})` near `computeReferenceScore`/`splitAnswerTokens`, reusing `referenceSplitPattern` + `bookNameToUsfm`. Identifies which token indices fall in the book-name span, reconstructs the typed span (typed at blanked positions, actual at non-blanked), resolves both to USFM via `bookNameToUsfm`, and returns per-index correctness. Must scope strictly to the reference's book-name span — do not apply to verse-body blanks. |
| `lib/screens/test/test_session_screen.dart` | `_onBlankCheck` (~401-431): call the new scoring function for book-name-span blanks when the answer is a reference; keep exact-match fallback for verse-text blanks and chapter/verse-number blanks. Stop calling `_blankControllers[i].clear()` (~416) so typed text persists after scoring. `_onBlankRetry` (~432-442): explicitly clear controllers before re-focusing, since retry previously relied on the check handler's clear. `_buildFillBlankArea` (~661-777): remove `labelText`/placeholder, wrap each blank `TextField` in `Semantics(label: 'Blank N of M', textField: true)` to preserve an accessible name, replace `errorText` correct/incorrect *label* text with the expected word shown via the existing `errorText` slot (reuse it, don't add a new widget), delete the dead `helperStyle` (line ~696, no `helperText` ever set), and swap `Icons.check`/`Icons.close` → `Symbols.check_circle_rounded`/`Symbols.cancel_rounded` to match the app's Material Symbols Rounded standard already used elsewhere in this file. Wrap both icons in `Semantics(label: 'Correct'/'Incorrect')` so success is announced too, not just failure. |
| `test/utils/scoring_test.dart` | Cover: single-token book name (no numeral) blanked with abbreviation; multi-token book name with only name-word blanked; multi-token with only numeral blanked; multi-token with both blanked (correct/incorrect); typed value that doesn't resolve to any book (stays incorrect); custom variants respected; regression — no book-span blanks or refToText direction unaffected. |
| `test/screens/test/test_session_screen_test.dart` | Add an integration-level check for the lenient book-name blank scoring, plus a check that typed text remains visible in the field after scoring and disappears/resets correctly on retry. |

### Steps

1. Per TDD workflow, write the `scoring_test.dart` cases first (all bullet points above), confirm they fail against the current `_onBlankCheck`/no-op scoring function.
2. Implement `scoreBlankedBookNameTokens` in `scoring.dart`.
3. Wire it into `_onBlankCheck`, keeping exact-match fallback for non-book-name blanks.
4. Remove `_blankControllers[i].clear()` from `_onBlankCheck`; add an explicit clear in `_onBlankRetry` before refocusing.
5. Update `_buildFillBlankArea`: remove label/placeholder, add `Semantics` wrapper per blank, reuse `errorText` for the expected-word display, delete dead `helperStyle`, swap icon family, add `Semantics` labels to both check/X icons.
6. Add/verify contrast of the expected-text-on-error styling in both light and dark themes (reuses existing `errorContainer`/`onErrorContainer` tokens from the dark-theme-contrast work in PR #102, but confirm at the new usage as body text rather than a short label).
7. Add the `test_session_screen_test.dart` integration checks.
8. Run `flutter test`, `python3 -m ruff check .` equivalent for Dart (`flutter analyze`), and manual smoke test on the emulator: fill-blank test with a reference blank spanning the book name, typing an abbreviation.

---

## Acceptance Criteria

- [ ] Typing a recognized book-name abbreviation ("Thess", "Th") into a blank inside a reference's book-name span is scored correct, matching Type-mode behavior
- [ ] Fill-blank text fields show no field label and no placeholder text
- [ ] User-typed text remains visible in each blank after scoring; retrying a blank clears the field for a fresh attempt
- [ ] After scoring, incorrect blanks show the expected word (not a "correct"/"incorrect" text label); check/X icons remain as the correctness indicator
- [ ] Screen readers announce an accessible name for each blank field and announce correct/incorrect state on both success and failure, not just failure
- [ ] All new and existing scoring/test-session tests pass

---

## Pre-Implementation Review

**Accessibility (Blocker) / Design (Critical):** Removing `labelText` with no replacement deletes the only accessible name for each blank — both reviewers independently flagged this. Must wrap each `TextField` in `Semantics(label: 'Blank N of M', textField: true)`.

**Accessibility (Blocker):** Correct blanks currently get zero accessible feedback (bare `Icon` widgets aren't exposed with a label). Wrap both check and X icons in `Semantics(label: 'Correct'/'Incorrect')`.

**Design (Major):** Reuse the existing `errorText` mechanism for the expected-word display rather than inventing a new `Text` widget — it's already the MD3-native pattern the brief mandates (no `SnackBar` for errors). Delete the dead `helperStyle` line while touching this block.

**Design (Major):** Swap `Icons.check`/`Icons.close` (default Material Icons) to `Symbols.check_circle_rounded`/`Symbols.cancel_rounded` to match the app's Material Symbols Rounded standard already used elsewhere in this same file and in `_ScoreReveal`.

**Design (Major) / Privacy (Medium):** `_onTypeCheck` still clears `_typeController` immediately while fill-blank will now preserve typed text — a cross-mode inconsistency. Either align both modes or explicitly document why fill-blank and type-the-verse diverge in the PR description.

**Security/Privacy (informational):** Confirm `scoreBlankedBookNameTokens` is scoped strictly to the book-name span of the current reference (via `referenceSplitPattern`), not applied to arbitrary blanked verse-body words, to avoid coincidental false-positive matches. No logging of typed vs. expected text. Consider a defensive length cap on the blank `TextField` consistent with existing `maxVariantLength`/`maxCustomVariants` bounds in `book_name_variants.dart`, though this is low-severity (single-user, on-device).

**Privacy (Medium):** Ensure `_onBlankRetry` clears controllers before re-focusing now that the automatic clear-on-check is removed, or a previous (possibly incorrect) attempt will linger in the field when retrying.

**Accessibility (Major):** Verify contrast of the expected-text display against `errorContainer` in both themes — this is new, longer body text (not just a short label), so re-verify 4.5:1 in both light and dark mode specifically for this string.
