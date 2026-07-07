# Plan: Remove fake translation toggle from verse detail screen

**Issues:** #131

---

## Goal

The verse's translation is shown as read-only text, not as an interactive (and non-functional) toggle group.

---

## Context

`lib/screens/verses/verse_detail_screen.dart` renders a `_TranslationSelector` (`SegmentedButton<String>`, lines 198-234) with hardcoded segments `ESV`/`CSB`/`NLT`, backed by local-only state (`_selectedTranslation`, line 27, explicitly commented "UI-only for now") that is never persisted or read anywhere else — selecting a segment does nothing to the actual verse. The real translation value is already displayed correctly, read-only, elsewhere on the same screen via `_MetadataCard` → `_MetaRow(label: 'Translation', value: verse.translation)` (line 261).

## Files to Modify

| File | Change |
|------|--------|
| `lib/screens/verses/verse_detail_screen.dart` | Delete `_TranslationSelector` and its dead state; verse's translation remains visible via the existing `_MetadataCard` row |

## Steps

1. Delete the `_TranslationSelector` widget class (lines 198-234) and its call site (lines 76-79).
2. Delete the now-unused `_selectedTranslation` field (line 27) and any `setState` callback that mutated it.
3. Since `_MetadataCard`'s `_MetaRow(label: 'Translation', value: verse.translation)` (line 261) already shows the real value read-only, no replacement widget is needed at the deleted call site — confirm the surrounding layout (spacing/padding) still looks correct with that widget simply removed rather than swapped for a placeholder.

---

## Acceptance Criteria

- [ ] Verse detail screen shows the verse's translation as a read-only label, not an interactive toggle/segmented control.
- [ ] No dead state (`_selectedTranslation` or related callbacks) remains.
- [ ] Layout renders cleanly with the toggle removed (no leftover empty space or misalignment).
