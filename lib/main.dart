import 'package:flutter/material.dart';

import 'app.dart';
import 'database/database_helper.dart';
import 'providers/settings_provider.dart';
import 'services/legacy_settings_migration.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // One-time cleanup of state left behind by removed features. Failures are
  // swallowed internally so a corrupted platform channel never blocks
  // startup.
  await LegacySettingsMigration.run();

  // Initialise encrypted database before any provider reads from it.
  final dbHelper = DatabaseHelper();
  await dbHelper.init();

  // Load persisted settings before the widget tree builds.
  final settingsProvider = SettingsProvider();
  await settingsProvider.load();

  // Initialise notification channels (must run before any notification call).
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Re-assert the saved reminder: the setting survives a fresh install or
  // "Clear data" but the alarm doesn't.
  final reminderTime = settingsProvider.settings.dailyNotificationTime;
  if (reminderTime != null) {
    await notificationService.restoreDailyNotification(
      reminderTime,
      showOnLockScreen: settingsProvider.settings.showOnLockScreen,
      notificationType: settingsProvider.settings.notificationType,
    );
  }

  // No permissions requested at startup — all requested at point-of-use.

  runApp(
    BibleFlashcardsApp(
      dbHelper: dbHelper,
      settingsProvider: settingsProvider,
      notificationService: notificationService,
    ),
  );
}
