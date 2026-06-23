import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'database/database_helper.dart';
import 'providers/settings_provider.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Disable runtime font fetching — all fonts must be bundled; no network egress.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Initialise encrypted database before any provider reads from it.
  final dbHelper = DatabaseHelper();
  await dbHelper.init();

  // Load persisted settings before the widget tree builds.
  final settingsProvider = SettingsProvider();
  await settingsProvider.load();

  // Initialise notification channels (must run before any notification call).
  final notificationService = NotificationService();
  await notificationService.initialize();

  // No permissions requested at startup — all requested at point-of-use.

  runApp(
    BibleFlashcardsApp(
      dbHelper: dbHelper,
      settingsProvider: settingsProvider,
      notificationService: notificationService,
    ),
  );
}
