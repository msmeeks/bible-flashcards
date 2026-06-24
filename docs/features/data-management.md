# Data Management (Export, Import, Google Drive Backup)

## Summary
Lets users back up and restore their verse library, test history, and app settings as a JSON file, either via the Android share sheet, a direct on-device save, or Google Drive. Exists so users do not lose progress on reinstall/device change and can move data between devices.

## Users / Use Cases
- **Admin**: N/A (single-user app, no roles)
- **Worker**: User exports data to share or save a backup file, imports a backup file (merge or replace existing data), connects Google Drive for automatic/manual cloud backup, restores from or deletes a Drive backup.

## Technologies
- `file_picker` — native Android file picker; used both to open files for import and to write export bytes via SAF `content://` URIs (no `dart:io` `File` calls on raw paths, no temp files for "Save Locally")
- `share_plus` — Android share sheet for the "Export Data" option (writes a temp file in app documents dir, shares it, then deletes it)
- `path_provider` — locates the app documents directory for the share-sheet temp file
- `sqflite_sqlcipher` — transactional insert of imported rows into encrypted SQLite

## Technical Overview
`ExportService` builds a single JSON payload (`schema_version`, `source_app`, verses, optional test results, optional settings) shared by all three export paths: share sheet (`shareExport`), local save (`saveExportToFile`), and Drive backup (`buildExportJson`, consumed by `GoogleDriveService`). `ImportService.import()` validates schema/size/array-length, coerces each row, and writes everything inside one `db.transaction`, using `ConflictAlgorithm.ignore` so merge mode never throws on duplicate primary keys. Replace mode deletes `test_results` and `verses` before inserting. The `includeHistory`/`includeSettings` toggles are independent — `includeSettings` controls whether app preferences are bundled, separate from test-history inclusion.

## Key Files
| File | Purpose |
|---|---|
| `lib/screens/settings/data_management_screen.dart` | Settings UI: Export/Save Locally/Import dialogs, Google Drive section, file picker invocation |
| `lib/services/export_service.dart` | Builds export JSON payload; `shareExport`, `saveExportToFile`, `buildExportJson` |
| `lib/services/import_service.dart` | Validates and imports backup JSON; size/array caps, row-level validation, transactional write |
| `lib/services/google_drive_service.dart` | Drive sign-in, `backup`/`restore`/`deleteBackup` against `drive.appdata` scope |

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

### Google Drive integration
Drive backup/restore reuse `ExportService.buildExportJson()` and `ImportService.import(..., replace: true)` — no separate serialization path. Drive scope is `drive.appdata` only (not visible in the user's regular Drive). See `GoogleDriveService` for sign-in/backup/restore/delete implementation.
