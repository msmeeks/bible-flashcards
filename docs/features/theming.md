# Theming & Contrast

## Summary
App ship light and dark Material 3 theme. Dark theme give low-eye-strain option fer evening study; all color/text choice hold WCAG AA contrast (4.5:1 text, 3:1 large UI) in both mode.

## Users / Use Cases
- **Admin**: N/A (no admin role in app)
- **Worker**: User pick light/dark/system in Settings; all screen (test session, review, verse detail) must stay readable under either theme.

## Technologies
- `google_fonts` (Lora serif fer scripture text, system sans fer UI chrome) — brand typography per DESIGN_BRIEF.
- Flutter `ColorScheme.fromSeed` — generate MD3 base palette, then override with hand-picked tokens fer brand color + accessibility.

## Technical Overview
`AppTheme.light()`/`AppTheme.dark()` in `lib/theme/app_theme.dart` build `ThemeData` from a seeded `ColorScheme`, override specific token (primary/secondary/tertiary/surface/error) with brand hex, and attach shared `_buildTextTheme(scheme)` fer text style. `AppColors` extension (`lib/theme/app_colors.dart`) add custom semantic token (success/warning + container/on-container pairs) not present in MD3, and branch on `scheme.brightness` so dark theme get its own tuned hex set instead of reusing light value.

## API Endpoints
N/A — pure client-side theming, no backend.

## Key Files
| File | Purpose |
|---|---|
| `lib/theme/app_theme.dart` | `ThemeData` builder fer light/dark, shared `_buildTextTheme` |
| `lib/theme/app_colors.dart` | `AppColors` extension on `ColorScheme` — success/warning semantic token, brightness-aware |
| `meta/DESIGN_BRIEF.md` | color token table (light + dark hex), typography spec |
| `test/theme/contrast_test.dart` | WCAG contrast-ratio assertion fer text roles + semantic token, both theme |
| `test/helpers/contrast.dart` | luminance / contrast-ratio math helper used by contrast test |

## Technical Detail
### Text color bug (fixed 2026-06-30, issues #97/#101)
`_buildTextTheme` used to build every `TextStyle` off `GoogleFonts.loraTextTheme()`/hardcoded `TextStyle()` without ever setting `color`. In light theme this coincidentally looked fine cuz Google Fonts default near-black text sit on light surface. In dark theme same near-black text sit on dark surface — invisible. This is why fill-in-the-blank test input text (and other body/label text) was unreadable in dark mode; root cause live here, not in test-mode input widget itself. Fix: every text role now `.copyWith(color: scheme.onSurface)` (or construct `TextStyle(..., color: onSurface)` fer chrome roles), so text color always track active theme's `onSurface`.

### Brightness-aware semantic tokens
`AppColors.success`/`successContainer`/`onSuccessContainer` and `warning` equivalent used to be single hardcoded hex shared by both theme (light-tuned only). Now each getter check `_isDark = brightness == Brightness.dark` and return separate hex fer dark. Dark values picked from same hue line (green fer success, gold fer warning) but individually verified ≥4.5:1 (container fg/bg pairs) or ≥3:1 (foreground vs surface) — see `contrast_test.dart`. Notable: dark `onSuccessContainer`/`onWarningContainer` reuse the *light theme's* container hex directly, since that light color already meet contrast against the new darker container fill.

### Contrast test coverage
`test/theme/contrast_test.dart` assert ratio fer: each `TextTheme` role against `scheme.surface`, and each semantic container pair (success/warning/error), fer both `AppTheme.light()` and `AppTheme.dark()`. Any new text role or semantic token must add assertion here before shipping.

## Change Log
| Date | Change |
|---|---|
| 2026-06-30 | Created doc. Fixed dark-theme text invisibility (#97/#101): `_buildTextTheme` now apply `scheme.onSurface` to all roles; `AppColors` success/warning tokens made brightness-aware; added contrast test suite; DESIGN_BRIEF color table updated with dark hex. |
