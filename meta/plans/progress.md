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

## 2026-06-30 — feat-fill-blank-difficulty.md (issues #98, #99)

Replaced the old fully-deterministic fill-blank algorithm (fixed 3→4→5 step cycle in `blankIndices()`) with a percentage-based density model, addressing both the "predictable which words are blanked" (#99) and "no control over blank count" (#98) reports.

Changes:
- `lib/utils/scoring.dart`: added `blankCountForPercentage(candidateWordCount, percentage)` — pure function, `round(pct% × count)` floored at 1 (20%) or 2 (30/50/75%). Rewrote `blankIndices()` to take a target count + injectable `Random` and return that many randomly-selected, duplicate-free, non-`:` candidate positions (sorted ascending; falls back to all candidates if count exceeds availability).
- `lib/screens/test/test_enums.dart`: new `BlankDensity` enum (20/30/50/75/Random) with `.label`/`.percentage`; `random` rolls one of the four fixed percentages independently per verse.
- `lib/screens/test/test_screen.dart`: new `ChoiceChip` row (single-select, unlike the Format/Direction `FilterChip` rows) shown only when Fill Blank is selected, defaulting to 20%, wrapped in a live region so its appearance/disappearance is announced to screen readers.
- `lib/screens/test/test_session_screen.dart`: threaded `blankDensity` through the constructor (default 20%); each verse re-rolls its own percentage when density is Random, using a single instance-level `Random` shared with format/direction randomization.
- Rewrote `test/utils/scoring_test.dart`'s `blankIndices` group (old hardcoded-position assertions no longer apply) and added a `blankCountForPercentage` group; added `BlankDensityLabel` tests to `test/screens/test/test_enums_test.dart`; added density-row and wiring tests to `test/screens/test/test_screen_test.dart` and a density-affects-blank-count widget test to `test/screens/test/test_session_screen_test.dart`.

All 432 tests pass, `flutter analyze` clean (only pre-existing unrelated deprecation infos). Doc update for `docs/features/test-modes.md` handled by sdlc-doc-writer subagent.
