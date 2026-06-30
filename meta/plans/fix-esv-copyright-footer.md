# Plan: EsvCopyrightFooter accessibility and layering fixes

**Issues:** #80, #81, #82, #83, #87

---

## Goal

Fix `EsvCopyrightFooter`'s accessibility violations (duplicate live-region announcements, missing keyboard focus, undersized tap target) and remove its dependency on the screen layer, plus the related spurious live-region issue in Settings' translation subtitle.

---

## Context

`EsvCopyrightFooter` (`lib/widgets/esv_copyright_footer.dart`) picked up several issues during the ESV-integration review: it announces collapse/expand state twice (#80), its collapsed toggle isn't keyboard-focusable (#81), its collapsed tap target may be under 48×48dp (#82), and it imports `SettingsScreen` directly to navigate, which couples a widget to a screen (#87). A related live-region issue in `settings_screen.dart`'s ESV subtitle (#83) shares the same root cause as #80 — unconditional `liveRegion: true` instead of tracking actual transitions — so it's grouped here for shared fix design.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/widgets/esv_copyright_footer.dart` | Single live-region semantics node tracking real transitions; keyboard-focusable toggle with focus ring; guaranteed 48×48dp tap target; accept `onViewFullTerms` callback instead of importing `SettingsScreen` |
| `lib/screens/review/review_show_screen.dart` | Pass `onViewFullTerms` callback to `EsvCopyrightFooter` |
| `lib/screens/verses/add_verse_screen.dart` | Pass `onViewFullTerms` callback to `EsvCopyrightFooter` |
| `lib/screens/settings/settings_screen.dart` | Fix ESV subtitle's live-region to only announce on actual value transition |

### Steps

1. Extract a small reusable helper (e.g. an `AnnounceOnChange` widget or mixin) that wraps a child in `Semantics(liveRegion: true, label: ...)` only for one frame after its tracked value actually changes — reset via a post-frame callback rather than a plain boolean checked on every `build()`, so an unrelated parent rebuild (theme change, rotation, parent `setState`) can't re-trigger a stale announcement.
2. In `esv_copyright_footer.dart`, collapse the hidden duplicate `Semantics(liveRegion: true)` node and the visible content's own `expanded`/`label` semantics into a single use of the step-1 helper around the visible `Semantics` wrapper.
3. Replace the bare `InkWell`-wrapped collapsed toggle with an `IconButton`-style control with real focus handling (not a bare `GestureDetector`/`InkWell(focusColor:)`, whose default focus indicator can be invisible on light themes) — matching the expanded state's existing `IconButton`. Rely on `IconButton`'s built-in 48×48 minimum target size rather than bolting on a separate `ConstrainedBox`.
4. Remove the `SettingsScreen` import from `esv_copyright_footer.dart`. Add a required `VoidCallback onViewFullTerms` constructor parameter; call it instead of `Navigator.push(MaterialPageRoute(...))`. Update both call sites (`review_show_screen.dart`, `add_verse_screen.dart`) to pass a callback that navigates to `SettingsScreen` and ensure focus returns to the triggering control when the user pops back.
5. In `settings_screen.dart`, apply the step-1 helper to the ESV default-translation subtitle instead of its current unconditional `liveRegion: true`, so opening Settings with ESV already selected doesn't trigger a spurious announcement, while an actual change still announces.

---

## Acceptance Criteria

- [ ] `EsvCopyrightFooter` has exactly one live region in its semantics tree, announcing collapse/expand exactly once per real transition, with no announcement on first mount
- [ ] The collapsed toggle is keyboard/D-pad focusable with a visible focus ring
- [ ] The collapsed toggle's tappable area is at least 48×48dp at all supported text scales
- [ ] `EsvCopyrightFooter` no longer imports `SettingsScreen`; navigation is supplied via callback from both call sites
- [ ] Settings' ESV subtitle produces no spurious live-region announcement when ESV is already the saved default on screen open, but still announces on an actual change
- [ ] Existing widget tests for the footer and Settings still pass; new tests cover the single-announcement and focus behaviors

---

## Pre-Implementation Review

**Accessibility (sdlc-accessibility-reviewer):**

- **Blocker (4.1.3):** "Track previous value, only `liveRegion: true` on transition" is incomplete — an unrelated parent rebuild (theme change, rotation, parent `setState`) can re-trigger an announcement if the live-region node's label is reconstructed while a prior-build live-region flag hasn't cleared from the semantics tree. Gate the live-region node so it only exists for one frame after a real transition (e.g. reset via a post-frame callback), not via a plain boolean checked each `build()`. Apply the same fix to both `esv_copyright_footer.dart` and the Settings ESV subtitle — extract a small reusable helper (e.g. `AnnounceOnChange`) instead of duplicating the pattern in two files.
- **Major (2.4.7):** When replacing the bare `InkWell` collapsed toggle, use an actual `IconButton`/`InkResponse`-style widget with real focus handling — not a bare `GestureDetector` or `InkWell(focusColor: ...)` alone, since `InkWell`'s default focus indicator can be invisible against light themes (insufficient 3:1 contrast per 1.4.11).
- **Major (2.5.8):** Prefer `IconButton`'s built-in 48×48 default over relying on intrinsic `Row` sizing plus a `ConstrainedBox` bolted on.
- **Minor (2.4.3):** After the `onViewFullTerms` callback navigates to Settings and the user pops back, focus should return to the control that triggered navigation.

These points are folded into the Steps above (step 1 adds the post-frame-reset detail and the shared helper; step 2 specifies `IconButton`-based focus, not bare `InkWell`; step 4 adds the focus-return requirement).
