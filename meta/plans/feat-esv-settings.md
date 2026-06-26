# Plan: ESV Default Translation Setting

**Issues:** #69
**Prerequisite:** Complete feat/esv-lookup (#67) first — ESV must be a valid translation option before it can be the default.

---

## Goal

Users can set a default translation in Settings; the Add Verse screen opens pre-selected to that translation, and selecting ESV as the default shows an inline personal-use-only notice.

---

## Context

`AppSettings.defaultTranslation` already exists in the model (default value `'ESV'`) and is persisted via `SettingsProvider`. The field is not yet exposed in the UI, so every new install silently defaults to ESV — but the Add Verse screen hardcodes `_translation = 'BSB'`, ignoring the setting entirely. This plan surfaces the control and wires both ends.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/screens/settings/settings_screen.dart` | Add "Default translation" control with ESV notice |
| `lib/screens/verses/add_verse_screen.dart` | Initialize `_translation` from `SettingsProvider.settings.defaultTranslation` |
| `lib/models/settings.dart` | Allowlist `defaultTranslation` in `fromMap` (if not already done in feat/esv-lookup) |
| `test/screens/settings/settings_screen_test.dart` | Add tests for new control |

### Steps

1. **`lib/screens/settings/settings_screen.dart` — Default translation control:**

   Add a new "Verses" (or extend "Appearance") section. Place the control above the Theme setting or in a logical group:

   ```dart
   _SectionHeader(label: 'Verses', textTheme: tt),
   MergeSemantics(
     child: ListTile(
       title: const Text('Default translation'),
       subtitle: settings.defaultTranslation == 'ESV'
           ? Semantics(
               liveRegion: true,
               label: 'ESV is for personal, non-commercial use only.',
               child: Text(
                 'ESV is for personal, non-commercial use only.',
                 style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
               ),
             )
           : null,
       trailing: SegmentedButton<String>(
         segments: const [
           ButtonSegment(value: 'BSB', label: Text('BSB')),
           ButtonSegment(value: 'KJV', label: Text('KJV')),
           ButtonSegment(value: 'WEB', label: Text('WEB')),
           ButtonSegment(value: 'ESV', label: Text('ESV')),
         ],
         selected: {settings.defaultTranslation},
         onSelectionChanged: (selected) {
           settingsProvider.update(
             settings.copyWith(defaultTranslation: selected.first),
             announcement: 'Default translation set to ${selected.first}',
           );
         },
       ),
     ),
   ),
   ```

   Note: At 375dp width, a 4-segment button in a `ListTile` trailing slot may be cramped. If layout testing shows clipping, replace with a full-width `SegmentedButton` below the title row (no `trailing`), or a `DropdownButton`. Verify at 375dp before shipping.

   The ESV notice uses `Semantics(liveRegion: true)` so TalkBack announces it when ESV is selected. When a non-ESV translation is selected, the `subtitle` is null and the notice disappears silently from the tree — that's acceptable since removing content does not need an announcement.

2. **`lib/screens/verses/add_verse_screen.dart` — read default from settings:**

   Replace the hardcoded initializer. In `_AddVerseScreenState`:
   ```dart
   late String _translation;

   @override
   void initState() {
     super.initState();
     // Read from settings; if ESV is default but service not available, fall back to BSB.
     final defaultT = context.read<SettingsProvider>().settings.defaultTranslation;
     _translation = (defaultT == 'ESV' && !EsvLookupService.isAvailable)
         ? 'BSB'
         : defaultT;
   }
   ```

3. **`lib/models/settings.dart` — allowlist guard** (apply here if not done in feat/esv-lookup plan):
   ```dart
   const validTranslations = {'BSB', 'KJV', 'WEB', 'ESV'};
   final rawTranslation = map['default_translation'] as String? ?? 'ESV';
   final defaultTranslation = validTranslations.contains(rawTranslation)
       ? rawTranslation : 'ESV';
   ```

### Tests

`test/screens/settings/settings_screen_test.dart`:
- Default translation control renders with the current `AppSettings.defaultTranslation` selected
- Selecting ESV shows the personal-use-only notice subtitle
- Selecting BSB/KJV/WEB hides the notice subtitle
- Selection calls `settingsProvider.update` with updated `defaultTranslation`

`test/screens/verses/add_verse_screen_test.dart`:
- With `defaultTranslation = 'KJV'` in settings, `_translation` initializes to `'KJV'`
- With `defaultTranslation = 'ESV'` and `EsvLookupService.isAvailable == false`, `_translation` falls back to `'BSB'`

---

## Acceptance Criteria

- [ ] Settings screen has a "Default translation" control showing BSB / KJV / WEB / ESV options
- [ ] Current `AppSettings.defaultTranslation` value is pre-selected in the control
- [ ] Selecting ESV shows "ESV is for personal, non-commercial use only." below the control; announced by TalkBack
- [ ] Selecting any non-ESV translation hides the notice
- [ ] Selection persists via `SettingsProvider` and survives app restart
- [ ] Opening Add Verse pre-selects the translation matching the current default setting
- [ ] With ESV as default but `ESV_API_KEY` absent (dev build), Add Verse falls back to BSB
- [ ] `flutter test` passes with new tests

---

## Pre-Implementation Review

**Security — MEDIUM: Allowlist `defaultTranslation` in `AppSettings.fromMap`.** The raw string from SharedPreferences flows into HTTP lookup calls and verse ID construction. Apply the `backupCadence`-style allowlist guard if not already done in feat/esv-lookup.

**A11y — HIGH: ESV must be in the AddVerseScreen SegmentedButton.** The factory default is already `'ESV'`. If `_translation` is initialized to `'ESV'` but no matching segment exists, Flutter renders the button with nothing selected — a broken state for all new installs. ESV segment addition in AddVerseScreen (from feat/esv-lookup) is a hard prerequisite for this plan.

**A11y — INFO: ESV notice uses `liveRegion: true`.** Ensures TalkBack announces the notice when ESV is selected, without requiring focus to move.

**A11y — INFO: `MergeSemantics` on the tile.** Wrapping `ListTile + SegmentedButton` in `MergeSemantics` keeps the control as a unified focus stop, consistent with the Theme tile pattern in the existing settings screen.

**Design — MEDIUM: Test 4-segment button at 375dp.** If the button clips inside a `ListTile` trailing slot, use a full-width layout or `DropdownButton`. Verify before shipping.

**Design — INFO: Include `announcement:` string.** Pass `announcement: 'Default translation set to ${selected.first}'` to `settingsProvider.update()` for consistent VoiceOver/TalkBack feedback, matching the existing Theme and notification type controls.
