# Plan: Auto-Advance Verse of the Week

**Issues:** #45

---

## Goal

The app automatically picks a new verse of the week every Sunday when the setting is enabled, requiring no manual intervention from the user.

---

## Context

Users want the app to automatically pick a new verse of the week every Sunday without manual intervention. When the setting is on, the app should detect on app open that it is Sunday and a new verse hasn't been selected yet this week, then pick a random non-current verse and set it as the verse of the week. The last-advanced date must be persisted through `AppSettings` (not ad-hoc in SharedPreferences) to match the existing tamper-guard pattern and to be included in backup/restore flows.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/models/settings.dart` | Add `autoAdvanceVerseOfWeek` bool and `lastVerseAdvanceDate` DateTime?; clamp/validate on `fromMap`; add to `copyWith`/`toMap`/`fromMap` |
| `lib/providers/settings_provider.dart` | Persist/load new fields via `_persist`/`load` |
| `lib/providers/verse_provider.dart` | Add `autoAdvanceVerseOfWeekIfNeeded(AppSettings settings)` method |
| `lib/screens/settings/settings_screen.dart` | Add `SwitchListTile` for the new toggle |
| `lib/screens/home/home_screen.dart` | Call `autoAdvanceVerseOfWeekIfNeeded` in `initState` post-frame callback |
| `meta/PRIVACY.md` | Add two new SharedPreferences keys to data table |
| `docs/features/verse-management.md` | Document auto-advance behavior |

### Steps

1. **`lib/models/settings.dart` — add fields:**
   ```dart
   final bool autoAdvanceVerseOfWeek; // default false
   final DateTime? lastVerseAdvanceDate; // default null
   ```
   - In `copyWith`: add `bool? autoAdvanceVerseOfWeek`, `DateTime? lastVerseAdvanceDate`
   - In `toMap`:
     ```dart
     'auto_advance_verse_of_week': autoAdvanceVerseOfWeek ? 1 : 0,
     'last_verse_advance_date': lastVerseAdvanceDate?.toIso8601String(),
     ```
   - In `fromMap` (apply tamper guard for date, same pattern as `lastBackupAt` lines 104–113):
     ```dart
     autoAdvanceVerseOfWeek: (map['auto_advance_verse_of_week'] as int? ?? 0) == 1,
     lastVerseAdvanceDate: () {
       final s = map['last_verse_advance_date'] as String?;
       if (s == null) return null;
       final d = DateTime.tryParse(s);
       if (d == null) return null;
       // Tamper guard: reject far-future dates
       return d.isBefore(DateTime.now().add(const Duration(days: 365))) ? d : null;
     }(),
     ```

2. **`lib/providers/settings_provider.dart` — wire persistence:**
   In `_persist()`:
   ```dart
   await prefs.setBool('auto_advance_verse_of_week', settings.autoAdvanceVerseOfWeek);
   final advDate = settings.lastVerseAdvanceDate;
   if (advDate != null) {
     await prefs.setString('last_verse_advance_date', advDate.toIso8601String());
   } else {
     await prefs.remove('last_verse_advance_date');
   }
   ```
   In `load()`: the keys are already read through `AppSettings.fromMap()` — ensure `prefs.getBool`/`prefs.getString` are added for both keys.

3. **`lib/providers/verse_provider.dart` — add auto-advance method:**
   ```dart
   Future<void> autoAdvanceVerseOfWeekIfNeeded(
     AppSettings settings,
     void Function(AppSettings) onUpdate,
   ) async {
     if (!settings.autoAdvanceVerseOfWeek) return;
     final today = DateTime.now();
     if (today.weekday != DateTime.sunday) return;
     if (settings.lastVerseAdvanceDate != null &&
         _isSameIsoWeek(settings.lastVerseAdvanceDate!, today)) return;
     // Pick a random non-current verse
     final candidates = _verses.where((v) => !v.isVerseOfWeek).toList();
     if (candidates.isEmpty) return;
     final picked = candidates[Random().nextInt(candidates.length)];
     await setVerseOfWeek(picked.id);
     onUpdate(settings.copyWith(lastVerseAdvanceDate: today));
   }

   // ISO week comparison (handles year boundary)
   bool _isSameIsoWeek(DateTime a, DateTime b) {
     final aMonday = a.subtract(Duration(days: a.weekday - 1));
     final bMonday = b.subtract(Duration(days: b.weekday - 1));
     return aMonday.year == bMonday.year &&
         aMonday.month == bMonday.month &&
         aMonday.day == bMonday.day;
   }
   ```

