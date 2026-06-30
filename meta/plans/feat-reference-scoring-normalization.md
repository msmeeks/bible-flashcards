# Plan: Reference Scoring Normalization

**Issues:** #43, #44

---

## Goal

Users can type Bible references using any natural separator variant (periods, spaces, word-forms, range connectors) and receive full credit.

---

## Context

Users typing Bible references in text-to-reference test mode are penalized for using natural separator variants. Phil 4.13, Phil 4 13, and Phil 4:13 should all score the same. Likewise, John 3:16 to 17, John 3:16 through 17, and John 3:16-17 should match. Both fixes live in the same normalization step before the existing `_referenceSplitPattern` regex fires in `computeReferenceScore`.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/utils/scoring.dart` | Add `_normalizeReferenceInput()` helper; call it on `typed` only before `firstMatch` |
| `test/utils/scoring_test.dart` | Add test cases for all new separator/range variants |

### Steps

1. **Add `_normalizeReferenceInput(String s) → String` helper** near the top of `lib/utils/scoring.dart` (before `computeReferenceScore`). Apply transformations in this order — order matters (range connectors before bare-space-digit):

   ```dart
   String _normalizeReferenceInput(String s) {
     // Word-form separators → symbols
     s = s.replaceAll(RegExp(r'\bcolon\b', caseSensitive: false), ':');
     s = s.replaceAll(RegExp(r'\bdot\b', caseSensitive: false), '.');
     s = s.replaceAll(RegExp(r'\bdash\b', caseSensitive: false), '-');
     // Range connectors — digit N (to|through) digit M → digit N-digit M
     // Use exact forms to avoid ReDoS (no nested quantifiers)
     s = s.replaceAll(RegExp(r'(\d+)\s+(?:to|through)\s+(\d+)', caseSensitive: false), r'$1-$2');
     // "and" only when already preceded by a chapter:verse token (digit:digit)
     s = s.replaceAll(RegExp(r'(\d+:\d+)\s+and\s+(\d+)(?!\s*\w)', caseSensitive: false), r'$1-$2');
     // Period between digits → colon
     s = s.replaceAll(RegExp(r'(\d+)\.(\d+)'), r'$1:$2');
     // Bare space between digit groups → colon (safe: book-number digits precede letters)
     s = s.replaceAll(RegExp(r'(\d+) (\d+)'), r'$1:$2');
     return s;
   }
   ```

2. **In `computeReferenceScore`**, apply normalization to `typed` only (not `correct`):
   ```dart
   final typedMatch = _referenceSplitPattern.firstMatch(_normalizeReferenceInput(typed.trim()));
   final correctMatch = _referenceSplitPattern.firstMatch(correct.trim()); // unchanged
   ```

3. **Add tests in `test/utils/scoring_test.dart`** inside the existing `computeReferenceScore` group:
   - `Phil 4.13` vs `Phil 4:13` → 1.0
   - `Phil 4 13` vs `Phil 4:13` → 1.0
   - `Phil 4 colon 13` vs `Phil 4:13` → 1.0
   - `Phil 4 dot 13` vs `Phil 4:13` → 1.0
   - `John 3:16 to 17` vs `John 3:16-17` → 1.0
   - `John 3:16 through 17` vs `John 3:16-17` → 1.0
   - `John 3:16 dash 17` vs `John 3:16-17` → 1.0
   - `John 3:16 and 17` vs `John 3:16-17` → 1.0
   - Fuzz: 1000-char string of all digits and spaces completes in < 100ms (bounds check)

---

## Acceptance Criteria

- [ ] `flutter test test/utils/scoring_test.dart` passes with all new separator/range variant cases
- [ ] Fuzz test with 1000-char digit/space string completes within 100ms
- [ ] Manual smoke: open a text-to-reference test, type `Phil 4.13` for Phil 4:13 — scores as correct
- [ ] Manual smoke: type `John 3:16 to 17` for John 3:16-17 — scores as correct

---

## Pre-Implementation Review

**Medium — ReDoS: use exact regex forms listed above.** The Dart Irregexp engine can backtrack catastrophically on patterns with nested quantifiers. The canonical forms in Step 1 have no nested or overlapping quantifiers and are safe. Do not deviate — any change that adds `\s*` inside an outer repetition must be re-audited.

**Low — Scope "and" to post-`:` context.** Global `(\d+)\s+and\s+(\d+)` would rewrite book-number prefixes (e.g., "1 and 2 Thessalonians"). Restrict it to `(\d+:\d+)\s+and\s+(\d+)` as shown above to avoid mangling book names with numeric prefixes.

**Low — Normalize `typed` only.** The `correct` value comes from the encrypted SQLite database and is always in canonical form. Normalizing it wastes cycles and masks data quality bugs.
