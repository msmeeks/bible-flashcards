import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One-time cleanup for state left behind by removed features.
class LegacySettingsMigration {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  // Was GoogleDriveService's sign-in intent flag; the Drive backup feature
  // (and its OAuth flow) has been removed, but the flag itself was never
  // cleared for users who had previously connected.
  static const _driveSignedInKey = 'drive_signed_in';

  // Was SettingsProvider's plaintext Drive-backup prefs; orphaned once the
  // Drive backup feature (and the AppSettings fields backing them) was
  // removed, but never actively deleted for existing installs.
  static const _orphanedDrivePrefsKeys = [
    'drive_backup_enabled',
    'backup_cadence',
    'last_backup_at',
    'drive_consent_at',
    'drive_consent_version',
  ];

  static Future<void> clearStaleDriveSignInFlag() async {
    await _secureStorage.delete(key: _driveSignedInKey);
  }

  static Future<void> clearOrphanedDrivePrefsKeys() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _orphanedDrivePrefsKeys) {
      await prefs.remove(key);
    }
  }

  /// Runs all legacy-cleanup steps, swallowing any platform-channel failure
  /// so a corrupted/unavailable secure-storage or prefs backend never blocks
  /// app startup.
  static Future<void> run() async {
    try {
      await clearStaleDriveSignInFlag();
      await clearOrphanedDrivePrefsKeys();
    } catch (e) {
      debugPrint('LegacySettingsMigration.run failed: $e');
    }
  }
}
