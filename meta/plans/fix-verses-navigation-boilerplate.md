# Plan: Deduplicate verse-detail navigation and remove redundant long-press handler

**Issues:** #113, #114

---

## Goal

Opening verse detail goes through one shared helper instead of four hand-written `Navigator.push` blocks, and the memorized-list tile no longer has a long-press handler that duplicates its tap behavior.

---

## Context

Converting `pushNamed` calls to imperative `Navigator.push(MaterialPageRoute(...))` pushes expanded a one-line call into a multi-line block, now duplicated three times in `verses_screen.dart` and once in `home_screen.dart`. Separately, `_MemorizedListTile`'s `onTap` and `onLongPress` push the identical route with no distinct behavior — flagged as redundant during the same diff review. Triage self-answered the "give long-press a distinct action vs. drop it" fork in favor of dropping it (see the triage note on #114): there's no existing long-press/context-menu convention elsewhere in the app to extend instead.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/screens/verses/verses_screen.dart` | Add a shared `openVerseDetail(BuildContext context, String verseId)` helper; use it at all three existing inline `MaterialPageRoute` call sites; remove `_MemorizedListTile.onLongPress` (or replace with a distinct action only if a convention is found elsewhere — see brief on #114). |
| `lib/screens/home/home_screen.dart` | Use the shared helper at its verse-detail navigation call site. |
| `test/screens/verses/verses_screen_test.dart` | Update/remove any test that explicitly exercised long-press-to-detail navigation; add/keep coverage that tap still opens verse detail. |

### Steps

1. Add the shared navigation helper (naming/signature at implementer's discretion, per the durable-brief guidance already posted on #113/#114).
2. Replace all four inline `Navigator.push(MaterialPageRoute(...))` call sites with calls to the helper.
3. Remove `_MemorizedListTile.onLongPress`.
4. Update tests accordingly.
5. Run `flutter test test/screens/verses/verses_screen_test.dart` and the full suite.

---

## Acceptance Criteria

- [ ] All four verse-detail navigation call sites use the shared helper.
- [ ] Tapping any of the four affected entry points still opens `VerseDetailScreen` with the correct verse id.
- [ ] Long-pressing a memorized-verse tile no longer triggers a duplicate navigation (handler removed, or replaced with a distinct justified action).
- [ ] All existing and updated tests pass.
