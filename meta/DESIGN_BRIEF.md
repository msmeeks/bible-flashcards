# Design Brief — Bible Flashcards

## 1. Product Tone

Calm, focused, reverent without stuffiness. The app supports Scripture memorization — a contemplative activity. Not gamified. Scripture text is always the most prominent element.

Design influences: Kindle (typography focus), Bear notes (warm neutrals), Material 3.

## 2. Target Device

Google Pixel 9 Pro — 1344×2992px, ~489dpi. Flutter logical pixels. Test at 375dp, 400dp, 450dp widths.

## 3. Color Palette

All values chosen for WCAG AA contrast (4.5:1 text, 3:1 UI).

### Primary — Deep Teal
| Token | Hex | Usage |
|---|---|---|
| `primary` | `#1B5E6B` | Primary buttons, active nav indicator, FAB |
| `primaryContainer` | `#C8E9EE` | Filled chip backgrounds, selected card tint |
| `onPrimary` | `#FFFFFF` | Text/icons on primary |
| `onPrimaryContainer` | `#001F24` | Text on primaryContainer |

### Secondary — Warm Sand
| Token | Hex | Usage |
|---|---|---|
| `secondary` | `#7D5A3C` | Secondary buttons, pack labels |
| `secondaryContainer` | `#F5DFC8` | "Available" verse card tint |
| `onSecondary` | `#FFFFFF` | |
| `onSecondaryContainer` | `#2B1700` | |

### Tertiary — Muted Gold
| Token | Hex | Usage |
|---|---|---|
| `tertiary` | `#8A6914` | Stars, score highlights, verse-of-week badge |
| `tertiaryContainer` | `#FDEFC3` | Verse-of-week card background |
| `onTertiary` | `#FFFFFF` | |
| `onTertiaryContainer` | `#281900` | |

### Neutral / Surface
| Token | Hex | Usage |
|---|---|---|
| `surface` | `#F8F5F0` | Screen background (warm white) |
| `surfaceVariant` | `#EDE7DE` | Card backgrounds, list items |
| `outline` | `#8A7E72` | Dividers, inactive borders |
| `onSurface` | `#1C1917` | Body text |
| `onSurfaceVariant` | `#4D453E` | Secondary/caption text |
| `inverseSurface` | `#312E2B` | Snackbar, audio player bar |
| `onInverseSurface` | `#F5EFE9` | Text on dark surfaces |

### Semantic States
| State | Token | Hex |
|---|---|---|
| Error | `error` | `#BA1A1A` |
| Success | custom `success` | `#276234` |
| Success container | custom `successContainer` | `#C8F0D0` |
| Warning | custom `warning` | `#7A5800` |
| Warning container | custom `warningContainer` | `#FFDEA3` |

Custom success/warning tokens applied via `ColorScheme.copyWith()` + `AppColors` extension class. Never use hex literals in widget code.

Dark theme: surface → `#1C1917`, onSurface → `#EDE7DE`, primary → `#4FBDCF`.

## 4. Typography

**Scripture text: Lora (Google Fonts)** — contemporary serif, bookish warmth.
**UI chrome: system sans (Roboto / Google Sans)** — native Android feel.

| Role | Font | Size | Weight | Usage |
|---|---|---|---|---|
| `headlineLarge` | Lora | 32sp | 400 | Verse text on detail/test screens |
| `headlineMedium` | Lora | 28sp | 400 | Verse card headline |
| `headlineSmall` | Lora | 24sp | 400 | Section headers |
| `titleLarge` | Sans | 22sp | 500 | AppBar screen titles |
| `titleMedium` | Sans | 16sp | 500 | List item primary text |
| `titleSmall` | Sans | 14sp | 500 | Card labels |
| `bodyLarge` | Lora | 16sp | 400 | Verse body text in cards |
| `bodyMedium` | Lora | 14sp | 400 | Verse preview |
| `bodySmall` | Sans | 12sp | 400 | Captions, timestamps |
| `labelLarge` | Sans | 14sp | 500 | Button labels |
| `labelMedium` | Sans | 12sp | 500 | Chip labels, badges |
| `labelSmall` | Sans | 11sp | 500 | Navigation bar labels |

Rules: verse text always Lora, never bold. Reference labels use `titleMedium` (sans) to separate visually. Max line length for verse body: ~72 chars.

## 5. Spacing Tokens

Base unit: 4dp. All values are multiples.

`space4`=4dp, `space8`=8dp, `space12`=12dp, `space16`=16dp, `space20`=20dp, `space24`=24dp, `space32`=32dp, `space48`=48dp, `space64`=64dp.

Screen edge insets: 16dp left/right. No arbitrary pixel values.

## 6. Shape Tokens

