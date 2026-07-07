# Plan: Remove Cloud Backup/Google Drive settings + fix app display name

**Issues:** #130, #132

---

## Goal

Data & Backup settings no longer offer Google Drive backup, and the app shows as "Bible Flashcards" everywhere instead of the raw package name.

---

## Context

Two small, unrelated config/cleanup fixes bundled together since both are low-complexity, isolated changes with no other pending work nearby:

- #130: `data_management_screen.dart` has a full "Cloud Backup" section (Connect/Back Up Now/Backup Frequency/Restore from Drive/Delete Drive Backup/Disconnect), backed by `GoogleDriveService` and `SettingsProvider`/`Settings` fields (`lastBackupAt`, `backupCadence`). Removing the UI makes this plumbing dead code — remove it together rather than leaving an orphaned service.
- #132: `android/app/src/main/AndroidManifest.xml` has `android:label="bible_flashcards"` (line 14) instead of a proper display name; `pubspec.yaml`'s `name: bible_flashcards` is the Dart package identifier and should NOT be changed (that would require a much larger rename across imports) — only the manifest label controls the on-device display name.

## Files to Modify

| File | Change |
|------|--------|
| `lib/screens/settings/data_management_screen.dart` | Remove "Cloud Backup" section (~lines 157-230) and all drive-related methods/state |
| `lib/services/google_drive_service.dart` | Delete (no longer referenced after UI removal) |
| `lib/models/settings.dart` | Remove `lastBackupAt`/`backupCadence` fields (drive-only) |
| `lib/providers/settings_provider.dart` | Remove any drive-specific update methods tied to those fields |
| `android/app/src/main/AndroidManifest.xml` | Change `android:label="bible_flashcards"` → `android:label="Bible Flashcards"` |

## Steps

1. **#130.** In `data_management_screen.dart`, delete the "Cloud Backup" header + `ListTile`s (Connect Google Drive / Back Up Now / Backup Frequency / Restore from Drive / Delete Drive Backup / Disconnect Google Drive) and the `_driveSignedIn`/`_driveLoading` state, `_showDriveConsentDialog`, `_doBackup`, `_showRestoreDialog`, `_showDeleteDriveBackupDialog`, `_disconnectDrive`, and the `_driveService` field itself.
2. Delete `lib/services/google_drive_service.dart` entirely — confirmed via grep it's only referenced from `data_management_screen.dart`.
3. Remove all five Drive-only fields from `lib/models/settings.dart` and `lib/providers/settings_provider.dart` (model fields, `copyWith`, `toMap`/`fromMap`, `_persist`/`load`): `lastBackupAt`, `backupCadence`, `driveBackupEnabled`, `driveConsentAt`, `driveConsentVersion` — not just the first two. Confirm via grep none of the five is read anywhere else before removing. Also update `test/models/settings_test.dart` and `test/services/import_service_test.dart`, which reference these fields and will fail to compile once they're removed.
4. `GoogleDriveService` stores a `drive_signed_in` intent flag (not an OAuth token — code comment confirms tokens are never stored, only Play Services/`GoogleSignIn` holds real credentials) in `flutter_secure_storage`, cleared only via the service's own `signOut()`. Deleting the service without clearing this leaves a stale flag in Keystore-backed storage for any user who previously connected. Add a one-time cleanup on next app launch (e.g. in `main.dart` init or a migration step) that deletes the `drive_signed_in` secure-storage key directly, so no orphaned state persists.
5. Leave the "Export Data" / "Save Locally" (SAF) / "Import Data" sections (local JSON backup) completely untouched — only the Google Drive section and its five settings fields are in scope. These local flows don't reference `_driveService` or any of the five fields being removed (confirmed).
6. Note for the PR description/changelog: any backup files a user previously uploaded to their own Google Drive `appDataFolder` are unaffected by this change — the app has no remaining code path to reach or delete them; users would need to manage those manually via Google's own data tools. Worth stating explicitly so this isn't mistaken for a data-deletion feature.
5. **#132.** Change `android:label="bible_flashcards"` to `android:label="Bible Flashcards"` in `android/app/src/main/AndroidManifest.xml:14`. Do not touch `pubspec.yaml`'s `name:` field — that's the Dart/Gradle package identifier, unrelated to the display label, and changing it would require a much larger cross-file rename out of scope for this issue.
6. Rebuild and verify on the emulator (`bash scripts/emulator.sh restart`) that the home screen icon label and recent-apps entry now read "Bible Flashcards".

---

## Acceptance Criteria

- [ ] Data & Backup settings no longer show Cloud Backup or Connect Google Drive sections/options.
- [ ] No dead `GoogleDriveService`/drive-only settings fields remain referenced or unreferenced in the codebase.
- [ ] Local JSON export/import (Save Locally, Export Data, Import Data) is unaffected.
- [ ] App displays as "Bible Flashcards" on home screen icon label, recent apps, and system permissions settings.
