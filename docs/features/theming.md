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
| `test/theme/font_family_test.dart` | assert `bodyLarge`/`headlineSmall` resolve `fontFamily == 'Lora'`, both theme |

## Technical Detail
### Text color bug (fixed 2026-06-30, issues #97/#101)
`_buildTextTheme` used to build every `TextStyle` off `GoogleFonts.loraTextTheme()`/hardcoded `TextStyle()` without ever setting `color`. In light theme this coincidentally looked fine cuz Google Fonts default near-black text sit on light surface. In dark theme same near-black text sit on dark surface — invisible. This is why fill-in-the-blank test input text (and other body/label text) was unreadable in dark mode; root cause live here, not in test-mode input widget itself. Fix: every text role now `.copyWith(color: scheme.onSurface)` (or construct `TextStyle(..., color: onSurface)` fer chrome roles), so text color always track active theme's `onSurface`.

### Brightness-aware semantic tokens
`AppColors.success`/`successContainer`/`onSuccessContainer` and `warning` equivalent used to be single hardcoded hex shared by both theme (light-tuned only). Now each getter check `_isDark = brightness == Brightness.dark` and return separate hex fer dark. Dark values picked from same hue line (green fer success, gold fer warning) but individually verified ≥4.5:1 (container fg/bg pairs) or ≥3:1 (foreground vs surface) — see `contrast_test.dart`. Dark `onSuccessContainer` reuses the *light theme's* `successContainer` hex directly, since that light color still meet 4.5:1 against the lightened dark container fill. Dark `onWarningContainer` can *not* reuse its light counterpart the same way (issue #138) — it's a dedicated dark-only hex (`#FFF2CC`) tuned separately.

`errorContainer`/`onErrorContainer` are real MD3 `ColorScheme` fields, not custom `AppColors` tokens, so their dark overrides live in `app_theme.dart`'s `dark()` instead of `app_colors.dart`. They used to fall through to the seed-generated MD3 defaults (`#93000A`/`#FFDAD6`); as of #138 both are explicitly overridden (`#D6000F`/`#FFE9E6`) fer the same contrast reasons as success/warning.

### Contrast test coverage
`test/theme/contrast_test.dart` assert ratio fer: each `TextTheme` role against `scheme.surface`, each semantic container pair (success/warning/error) at ≥4.5:1, fer both `AppTheme.light()` and `AppTheme.dark()`. A dedicated dark-only group also assert each container (success/warning/error) at ≥3:1 against `surface` (WCAG 1.4.11 UI-boundary check, #138) — light theme wasn't re-verified here since it was untouched by #138. Any new text role or semantic token must add assertion here before shipping.

### Lora base TextTheme bug (fixed 2026-07-03)
`_buildTextTheme` built its Lora base from `const TextTheme().apply(fontFamily: 'Lora')` — every field on the default `TextTheme()` constructor is null, and `.apply()` is a `field?.copyWith(...)` no-op, so Lora was never actually attached to any role; ThemeData silently fell back to default Material/Roboto. Fix: `loraBase` now built from `Typography.englishLike2021.apply(fontFamily: 'Lora')`, a fully populated default theme, so the family and per-role overrides take effect. Covered by `test/theme/font_family_test.dart`.

## Change Log
| Date | Change |
|---|---|
| 2026-07-07 | Fixed dark-theme badge low-contrast against surface (#138): lightened dark `successContainer` (`#0F3D1E`→`#1D7439`) and `warningContainer` (`#4A3800`→`#816100`, smaller jump); gave dark `onWarningContainer` its own hex (`#FFF2CC`, no longer reuses light's `#FFDEA3`); explicitly overrode dark `errorContainer`/`onErrorContainer` (`#D6000F`/`#FFE9E6`) instead of falling through to MD3 seed defaults. Added 3:1 container-vs-surface contrast test group. Light theme and Pending badge tier unchanged. |
| 2026-07-03 | Fixed Lora base TextTheme no-op (`const TextTheme()` → `Typography.englishLike2021`); added `font_family_test.dart`. |
| 2026-06-30 | Created doc. Fixed dark-theme text invisibility (#97/#101): `_buildTextTheme` now apply `scheme.onSurface` to all roles; `AppColors` success/warning tokens made brightness-aware; added contrast test suite; DESIGN_BRIEF color table updated with dark hex. |
