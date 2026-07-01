# Plan: Fix Dark Theme Contrast (Text Theme Root Cause + Full Token Audit)

**Issues:** #97, #101

---

## Goal

In dark theme, every piece of app text and every custom semantic color token (success/warning) meets WCAG 2.2 AA contrast, with no screen left unaudited.

---

## Context

The app's shared `TextTheme` (`lib/theme/app_theme.dart`, `_buildTextTheme`) is built from `GoogleFonts.loraTextTheme()` and only overrides `fontSize`/`fontWeight` per role — it accepts a `ColorScheme` parameter but never uses it to set `color`. Google Fonts' default text theme bakes in a fixed, light-mode-appropriate (near-black) text color. Because `_buildTextTheme` is reused unchanged for both `light()` and `dark()` `ThemeData`, any widget that renders text via an unstyled shared style (e.g. `tt.bodyLarge`, `tt.titleMedium`) gets near-black text in dark theme too — invisible against dark surfaces. This is directly why the fill-in-the-blank test input (`test_session_screen.dart`) renders typed text that's nearly impossible to read in dark mode (#97).

Separately, `lib/theme/app_colors.dart`'s `AppColors` extension (`success`/`successContainer`/`onSuccessContainer`/`warning`/`warningContainer`/`onWarningContainer`) hardcodes one set of hex values shared identically by both themes, with no dark-brightness-aware variant — a design gap `meta/DESIGN_BRIEF.md` never closes (its dark-theme section only documents `surface`/`onSurface`/`primary` overrides). This is issue #101, which also covers sweeping every other screen for the same "unstyled text style → wrong color in dark theme" root cause, since #97 only closes the gap for the test-session screens.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/theme/app_theme.dart` | **Root cause fix.** `_buildTextTheme(scheme)` must apply `scheme.onSurface` (or the correct `on*` token per role) as `color` on every returned `TextStyle`, not just fontSize/weight. This alone fixes #97's fill-blank/type-mode input visibility, since those `TextField`s already reference `tt.bodyLarge`/`tt.titleMedium`/`tt.headlineSmall` without their own color override. |
| `lib/theme/app_colors.dart` | Give `success`/`warning` (and their container/on-container pairs) brightness-aware values. `ColorScheme.fromSeed()` has no hook for custom extension colors, so pick dark-theme hex values manually from the *same hue lines* already used in light theme (green for success `#276234`, gold for warning `#7A5800`) — do not introduce new hues. Verify each resulting pairing computes to ≥4.5:1 (normal text) or ≥3:1 (large text/UI) against the dark surfaces it's actually drawn on. Implement via a `Brightness`-aware mechanism (e.g. two `ThemeExtension` instances registered per `ThemeData`, or brightness-branching getters) — pick one approach, don't mix both. |
| `lib/theme/app_theme.dart` (`dark()`) | Verify `TextSelectionThemeData` (cursor/selection-handle color, defaults to `primary`) and the `focusedBorder`'s `base.primary` at 2px meet ≥3:1 against `surfaceContainerHighest` in the new dark palette; set explicitly if the default falls short. Verify `navigationBarTheme`'s label/indicator contrast now that `backgroundColor` is unset in `dark()` (light theme sets it explicitly — confirm the dark default is equivalent or set it too). |
| `meta/DESIGN_BRIEF.md` | Update the color-token table to add a Dark column for `success`/`successContainer`/`onSuccessContainer`/`warning`/`warningContainer`/`onWarningContainer`. Fix the existing "Dark theme: surface → ..., onSurface → ..., primary → ..." prose line into a proper table row so it stops drifting out of sync with the code. |
| Sweep targets (verify only; fix inline if a real gap is found) | `lib/screens/verses/add_verse_screen.dart`, `verses_screen.dart`, `verse_detail_screen.dart`, `lib/screens/settings/test_history_screen.dart`, `settings_screen.dart`, `lib/screens/test/test_result_screen.dart`, `test_session_screen.dart`, `lib/screens/home/home_screen.dart`, `lib/screens/review/review_screen.dart`, `lib/screens/history/history_screen.dart`, `lib/widgets/inline_status_banner.dart`, `audio_player_bar.dart`, `verse_card.dart`, `confidence_badge.dart`. Grep for two independent failure modes: (a) unstyled shared text-style usage (should now be fixed automatically by the `app_theme.dart` change, but confirm no call site double-overrides with a hardcoded light color), and (b) raw `Color(0xFF...)` literals or inline `TextStyle(color: Colors.black/...)` overrides in widget code, which bypass the theme layer entirely and violate the design brief's "never use hex literals in widget code" rule. |

