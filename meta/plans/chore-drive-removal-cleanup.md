# Plan: Complete Google Drive Backup Removal Cleanup

**Issues:** #145, #148, #149, #150, #151

---

## Goal

All residual traces of the removed Google Drive backup feature are cleaned up: startup migration is crash-safe, orphaned local settings are cleared, the residual OAuth grant is disclosed to affected users, and all remaining UI/doc copy accurately reflects export/import-only functionality.

---

## Context

Google Drive backup was removed from the app (#130, #132), but several loose ends remain. The startup call to `LegacySettingsMigration` (added to clean up Drive-era flags) has no error handling and could block app launch entirely if the platform channel throws (#145). That same migration only clears one secure-storage flag, leaving several plaintext SharedPreferences keys from the old Drive settings unreferenced but present (#149). Users who previously connected Drive retain an OAuth grant the app can no longer see or revoke, since the `google_sign_in` package was fully removed (#148 — resolved via documentation, not by reintroducing the dependency). Finally, the Settings screen subtitle (#150) and a feature doc (#151) still reference Drive backup by name.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/main.dart` | Wrap the `LegacySettingsMigration` startup call in try/catch (swallow-and-log) |
| `lib/services/legacy_settings_migration.dart` (or equivalent) | Add cleanup of `drive_backup_enabled`, `backup_cadence`, `last_backup_at`, `drive_consent_at`, `drive_consent_version` SharedPreferences keys, best-effort |
| `test/services/legacy_settings_migration_test.dart` | Add a test asserting a thrown `PlatformException` doesn't propagate; add a test asserting the five SharedPreferences keys are removed |
| `CHANGELOG.md` | Add an entry disclosing the residual Drive OAuth grant and how to revoke it |
| `help-docs/` (relevant data-management/backup article) | Add the same disclosure |
| `lib/screens/settings/settings_screen.dart` | Change the Data Management subtitle to drop the Drive backup reference |
| `docs/features/verse-management.md` | Drop the "and therefore ... Drive backup" clause |

### Steps

1. Wrap the `LegacySettingsMigration` call in `main.dart` in try/catch; log the exception, don't rethrow. Add a test simulating a thrown `PlatformException` from the platform channel and asserting startup/migration completes without propagating it.
2. Extend the migration to also delete the five listed SharedPreferences keys, best-effort (no throw if absent). Add a test asserting all five are gone after migration runs, and a no-op case for installs that never had them.
3. Add a CHANGELOG entry and a matching help-docs note explaining that Drive backup access was removed and that previously-connected users can revoke the residual `drive.appdata` grant at https://myaccount.google.com/permissions. Do not reintroduce the `google_sign_in`/`googleapis` dependency.
4. Update the Settings screen subtitle to something like "Export and import your data".
5. Update `docs/features/verse-management.md` to remove the stale Drive backup reference.

---

## Acceptance Criteria

- [ ] An exception thrown during migration does not prevent app startup (test-covered)
- [ ] The five orphaned SharedPreferences keys are removed by migration for existing installs (test-covered)
- [ ] CHANGELOG and help-docs disclose the residual Drive OAuth grant and how to revoke it manually
- [ ] Settings subtitle no longer mentions Google Drive or backup
- [ ] `docs/features/verse-management.md` no longer references Drive backup