| Token | Radius | Usage |
|---|---|---|
| `shapeExtraSmall` | 4dp | Chips, small badges |
| `shapeSmall` | 8dp | Text fields, small buttons |
| `shapeMedium` | 12dp | Cards |
| `shapeLarge` | 16dp | Bottom sheets |
| `shapeExtraLarge` | 28dp | FAB |
| `shapeFull` | 50dp | Icon buttons, avatars |

## 7. Component Patterns

### Verse Card
- Background: `tertiaryContainer` (verse-of-week), `surfaceVariant` (memorized), `secondaryContainer` (available)
- Corner: `shapeMedium`. Padding: 16dp. No shadow.
- Reference: `titleSmall` (sans), above verse text. Verse: `bodyLarge` (Lora).
- Status chip trailing: "Memorized" (success), "In Progress" (tertiary), "Available" (outline).

### Buttons
- `FilledButton` — primary action (one per screen max)
- `FilledButton.tonal` — secondary actions
- `OutlinedButton` — tertiary/cancel
- `TextButton` — inline links, Skip/Later
- `FloatingActionButton` — one per screen max (Add Verse)
- **Never use `ElevatedButton`**

### Input Fields
- MD3 `TextField` with `filled` decoration. Fill: `surfaceVariant`.
- Type-the-verse: `headlineSmall` style, `maxLines: null`.
- Always `labelText` — never placeholder-only (WCAG failure).

### Test Screen
- Prompt card: `tertiaryContainer`, `headlineMedium` Lora, 180dp min height, centered.
- Progress: `LinearProgressIndicator`, 6dp height, `primary`/`primaryContainer` colors.
- Recite mode: "I know it" / "Show me" `FilledButton` side by side.
- Fill-in-blank: inline `TextField` gaps via `Wrap` + `InlineSpan`.
- Score results: per-verse accuracy badges (success ≥90%, warning ≥70%, error <70%).

### Audio Player Bar
- Persistent above `NavigationBar`. `inverseSurface` background. `shapeLarge` top corners.
- Controls: Play/Pause (48dp filled circle), ±5s seek, previous/next.
- All icons: `Semantics(label: ...)` + `Tooltip`.
- Dismissible by swipe down.

## 8. Navigation

**MD3 `NavigationBar`** (not legacy `BottomNavigationBar`). 4 destinations:

| Label | Icon | Screen |
|---|---|---|
| Home | `Icons.home` | Verse of the week + quick actions |
| Verses | `Icons.menu_book` | Memorized + available lists (TabBar within) |
| Test | `Icons.quiz` | Test mode selection + session |
| Settings | `Icons.settings` | App preferences |

Active indicator: MD3 pill (`primaryContainer` bg, `onPrimaryContainer` icon+label). No badges.
Audio player bar sits above `NavigationBar` inside the `Scaffold` body.
Verse Lists uses `TabBar` (MD3 Secondary) with "Memorized" | "Available" tabs.

## 9. Iconography

Material Symbols Rounded (`material_symbols_icons` package). Only Rounded style. Sizes: 24dp (nav/toolbar), 18dp (button leading), 16dp (badge), 64dp (empty states).

## 10. Motion

| Context | Transition | Duration |
|---|---|---|
| Bottom nav switch | `FadeTransition` | 200ms |
| Screen push | `SharedAxisTransition` (z-axis) | 300ms |
| Bottom sheet | Vertical slide + fade | 250ms |
| Test answer reveal | `AnimatedCrossFade` | 250ms |
| Score fill | `AnimatedFraction` | 600ms |

Always respect `MediaQuery.disableAnimations`.

## 11. Accessibility (WCAG 2.2 AA)

- All interactive elements: 48×48dp min touch target
- `Semantics(label: ...)` on all icon-only buttons
- Scripture min `bodyLarge` (16sp); clamp `textScaleFactor` at component level
- Color never sole differentiator — status chips always include icon + color
- Focus order: top-to-bottom, left-to-right; `FocusNode.requestFocus()` after test answer submission
- Audio controls: all have semantic labels, progress reads "X of Y seconds"

## 12. Implementation Notes

- `useMaterial3: true` always
- `ColorScheme.fromSeed(seedColor: Color(0xFF1B5E6B))` then `.copyWith()` for exact values
- `google_fonts` v6+ for Lora via `GoogleFonts.loraTextTheme()`
- Minimum Flutter SDK: 3.22 (Dart 3.4, full MD3 components)
- `flutter_animate` for score fill and reveal only

## 13. What Never To Do

- No `ElevatedButton`
- No `BottomNavigationBar` (MD2)
- No `SnackBar` for errors — use `errorText` on fields or inline error card
- No raw `Color(0xFF...)` literals — only theme tokens
- No `TextStyle(fontFamily: 'Lora')` inline — only via theme textTheme
- No `Scaffold.drawer` as primary navigation
