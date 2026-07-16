import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The daily reminder depends on manifest declarations that nothing else
/// asserts: scheduled alarms are dropped on reboot unless the plugin's boot
/// receiver is registered, and that failure is silent and only observable
/// after a physical reboot. These guard the declarations against regression.
void main() {
  late String manifest;

  setUpAll(() {
    manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  });

  group('AndroidManifest daily reminder requirements', () {
    test('declares RECEIVE_BOOT_COMPLETED', () {
      expect(
        manifest,
        contains('android.permission.RECEIVE_BOOT_COMPLETED'),
      );
    });

    test('registers the plugin boot receiver so alarms survive reboot', () {
      expect(
        manifest,
        contains(
          'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver',
        ),
      );
    });

    test('boot receiver listens for BOOT_COMPLETED', () {
      expect(manifest, contains('android.intent.action.BOOT_COMPLETED'));
    });

    test('boot receiver is not exported', () {
      // The receiver only re-registers local alarms; nothing outside the app
      // has any reason to reach it.
      final nameIndex = manifest.indexOf('ScheduledNotificationBootReceiver');
      final element = manifest.substring(
        manifest.lastIndexOf('<receiver', nameIndex),
        manifest.indexOf('</receiver>', nameIndex),
      );
      expect(element, contains('android:exported="false"'));
    });

    test('declares POST_NOTIFICATIONS for the Android 13+ runtime prompt', () {
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    });
  });

  // PRIVACY.md presents its permission table as exhaustive, which stops being
  // true the moment it silently isn't: adding a uses-permission is a one-line
  // change nothing otherwise forces you to disclose.
  test('every declared permission has a row in PRIVACY.md', () {
    final declared = RegExp(r'android\.permission\.(\w+)')
        .allMatches(manifest)
        .map((m) => m.group(1)!)
        .toSet();
    final privacy = File('meta/PRIVACY.md').readAsStringSync();

    final undisclosed =
        declared.where((p) => !privacy.contains('`$p`')).toList()..sort();

    expect(
      undisclosed,
      isEmpty,
      reason: 'Permissions declared in AndroidManifest.xml with no row in '
          "meta/PRIVACY.md's Permissions Used table: $undisclosed",
    );
  });
}
