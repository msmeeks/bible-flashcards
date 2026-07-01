# Plan: Fill-in-the-Blank Difficulty Control (Percentage-Based Density + Randomized Positions)

**Issues:** #98, #99

---

## Goal

The user can choose how many words get blanked in a fill-in-the-blank test (as a percentage of verse length, with a random-per-verse option), and repeat reviews of the same verse blank different words each time instead of always the same ones.

---

## Context

`blankIndices()` (`lib/utils/scoring.dart`) currently selects blank positions via a fully deterministic cycling step (3→4→5→3→…), so both the *number* of blanks and *which* words get blanked are a fixed function of a verse's word count — no randomness, no user control. This makes fill-blank tests predictable (users memorize which words are missing rather than recalling the verse) and doesn't scale well across the wide range of flashcard lengths the app supports (single short verses up to multi-verse cards).

The fix has two independent parts that must land together since both touch the same function and need the same RNG-injection mechanism for testability: a new percentage-based density *setting* on the test setup screen (#98, superseding an earlier fixed-escalating-probability design that didn't account for variable verse length), and randomized *position* selection given a target blank count (#99).

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/screens/test/test_enums.dart` | Add a new enum for blank density, analogous to `TestFormat`/`PromptDirection` (e.g. values for 20%/30%/50%/75%/Random). |
| `lib/screens/test/test_screen.dart` | Add a new `ChoiceChip`-based single-select control (**not** `FilterChip` — density is mutually exclusive, unlike Format/Direction which are multi-select) shown only when `TestFormat.fillBlank` is in `_selectedFormats`, following the existing `SectionLabel` + `Semantics(explicitChildNodes: true)` + `Wrap` layout pattern used for Format/Prompt direction. Default selection: **20%**. Wrap the conditional section in `Semantics(liveRegion: true)` so screen readers are notified when it appears/disappears as Fill Blank is toggled (matching the `_ErrorCard` live-region precedent already in this file). Thread the selected value down to `TestSessionScreen` via constructor, matching the existing `selectedFormats`/`selectedDirections` prop-threading pattern. |
| `lib/utils/scoring.dart` | Add a pure, unit-testable function that takes a candidate word count + chosen percentage and returns the blank count to use: `round(percentage × candidateWordCount)`, floored at **1** for the 20% option and **2** for 30/50/75%. For **Random**, the *caller* rolls one of {20,30,50,75} independently per verse and passes the result through this same function — keep the roll and the count-derivation as separate concerns. Update `blankIndices()` (or its replacement) to accept the already-computed blank count as an input, then randomly select that many distinct positions from the candidate (non-`:`) positions using an injectable/seedable `Random` parameter (defaulting to a real instance) so tests stay deterministic. If the computed count exceeds available candidate words, use all available. |
| `lib/screens/test/test_session_screen.dart` | Wire the density selection (and, for Random, a per-verse roll) into blank generation when building each fill-blank card. |
| `test/utils/scoring_test.dart` | Replace the existing hardcoded-position assertions (which assumed the old deterministic step-cycle) with seeded-RNG tests: percentage-to-count math (including the 1-vs-2 floor split), position-selection producing valid/duplicate-free/non-`:` results, and count-exceeds-availability fallback. |

### Steps

1. Add the density enum to `test_enums.dart`.
2. Add the percentage-to-blank-count pure function to `scoring.dart`, with the 20%→min-1 / 30-75%→min-2 floor rule.
3. Update `blankIndices()` to take a target count and an injectable `Random`, returning a randomly-selected duplicate-free subset of candidate positions (still excluding `:` tokens).
4. Add the `ChoiceChip` density control to `test_screen.dart`, conditionally shown, default 20%, with the live-region wrapper for its appearance/disappearance.
5. Thread the selection through to `test_session_screen.dart`; for Random, roll a fresh percentage per verse when building each fill-blank card.
6. Update `scoring_test.dart` for the new seeded-RNG-based behavior.

---

## Acceptance Criteria

- [ ] Test setup screen shows a 20%/30%/50%/75%/Random `ChoiceChip` row when Fill Blank format is selected, hidden otherwise, defaulting to 20%
- [ ] A fixed percentage produces `round(percentage × candidate word count)` blanks per verse, floored at 1 (20%) or 2 (30/50/75%)
- [ ] Random re-rolls one of the four percentages independently per verse in the test
- [ ] Verses with fewer candidate words than the computed count blank all available candidate words without error
- [ ] Given the same verse and count, repeated generations with different RNG state produce different position sets
- [ ] `:` separator tokens are never selected; no duplicate positions within one generation
- [ ] All of the above is deterministically unit-testable via an injectable/seedable RNG
- [ ] The conditional density control's appearance/disappearance is announced to screen readers (live region), matching the existing `_ErrorCard` pattern

---

## Pre-Implementation Review

**Security:** No concerns — purely local randomization logic, no network/auth/DB/injection surface. Confirmed the non-cryptographic RNG choice is appropriate (test difficulty randomization is not security-sensitive). Only non-security note: validate the percentage/count math against edge cases (very small word counts, boundary percentages) in tests.

**Privacy:** No concerns — local, ephemeral UI selection state (not persisted, matching other test setup controls), no new PII, logging, or consent impact. Doesn't affect the existing "typed test input is never persisted" rule.

**Accessibility:**
- Base `FilterChip`/`Wrap`/`Semantics` pattern is keyboard/focus-correct to reuse.
- **Major:** The conditional section (appears/disappears with Fill Blank toggle) must be wrapped in a live region so screen-reader users know new controls appeared — the plan now includes this, following the `_ErrorCard` precedent in `test_screen.dart`.
- **Minor:** Don't auto-move focus into the new chip row on appearance; let it sit in natural document order. Confirm the default-selected chip is visually distinguishable by more than color alone.

**Design:**
- **Major:** Use `ChoiceChip`, not `FilterChip` — per `meta/DESIGN_BRIEF.md`'s chip-usage convention, `FilterChip` is for independent multi-select (Format, Direction) while `ChoiceChip` is for mutually-exclusive single-select, which is what a 5-option density picker is. Copying the Format section's chip type verbatim would be a semantic mismatch even though visually similar. (Reflected in the plan above.)
- A `Slider`-based pattern (like `ReviewCountControls`) doesn't fit here — density is a fixed discrete set including a non-numeric "Random" option, which doesn't map to a continuous slider position. Reuse the chip-group *layout* (`SectionLabel` + `Semantics(explicitChildNodes: true)` + `Wrap`) but with `ChoiceChip`.
- Reuse the existing `SizedBox(height: 24)` spacing rhythm already used between sections on this screen.
