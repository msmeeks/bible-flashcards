# Data Management (Export, Import)

## Summary
Lets users back up and restore their verse library, test history, and app settings as a JSON file, either via the Android share sheet or a direct on-device save, and restore that file via import. Exists so users do not lose progress on reinstall/device change and can move data between devices.

## Users / Use Cases
- **Admin**: N/A (single-user app, no roles)
- **Worker**: User exports data to share or save a backup file, imports a backup file (merge or replace existing data).

## Technologies
- `file_picker` — native Android file picker; used both to open files for import and to write export bytes via SAF `content://` URIs (no `dart:io` `File` calls on raw paths, no temp files for "Save Locally")
- `share_plus` — Android share sheet for the "Export Data" option (writes a temp file in app documents dir, shares it, then deletes it)
- `path_provider` — locates the app documents directory for the share-sheet temp file
- `sqflite_sqlcipher` — transactional insert of imported rows into encrypted SQLite

## Technical Overview
`ExportService` builds a single JSON payload (`schema_version`, `source_app`, verses, optional test results, optional settings) shared by both export paths: share sheet (`shareExport`) and local save (`saveExportToFile`). `ImportService.import()` validates schema/size/array-length, coerces each row, and writes everything inside one `db.transaction`, using `ConflictAlgorithm.ignore` so merge mode never throws on duplicate primary keys. Replace mode deletes `test_results` and `verses` before inserting. The `includeHistory`/`includeSettings` toggles are independent — `includeSettings` controls whether app preferences are bundled, separate from test-history inclusion.

Google Drive cloud backup (`GoogleDriveService`, `driveBackupEnabled`/`backupCadence`/`lastBackupAt`/`driveConsentAt`/`driveConsentVersion` settings fields) was removed entirely in #130. The screen title remains "Data & Backup" but now only contains Export Data / Save Locally / Import Data.

## Key Files
| File | Purpose |
|---|---|
| `lib/screens/settings/data_management_screen.dart` | Settings UI: Export/Save Locally/Import dialogs, file picker invocation |
| `lib/services/export_service.dart` | Builds export JSON payload; `shareExport`, `saveExportToFile`, `buildExportJson` |
| `lib/services/import_service.dart` | Validates and imports backup JSON; size/array caps, row-level validation, transactional write |
| `lib/services/legacy_settings_migration.dart` | One-time startup cleanup unrelated to the current export/import flow — see Technical Detail below |

## Technical Detail

### File picker (import)
`_pickJsonFile()` in `data_management_screen.dart` calls `FilePicker.pickFiles(withData: true, type: FileType.custom, allowedExtensions: ['json'])` and decodes `result.files.firstOrNull.bytes` as UTF-8. It deliberately reads bytes directly rather than opening `result.files.first.path` with `dart:io File`, since SAF can hand back a `content://` URI instead of a real filesystem path on some Android configs — opening that path directly would throw. Returns `null` on cancel.

### Save Locally export
`saveExportToFile()` calls `FilePicker.saveFile(bytes: utf8.encode(json), type: FileType.custom, allowedExtensions: ['json'])`. The picker writes bytes directly through the SAF `content://` URI the user selects — no temp or cache file is created at any point, unlike the share-sheet path. Returns `false` if the user cancels.

### Share-sheet export
`shareExport()` still needs a real file on disk because `share_plus` shares by file path. It writes to `getApplicationDocumentsDirectory()` with a random hex suffix, shares via `Share.shareXFiles`, then deletes the temp file in a `finally` block (best-effort; swallows delete errors).

### Import validation caps
Two independent caps in `ImportService`, both enforced before any row coercion:
- **Byte-size cap**: 5 MB on the raw UTF-8-encoded JSON string (`_maxBytes`), guards against arbitrarily large payloads.
- **Array-length cap**: 50,000 entries on `verses` and on `test_results` (`_maxArrayLength`), enforced separately for each array. Guards against a small-byte-size file containing huge numbers of tiny/repetitive rows that would still cause excessive per-row parse/allocation work.

Per-row validation rejects (skips, does not abort) rows with missing/wrong-typed fields or fields exceeding length limits (e.g. verse text > 2000 chars, reference > 100 chars). `schema_version` must be an int ≤ 1; `source_app` must equal `bible_flashcards`.

### includeSettings naming
The export/save dialogs and `ExportService` use `includeSettings` (not `includeScores`) for the checkbox controlling whether app preferences (audio, notification, theme) are bundled into the payload — distinct from `includeHistory`, which controls test-result inclusion.

### Legacy Drive sign-in flag cleanup (#130)
`google_sign_in`/`googleapis` and `GoogleDriveService` were removed along with the Cloud Backup UI and its five `AppSettings` fields. `GoogleDriveService` previously stored a `drive_signed_in` intent flag (never an OAuth token) in `flutter_secure_storage` for any user who had connected Drive. `LegacySettingsMigration.clearStaleDriveSignInFlag()` runs once at app startup (called from `main.dart`) and deletes that orphaned key so no stale state persists in Keystore-backed storage after the feature's removal. Any backup files a user previously uploaded to their own Google Drive `appDataFolder` are unaffected — the app has no remaining code path to reach or delete them.
