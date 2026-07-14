# Plan: Test Modes — remove Recite, refine Type-mode scoring & UX

**Issues:** #165, #161, #162, #166

---

## Goal

Retire the ineffective Recite format and make Type mode the reliable spoken/typed recall path: consistent punctuation-insensitive scoring, a word-level diff of the answer, and no premature auto-advance.

---

## Context

Recite mode (on-device speech-to-text) is unreliable in practice; Type mode plus the keyboard's built-in dictation covers the same need better. Removing Recite (#165) simplifies the test flow and lets the remaining work concentrate on Type mode: scoring currently preserves apostrophes so contractions mismatch (#161), the word-level LCS alignment is computed but discarded so users see only an aggregate score with no per-word feedback (#162), and Type mode auto-advances ~1s after scoring so users can't study the result (#166).

---

## Implementation Notes

### Internal ordering

Do **#165 first** (removes the Recite branches these other changes would otherwise have to carry), then **#161** (normalization), then **#162** (consumes #161's normalization). **#166** is independent of the others.

### Files to Modify

| File | Change |
|------|--------|
| `lib/screens/test/test_enums.dart` | Remove `TestFormat.recite` and its `label` switch arm. |
| `lib/screens/test/test_session_screen.dart` | Remove `_buildReciteArea` and all `TestFormat.recite` branches; remove Type-mode timed auto-advance (#166); add explicit advance control + word-diff render (#162). |
| `lib/screens/test/test_screen.dart` | Remove Recite from the format picker. |
| `lib/models/test_result.dart` | `testFormat` comment/string set drops `"recite"`; keep read tolerance for legacy rows (see below). |
| `lib/services/speech_recognition_service.dart` | Delete if used only by Recite; otherwise strip Recite-only paths. |
| `lib/utils/scoring.dart` | Drop the `'` carve-out in `normalize()` (#161); expose LCS alignment as structured diff tokens via a shared helper (#162). |
| `pubspec.yaml` / `android/app/src/main/AndroidManifest.xml` | Remove `speech_to_text` + `RECORD_AUDIO` if Recite was the only consumer. |
| `meta/DESIGN_BRIEF.md` | Remove Recite references: §7 "Test Screen" ("I know it"/"Show me") and the Action Pairs exception example. |
| `docs/features/test-modes.md` | Remove Recite/speech-to-text documentation; document Type-mode diff + no-auto-advance. |

### Steps

1. **#165 Remove Recite.** Delete the `recite` enum member and every branch/switch arm on it across the test flow and format picker. Delete `SpeechRecognitionService` and the `speech_to_text` dependency + `RECORD_AUDIO` permission if nothing else uses them (grep first). `TestResult.testFormat` is a free-form string and `TestFormatLabel.tryFromName` already returns `null` for unknown names — legacy `"recite"` rows must still load without crashing; verify the results/history UI renders a stored-but-unknown format gracefully (fallback label, no exception). Scrub Recite from `DESIGN_BRIEF.md` and the feature doc.
2. **#161 Scoring normalization.** In `scoring.dart`'s `normalize()`, change the strip regex so apostrophes are removed like all other punctuation (remove `'` from the preserved set). This flows through `computeScore` and transitively `computeReferenceScore`. Update/add unit tests for straight vs curly apostrophe and omitted apostrophe cases.
3. **#162 Word diff.** Refactor the word-level LCS so the alignment is returned as structured tokens (e.g. `{word, op: match|insert|delete}`) from a shared helper reused by both `computeScore` and the render. Alignment uses the normalized comparison (post-#161); render uses the original casing/punctuation. In the Type-mode scored view, render the diff inline: matches neutral (`onSurface`), deletions (source words missing from the answer) with strikethrough + muted color, insertions (typed words not in source) with a distinct non-color cue (underline or leading symbol) + color. Use theme tokens only (`error`/`success`/`onSurfaceVariant` via `AppColors`), never raw hex. Add `Semantics` so screen readers convey missed/extra words, not color alone.
4. **#166 No auto-advance.** In the Type-mode check handler, remove the `Future.delayed(...)` → `_recordAndAdvance` timer. Reveal the score and keep it on screen; add an explicit advance control (e.g. "Next", `FilledButton` per Action Pairs) shown only in the scored state that calls `_recordAndAdvance` on tap. Guard against double-record/re-entrancy. The control must be a ≥48dp target, focusable, and keyboard-activatable; manage focus to it on reveal.

---

## Acceptance Criteria

- [ ] Recite is not selectable anywhere; the project compiles with `TestFormat.recite` removed.
- [ ] `speech_to_text` + `RECORD_AUDIO` removed if Recite was their only consumer; otherwise justified in the PR.
- [ ] A stored test result with a legacy `"recite"` format loads and renders without error.
- [ ] Typed answers differing from source only by apostrophe presence or glyph (straight/curly) score as a full match; reference scoring otherwise unchanged.
- [ ] After scoring, the Type-mode view shows an inline word diff distinguishing matches, deletions, and insertions, using theme tokens and a non-color cue for each state; screen readers announce missed/extra words.
- [ ] Checking a Type answer does NOT auto-advance; an explicit Next control advances and records exactly once.
- [ ] Recite-specific tests removed; new tests cover apostrophe scoring, diff rendering (match / missing / extra / mixed), and no-auto-advance; suite passes.
- [ ] `DESIGN_BRIEF.md` and `docs/features/test-modes.md` no longer reference Recite.

---

## Pre-Implementation Review

**Design (`DESIGN_BRIEF.md`):**
- Removing Recite requires editing the brief itself: §7 "Test Screen" lists Recite's "I know it"/"Show me" buttons, and the §7 Action Pairs "Exception" cites Recite as the equal-weight either/or example. Both must go so the brief stays accurate.
- The #166 Next control is a forward action → `FilledButton` primary per Action Pairs; do not introduce a `TextButton`.
- The #162 diff must use theme tokens (`error`/`success`/`onSurfaceVariant` via `AppColors`), never raw `Color(0xFF...)` (brief §13).

**Accessibility (WCAG 2.2 AA):**
- Color is never the sole differentiator (brief §11): diff deletions pair color with strikethrough, insertions with an additional non-color cue; add `Semantics` labels so the missed/extra distinction is announced.
- Next control ≥48×48dp, keyboard-activatable; `FocusNode.requestFocus()` after reveal per brief §11 focus-order rule.

**Privacy:**
- Typed input is discarded immediately today (`_typeController.clear()`); the #162 diff must be derived at render time from in-memory data and must NOT introduce any persistence/logging of answer text (`meta/PRIVACY.md`).

**Security:** none — no new data flows or dependencies (removals only).
