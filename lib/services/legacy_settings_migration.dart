import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// One-time cleanup for state left behind by removed features.
class LegacySettingsMigration {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  // Was GoogleDriveService's sign-in intent flag; the Drive backup feature
  // (and its OAuth flow) has been removed, but the flag itself was never
  // cleared for users who had previously connected.
  static const _driveSignedInKey = 'drive_signed_in';

  static Future<void> clearStaleDriveSignInFlag() async {
    await _secureStorage.delete(key: _driveSignedInKey);
  }
}
