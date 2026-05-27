import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'database/database_helper.dart';
import 'providers/audio_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/verse_provider.dart';
import 'screens/main_scaffold.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/test/test_screen.dart';
import 'screens/verses/verses_screen.dart';
import 'theme/app_theme.dart';

class BibleFlashcardsApp extends StatelessWidget {
  final DatabaseHelper dbHelper;
  final SettingsProvider settingsProvider;

  const BibleFlashcardsApp({
    super.key,
    required this.dbHelper,
    required this.settingsProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<VerseProvider>(
          create: (_) => VerseProvider(dbHelper)..loadVerses(),
        ),
        ChangeNotifierProvider<AudioProvider>(
          create: (_) => AudioProvider(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          final themeMode = switch (settings.settings.themeMode) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          };

          return MaterialApp(
            title: 'Bible Flashcards',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeMode,
            initialRoute: '/',
            routes: {
              '/': (_) => const MainScaffold(),
              '/verse-detail': (_) => const VersesScreen(),
              '/verse-add': (_) => const VersesScreen(),
              '/test': (_) => const TestScreen(),
              '/test-result': (_) => const TestScreen(),
              '/settings': (_) => const SettingsScreen(),
            },
          );
        },
      ),
    );
  }
}
