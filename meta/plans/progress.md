# Iteration Progress

## 2026-06-30 — fix-dark-theme-contrast.md (issues #97, #101)

Root cause: `_buildTextTheme` in `lib/theme/app_theme.dart` accepted a `ColorScheme` but never applied it as `color` on any `TextStyle`, so dark theme inherited Google Fonts' near-black default text color — invisible against dark surfaces (this is why fill-in-the-blank/type-mode test input text was unreadable in dark mode, #97).

Fixed:
- Every `TextTheme` role now derives `color: scheme.onSurface` from the passed scheme.
- `lib/theme/app_colors.dart`'s `AppColors` extension (success/warning semantic tokens) made brightness-aware via `ColorScheme.brightness` branching — previously hardcoded one light-only hex set shared by both themes (#101). Dark values picked from the same hue lines as light (green/gold).
- Verified `TextSelectionThemeData` cursor color and `focusedBorder` (both derive from `scheme.primary`) meet ≥3:1 against dark surfaces/`surfaceContainerHighest` — no override needed.
- Swept the 14 listed screens/widgets for raw hex literals or inline color overrides bypassing the theme — none found, all clean.
- Added `test/theme/contrast_test.dart` (15 tests) computing WCAG contrast ratios for text-vs-surface and semantic token pairs (success/warning/error) in both themes, using a new `test/helpers/contrast.dart` luminance/contrast-ratio helper.
- Updated `meta/DESIGN_BRIEF.md`'s color token table with dark values for success/warning/error and folded the stale prose fragment into a proper table.
- Added `docs/features/theming.md` + `docs/llms.md` index entry.

All 421 tests pass, `flutter analyze` clean (only pre-existing unrelated deprecation infos).

Follow-up (not blocking, logged by design review): dark on-success/on-warning-container colors reuse the light theme's container hex verbatim rather than being independently derived — verified via contrast test, but flagged as a shortcut worth a closer look later. Also, applying `onSurface` uniformly to every text role (incl. `labelSmall`/`bodySmall`) fixes the bug but flattens M3's visual hierarchy; consider swapping de-emphasized roles to `onSurfaceVariant` in a future pass once contrast is reconfirmed for those roles.
