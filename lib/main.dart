import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'database/database_helper.dart';
import 'providers/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise encrypted database before any provider reads from it.
  final dbHelper = DatabaseHelper();
  await dbHelper.init();

  // Load persisted settings before the widget tree builds.
  final settingsProvider = SettingsProvider();
  await settingsProvider.load();

  // No permissions requested at startup — all requested at point-of-use.

  runApp(
    BibleFlashcardsApp(
      dbHelper: dbHelper,
      settingsProvider: settingsProvider,
    ),
  );
}
