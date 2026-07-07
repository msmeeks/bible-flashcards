# Plan: Lighten dark-theme confidence badge colors

**Issues:** #138

---

## Goal

Strong (success) and Weak (error) confidence badges are clearly readable in dark theme; Learning (warning) is modestly lightened. Light theme is unchanged.

---

## Context

`ConfidenceBadge` (`lib/widgets/confidence_badge.dart`) colors its Strong/Learning/Weak tiers from `successContainer`/`warningContainer`/`errorContainer` + their `on*` pairs. `successContainer`/`warningContainer` are custom tokens defined in `lib/theme/app_colors.dart`'s `AppColors` extension; their current dark values (`#0F3D1E`, `#4A3800`) sit close in luminance to the dark surface (`#1C1917`), reading muddy. `errorContainer`/`onErrorContainer` are **not** overridden anywhere — they fall through to `ColorScheme.fromSeed(...).copyWith(...)`'s Material 3 dark defaults (`#93000A`/`#FFDAD6`) set in `lib/theme/app_theme.dart`'s `dark()` (lines 96-103), which is also too dark per the issue.

The existing `test/theme/contrast_test.dart` already asserts 4.5:1 contrast for `onSuccessContainer`/`successContainer`, `onWarningContainer`/`warningContainer`, and `onErrorContainer`/`errorContainer` — this suite is the acceptance gate for the new values.

## Files to Modify

| File | Change |
|------|--------|
| `lib/theme/app_colors.dart` | Lighten dark `successContainer`/`onSuccessContainer` and `warningContainer`/`onWarningContainer` |
| `lib/theme/app_theme.dart` | Add `errorContainer`/`onErrorContainer` overrides to the dark `ColorScheme.fromSeed(...).copyWith(...)` (lines 96-103), lightened from MD3 defaults |

## Steps

1. In `app_colors.dart`, pick new dark-theme hex values for `successContainer` and `errorContainer` that are visibly lighter/more saturated against `#1C1917` than the current `#0F3D1E`/MD3-default `#93000A`, while keeping `warning` unaffected in hue (green/red respectively, per existing hue-line comments). Lighten `warningContainer` by a smaller amount than the other two, per the issue's explicit "smaller adjustment" note.
2. Add matching `onSuccessContainer`/`onErrorContainer`/`onWarningContainer` adjustments as needed — the existing pattern reuses the *light* theme's container hex as the dark theme's `on*` color (see comments at lines 18-19, 28-29); follow the same reuse approach if it still clears 4.5:1 against the new, lighter container colors, otherwise pick a new `on*` value that does.
3. Since `errorContainer`/`onErrorContainer` aren't currently in the `AppColors` extension (they're real `ColorScheme` fields, not custom tokens), add them directly to the `.copyWith(...)` in `app_theme.dart`'s `dark()` (alongside the existing `primary`/`surface`/`onSurface` overrides at lines 100-102) rather than adding new extension getters.
4. Run `flutter test test/theme/contrast_test.dart` and iterate on the chosen hex values until all three container/on-container pairs meet 4.5:1 in dark theme.
5. Do not touch light-theme values (`_isDark ? ... : <unchanged>` branches) or the Pending badge's `surfaceContainerHighest`/`onSurfaceVariant` — both explicitly out of scope.

---

## Pre-Implementation Review

- **Accessibility gap in the existing test suite:** `contrast_test.dart` only asserts on-color vs. container (4.5:1) and bare `success`/`warning`/`error` vs. `surface` (3:1) — it does **not** assert the *container* colors themselves against `surface` at 3:1 (the WCAG 1.4.11 non-text/UI-boundary check). Since the issue's actual complaint is that containers sit too close in luminance to the surface, add a `containerColor vs. surface >= 3:1` assertion for all three containers to the test suite before iterating hex values, so the fix is verified against the problem that was actually reported, not just the pre-existing on/container check.
- **Design paper-cut:** `errorContainer`/`onErrorContainer` live in `app_theme.dart`'s `copyWith`, while `successContainer`/`warningContainer` live in `app_colors.dart`'s `AppColors` extension — two places to check for future badge-color work. Add a one-line comment in each file cross-referencing the other so a future "add a new tier" change doesn't miss the split location.

---

## Acceptance Criteria

- [ ] Dark-theme `successContainer` and `errorContainer` (and their `on*` pairs) are visibly lighter than current values, verified to still meet 4.5:1 contrast.
- [ ] Dark-theme `warningContainer` is somewhat lighter than current, same contrast requirement.
- [ ] `test/theme/contrast_test.dart` passes with the new values.
- [ ] Light theme badge colors are unchanged.