4. **`lib/screens/settings/settings_screen.dart` — add toggle** under the Notifications section (after the notification-type `SegmentedButton` tile, around line 121):
   ```dart
   SwitchListTile(
     title: const Text('Auto-advance verse of the week'),
     subtitle: const Text('Picks a new verse every Sunday'),
     value: settings.autoAdvanceVerseOfWeek,
     onChanged: (v) => settingsProvider.update(settings.copyWith(autoAdvanceVerseOfWeek: v)),
   ),
   ```

5. **`lib/screens/home/home_screen.dart` — trigger on app open.** Inside the existing `initState` `addPostFrameCallback`, after `loadVerses()`, add:
   ```dart
   final settings = context.read<SettingsProvider>().settings;
   await context.read<VerseProvider>().autoAdvanceVerseOfWeekIfNeeded(
     settings,
     (updated) => context.read<SettingsProvider>().update(updated),
   );
   ```
   The `autoAdvanceVerseOfWeekIfNeeded` method is idempotent (ISO-week guard inside it), so no extra in-flight flag is needed in the widget.

6. **`meta/PRIVACY.md`** — add two rows to the SharedPreferences data table:
   - `auto_advance_verse_of_week` (bool) — user preference for auto-advance feature
   - `last_verse_advance_date` (ISO-8601 string) — tracks when VoW was last auto-advanced; used to prevent re-advancing within the same week

7. **Add tests:**
   - `autoAdvanceVerseOfWeekIfNeeded` does nothing when setting is off
   - Does nothing when today is not Sunday
   - Does nothing when already advanced this ISO week
   - Advances when today is Sunday and week hasn't been advanced
   - Handles empty candidate pool without crashing
   - `_isSameIsoWeek` handles December 28 – January 3 year boundary

---

## Acceptance Criteria

- [ ] `flutter test` passes with all new auto-advance tests
- [ ] Settings screen shows "Auto-advance verse of the week" toggle
- [ ] With toggle off: app open on Sunday leaves verse of week unchanged
- [ ] With toggle on and Sunday: verse of week changes on first app open
- [ ] Opening app twice on the same Sunday: verse changes only once
- [ ] Settings → Export includes `auto_advance_verse_of_week` and `last_verse_advance_date` in exported JSON

---

## Pre-Implementation Review

**Medium — Race condition resolved.** By placing the idempotency guard (`_isSameIsoWeek`) inside `autoAdvanceVerseOfWeekIfNeeded` in `VerseProvider` (not in the widget), the method is safe to call multiple times in a session — it's a no-op after the first advance. No widget-level lock needed.

**Medium — Tamper guard.** The `lastVerseAdvanceDate` deserialization in Step 1 rejects far-future dates using the same pattern as `lastBackupAt` (settings.dart lines 104–113). This prevents an attacker with ADB/root access from permanently suppressing auto-advance by setting a far-future date.

**Medium — Backup/restore coverage.** Routing `lastVerseAdvanceDate` through `AppSettings` and `_persist` ensures it is included in export/import and Drive backup flows, preventing a surprise advance after restore.

**Informational — Empty candidate pool.** The `if (candidates.isEmpty) return;` guard in Step 3 prevents `RangeError` when the user has only one verse (the current verse of the week).

**Informational — ISO week boundary.** The `_isSameIsoWeek` helper computes the Monday of each date's week and compares calendar dates (not just weekday numbers), correctly handling the Dec 28 – Jan 3 cross-year case.
