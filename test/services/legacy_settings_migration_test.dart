import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
