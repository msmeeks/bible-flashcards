import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bible_flashcards/services/legacy_settings_migration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  final deletedKeys = <String>[];

  setUp(() {
    deletedKeys.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'delete') {
        final arguments = call.arguments as Map<Object?, Object?>;
        deletedKeys.add(arguments['key'] as String);
        return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('clears the stale drive_signed_in secure-storage key', () async {
    await LegacySettingsMigration.clearStaleDriveSignInFlag();

    expect(deletedKeys, contains('drive_signed_in'));
  });

  test('run() does not throw when secure storage delete throws', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'unavailable');
    });

    await expectLater(LegacySettingsMigration.run(), completes);
  });

  test('run() removes the five orphaned Drive SharedPreferences keys',
      () async {
    SharedPreferences.setMockInitialValues({
      'drive_backup_enabled': true,
      'backup_cadence': 'weekly',
      'last_backup_at': '2026-01-01T00:00:00.000Z',
      'drive_consent_at': '2026-01-01T00:00:00.000Z',
      'drive_consent_version': 1,
      'default_translation': 'BSB',
    });

    await LegacySettingsMigration.run();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('drive_backup_enabled'), isFalse);
    expect(prefs.containsKey('backup_cadence'), isFalse);
    expect(prefs.containsKey('last_backup_at'), isFalse);
    expect(prefs.containsKey('drive_consent_at'), isFalse);
    expect(prefs.containsKey('drive_consent_version'), isFalse);
    expect(prefs.getString('default_translation'), 'BSB');
  });

  test('run() is a no-op when no orphaned Drive keys are present', () async {
    SharedPreferences.setMockInitialValues({'default_translation': 'BSB'});

    await expectLater(LegacySettingsMigration.run(), completes);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('default_translation'), 'BSB');
  });
}