### Steps

1. Fix `_buildTextTheme` in `app_theme.dart` to derive text color from the passed `ColorScheme` (per-role: body/title/label text → `onSurface`, any role drawn on a container background → the matching `on*Container` token if applicable). Confirm this alone resolves #97 by checking `test_session_screen.dart`'s fill-blank and type-mode `TextField`s render visible text in dark theme.
2. Give `AppColors` brightness-aware success/warning values, choosing hex values from the existing hue lines and verifying computed contrast ratios against the actual backgrounds each token is composited against (container backgrounds, badge text, etc. — see usage sites in `test_result_screen.dart`, `test_history_screen.dart`, `confidence_badge.dart`, `verse_card.dart`, `inline_status_banner.dart`, `add_verse_screen.dart`, `data_management_screen.dart`).
3. Audit every success/warning usage site for a non-color cue (icon/text label) alongside the color, per WCAG 1.4.1 — don't just fix contrast, confirm color isn't the *only* signal.
4. Verify `TextSelectionThemeData` and focus-border contrast in `dark()`; adjust if needed.
5. Update `meta/DESIGN_BRIEF.md`'s token table with the new dark values.
6. Sweep the listed files for raw hex literals or inline color overrides; fix any found using the same theme-level approach (no scattered one-off `copyWith(color: ...)` patches).
7. Add a test that computes and asserts contrast ratios for the semantic token pairs in both themes (not just visual inspection).

---

## Acceptance Criteria

- [ ] Typed text in dark-theme fill-blank and type-mode test inputs is clearly visible (≥4.5:1)
- [ ] Verse-text labels/context around fill-blank blanks are legible in dark theme
- [ ] Light theme's existing text rendering and contrast are byte-for-byte unchanged
- [ ] `success`/`warning`/their container/on-container pairs have distinct, WCAG-compliant light and dark values, derived from the existing hue lines (not arbitrary new colors)
- [ ] A test computes and asserts contrast ratios for these token pairs in both themes
- [ ] `meta/DESIGN_BRIEF.md`'s color token table documents the new dark values
- [ ] Dark-theme `TextSelectionThemeData` cursor/handle color and focus-border color meet ≥3:1 against their backgrounds
- [ ] Sweep of the listed screens/widgets turns up no remaining raw hex literals or inline color overrides bypassing the theme
- [ ] Fix is applied at the shared theme layer, not via one-off widget-level color patches

---

## Pre-Implementation Review

**Security:** No concerns — pure color/typography derivation, no I/O, no user input, no new dependencies.

**Privacy:** No concerns — no new data collection, PII, logging, or consent-flow impact.

**Accessibility:**
- **Root cause confirmation:** `_buildTextTheme` ignores its `scheme` parameter entirely — the fix belongs there, not just in `app_colors.dart`.
- **Major:** Plan must address `TextSelectionThemeData` cursor/selection-handle contrast (defaults to `primary`, not guaranteed ≥3:1 against the new dark fill colors) and the `focusedBorder`'s 2px `primary` border contrast — neither was in the original issue scope but both are real WCAG risks in the same code path.
- **Major:** Success/warning tokens are used as badge/container backgrounds across many screens — audit each usage for a non-color cue (icon/label), not just contrast ratio (WCAG 1.4.1).
- **Minor:** `dark()`'s `navigationBarTheme` omits `backgroundColor` (light sets it explicitly) — confirm the default still meets contrast.

**Design:**
- Confirms the root cause is `_buildTextTheme` ignoring `scheme` — fix must touch `app_theme.dart` directly, matching the design brief's "never use hex literals in widget code" discipline (i.e. never omit `color` either — always derive from `scheme`).
- New dark success/warning values should be manually chosen from the *same hue lines* as light theme (green/gold), verified individually for contrast — `ColorScheme.fromSeed()` has no mechanism for toning custom extension colors, so this is the only available approach, not a shortcut.
- Recommends making `AppColors` explicitly `Brightness`-aware (two `ThemeExtension` instances, or branching getters) — pick one mechanism, confirm the implementation doesn't mix approaches.
- `meta/DESIGN_BRIEF.md`'s dark-theme documentation is already incomplete/stale (prose fragment instead of a table row) — fix this as part of the same change so it doesn't drift again.
- Sweep step should explicitly grep for both raw `Color(0xFF...)` literals and inline `TextStyle(color: ...)` overrides, not just missing-color oversights.
