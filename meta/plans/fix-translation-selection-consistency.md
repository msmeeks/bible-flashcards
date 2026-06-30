# Plan: Translation-selection consistency and ESV availability gating

**Issues:** #73, #77, #88

---

## Goal

Make translation selection (BSB/KJV/WEB/ESV) behave and look consistently everywhere it appears, and gate ESV on actual key availability wherever it's offered.

---

## Context

Settings and Add Verse both let the user pick a translation, but diverge in two ways: Settings always offers ESV even without an API key configured (#73), while Add Verse correctly checks `EsvLookupService.isAvailable`; and the two screens use different control widgets for the same logical choice — `SegmentedButton` in Settings vs `ActionChip` in Add Verse (#88), with the chip also folding usage-note text into the tappable control. Separately, the "Verse-of-week probability" label in Settings has drifted from the underlying `audioInterruptProbability`/`audioInterruptEnabled` field and pref-key names (#77) — unrelated to translation selection but in the same file and worth fixing in the same pass.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/screens/settings/settings_screen.dart` | Gate ESV segment behind `EsvLookupService.isAvailable`; switch translation control to match Add Verse's idiom (or vice versa, see Steps); address probability/interrupt naming divergence |
| `lib/screens/verses/add_verse_screen.dart` | Switch `ActionChip` to `SegmentedButton<String>`; move cap/usage note to static caption text |
| `lib/services/esv_lookup_service.dart` | Expose a cheap way to check `isAvailable` without requiring a constructed `http.Client` (if not already trivial) |
| `lib/models/settings.dart` / `lib/providers/settings_provider.dart` | Add a comment near `audioInterruptProbability`/`audioInterruptEnabled` noting the intentional UI rename (lighter option), or rename fields/keys with a migration (heavier option — pick based on review) |

### Steps

1. Confirm `EsvLookupService.isAvailable` (`lib/services/esv_lookup_service.dart:32`) can be checked cheaply; it currently requires an instance. Decide whether Settings should hold a long-lived service instance or expose a static/cheap check — follow whatever pattern `AddVerseScreen` already uses for the same check.
2. In `settings_screen.dart`, gate the ESV segment of the default-translation control behind that availability check, mirroring `add_verse_screen.dart:38-42`.
3. Standardize both screens on `SegmentedButton<String>` for translation selection: convert `add_verse_screen.dart`'s `ActionChip` to a `SegmentedButton`, and render the "Personal use · 500-verse cap" note as plain caption text beneath it rather than embedded in the tappable control.
4. For #77: add a short comment at the `audioInterruptProbability`/`audioInterruptEnabled` field declarations in `lib/models/settings.dart` noting the UI displays this as "Verse-of-week probability". Do not rename the stored pref keys unless a migration is also written — prefer the comment-only fix to avoid breaking existing users' stored preferences.

---

## Acceptance Criteria

- [ ] Settings cannot present ESV as selectable when no ESV API key is configured
- [ ] Both Settings and Add Verse use the same control idiom (`SegmentedButton<String>`) for translation selection
- [ ] The cap/usage note in Add Verse is static caption text, not part of the tappable control
- [ ] A comment (or migration, if chosen) resolves the naming divergence between "Verse-of-week probability" and `audioInterruptProbability`
- [ ] Existing translation-selection and settings-persistence tests still pass
