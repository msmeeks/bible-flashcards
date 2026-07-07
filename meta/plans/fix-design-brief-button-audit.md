# Plan: App-wide dialog button styling audit

**Issues:** #133
**Prerequisite:** merge `chore/settings-cleanup`, `fix/recite-aloud-speech`, and `fix/flashcard-translation-readonly` first. All three touch files this plan also edits (`data_management_screen.dart`, `test_session_screen.dart`, `verse_detail_screen.dart`) — this plan should land last to avoid rebasing dialog-styling edits on top of larger structural changes to the same files. Also independent of `feat/add-verse-confirmation-redesign` (that plan owns Add Verse's own dialogs; this plan explicitly excludes them to avoid duplicate edits to the same lines).

---

## Goal

Every confirm/cancel dialog and action-pair button row in the app uses `FilledButton` for the primary/forward action and `OutlinedButton` for the secondary/negative action, positioned per `meta/DESIGN_BRIEF.md`'s Action Pairs convention.

---

## Context

A grep across `lib/` for `AlertDialog(` found 16 dialogs in 8 files (excluding Add Verse's own dialog, tracked separately under #128). 13 already have the right primary side (`FilledButton`) but use plain `TextButton` for cancel/negative instead of `OutlinedButton`. Two dialogs use `TextButton` on both sides and need the primary side upgraded too. One dialog is a single-button informational dismiss, not an action pair, and is out of scope.

## Files to Modify

| File | Dialog | Change |
|------|--------|--------|
| `lib/app.dart:146` | notification opt-in | `TextButton` "No thanks" → `OutlinedButton` |
| `lib/screens/settings/book_variants_screen.dart:54` | add variant | `TextButton` "Cancel" → `OutlinedButton` |
| `lib/screens/settings/data_management_screen.dart:271` | Export Data | `TextButton` "Cancel" → `OutlinedButton` |
| `lib/screens/settings/data_management_screen.dart:351` | Save Locally | `TextButton` "Cancel" → `OutlinedButton` |
| `lib/screens/settings/data_management_screen.dart:434` | Import Data | `TextButton` "Cancel" → `OutlinedButton` |
| `lib/screens/settings/data_management_screen.dart:571` | Replace All Data? | `TextButton` "Cancel" → `OutlinedButton` (keep error-colored `FilledButton` primary as-is) |
| `lib/screens/settings/settings_screen.dart:424` | Verse-of-week probability | `TextButton` "Cancel" → `OutlinedButton` |
| `lib/screens/settings/settings_screen.dart:558` | Clear test history | `TextButton` "Cancel" → `OutlinedButton` (keep error-colored `FilledButton` primary) |
| `lib/screens/settings/settings_screen.dart:588` | Clear Activity History | `TextButton` "Cancel" → `OutlinedButton` (keep error-colored `FilledButton` primary) |
| `lib/screens/settings/test_history_screen.dart:64` | Clear Test History | `TextButton` "Cancel" → `OutlinedButton` (keep error-colored `FilledButton` primary) |
| `lib/screens/test/test_session_screen.dart:350` | Microphone access needed | Both sides currently `TextButton` — make the forward action (open app settings) `FilledButton`, "Cancel" `OutlinedButton` |
| `lib/screens/verses/verse_detail_screen.dart:148` | Remove from memorized? | Both sides currently `TextButton` — make "Remove" an error-colored `FilledButton`, "Cancel" `OutlinedButton` |

**Out of scope / no change:**
- `lib/screens/verses/add_verse_screen.dart:117` (ESV/BSB consent dialog) — owned by `feat/add-verse-confirmation-redesign`.
- `lib/screens/settings/settings_screen.dart:367` ("Cannot enable") — single-button informational dismiss, not an action pair; leave as `TextButton` "OK" per the design brief's allowance for inline dismissals.
- `lib/screens/settings/data_management_screen.dart:624` (Connect Google Drive?) and `:776` (Delete Drive Backup?) — **removed entirely** by `chore/settings-cleanup` (#130). Do not style these; re-grep for `AlertDialog(` in this file after that plan merges to confirm they're gone before starting this one, in case new dialogs were added in the interim.

## Steps

1. Note: since `bible-flashcards` is Android-only, "note" in dialogs referencing "app settings" refers to Android system settings deep-link, not any other platform — no cross-platform conditional needed.
2. For each row in the table above, swap the widget type only — do not change dialog copy, `barrierDismissible`, or destructive-action red coloring already present on some `FilledButton`s (e.g. Clear/Delete/Replace actions keep their error-container styling; only the button *type* and its counterpart change).
3. Confirm button order matches the convention: primary right/top, secondary left/bottom, in every `actions: [...]` list touched.
4. For the two full-redesign dialogs (`test_session_screen.dart:350`, `verse_detail_screen.dart:148`), verify the newly-added `FilledButton`'s `onPressed` callback is unchanged from the prior `TextButton`'s — only the widget/style changes, not behavior.
5. Run the existing accessibility/contrast test suite (`test/theme/contrast_test.dart`) after changes — `OutlinedButton` styling is theme-driven (`outlinedButtonTheme` in `app_theme.dart`), so no new contrast values should be needed, but confirm nothing regresses.
6. For the two new `FilledButton`s at `test_session_screen.dart:350` and `verse_detail_screen.dart:148`, use the existing destructive-button pairing already established at `data_management_screen.dart:571,776` (`backgroundColor: cs.error`, `foregroundColor: cs.onError`) rather than inventing new style params.

---

## Pre-Implementation Review

All spot-checked locations (app.dart:146; data_management_screen.dart:271/351/434/571/624/776; test_session_screen.dart:350; verse_detail_screen.dart:148) match the plan's line numbers and button-type descriptions exactly — plan is accurate and ready to execute. No security/privacy findings (pure widget-type swaps; `onPressed` callbacks unchanged). Accessibility: `OutlinedButton`/`TextButton` share the same semantics role, so screen-reader behavior doesn't regress on the simple swaps; the two full-redesign rows are the only elevated-risk spots (copy/paste could swap `onPressed` handlers), already called out in step 4.

---

## Acceptance Criteria

- [ ] Every `AlertDialog` with a cancel + confirm action pair uses `OutlinedButton` for cancel and `FilledButton` for confirm.
- [ ] No action pair anywhere in the app uses `FilledButton.tonal` for one side and a differently-weighted style for the other.
- [ ] Bare `TextButton` remains only on genuine inline links/dismissals not part of a forward/cancel pair.
- [ ] Button order (right/top = primary, left/bottom = secondary) is consistent everywhere an action pair appears.
