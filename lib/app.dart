import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database/database_helper.dart';
import 'providers/audio_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/tracking_provider.dart';
import 'providers/verse_provider.dart';
import 'screens/history/history_screen.dart';
import 'screens/main_scaffold.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/test/test_screen.dart';
import 'screens/verses/add_verse_screen.dart';
import 'screens/verses/verse_detail_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

class BibleFlashcardsApp extends StatefulWidget {
  final DatabaseHelper dbHelper;
  final SettingsProvider settingsProvider;
  final NotificationService notificationService;

  const BibleFlashcardsApp({
    super.key,
    required this.dbHelper,
    required this.settingsProvider,
    required this.notificationService,
  });

  @override
  State<BibleFlashcardsApp> createState() => _BibleFlashcardsAppState();
}

class _BibleFlashcardsAppState extends State<BibleFlashcardsApp> {
  bool _noticeShown = true;

  @override
  void initState() {
    super.initState();
    _checkEngagementNotice();
  }

  Future<void> _checkEngagementNotice() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('engagement_notice_shown') ?? false;
    if (!shown) {
      setState(() => _noticeShown = false);
    }
  }

  Future<void> _markNoticeAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('engagement_notice_shown', true);
    await prefs.setBool('engagement_tracking_enabled', true);
    DatabaseHelper.invalidateTrackingCache();
    if (mounted) setState(() => _noticeShown = true);
  }

  Future<void> _markNoticeDeclined() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('engagement_notice_shown', true);
    await prefs.setBool('engagement_tracking_enabled', false);
    DatabaseHelper.invalidateTrackingCache();
    if (mounted) setState(() => _noticeShown = true);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(
          value: widget.settingsProvider,
        ),
        ChangeNotifierProvider<VerseProvider>(
          create: (_) => VerseProvider(widget.dbHelper)..loadVerses(),
        ),
        ChangeNotifierProvider<AudioProvider>(
          create: (_) => AudioProvider(
            notificationService: widget.notificationService,
          ),
        ),
        ChangeNotifierProvider<TrackingProvider>(
          create: (_) => TrackingProvider(widget.dbHelper),
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
              '/': (_) => _noticeShown
                  ? const MainScaffold()
                  : _EngagementNoticeWrapper(
                      onAccept: _markNoticeAccepted,
                      onDecline: _markNoticeDeclined,
                    ),
              '/verse-detail': (_) => const VerseDetailScreen(),
              '/verse-add': (_) => const AddVerseScreen(),
              '/test': (_) => const TestScreen(),
              // TestResultScreen requires a sessionResult argument and is pushed
              // imperatively from TestSessionScreen; no named route needed.
              '/settings': (_) => const SettingsScreen(),
              '/history': (_) => const HistoryScreen(),
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// First-launch engagement notice
// ---------------------------------------------------------------------------

class _EngagementNoticeWrapper extends StatefulWidget {
  const _EngagementNoticeWrapper({
    required this.onAccept,
    required this.onDecline,
  });

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  State<_EngagementNoticeWrapper> createState() =>
      _EngagementNoticeWrapperState();
}

class _EngagementNoticeWrapperState extends State<_EngagementNoticeWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showDialog());
  }

  Future<void> _showDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Activity Tracking'),
        content: const Text(
          'We now track your daily study streaks and verse review counts to '
          'help you build a consistent habit. This data stays on your device. '
          'You can clear it anytime in Settings → Activity History.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              widget.onDecline();
            },
            child: const Text('No thanks'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              widget.onAccept();
            },
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const MainScaffold();
}
