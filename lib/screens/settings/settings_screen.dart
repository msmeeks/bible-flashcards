import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../database/database_helper.dart';
import '../../models/settings.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tracking_provider.dart';
import '../../providers/verse_provider.dart';
import '../../services/audio_interrupt_service.dart';
import '../../services/audio_service.dart';
import '../../services/notification_service.dart';
import 'book_variants_screen.dart';
import 'data_management_screen.dart';
import 'test_history_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AudioInterruptService? _interruptService;
  final FocusNode _reminderFocusNode = FocusNode();

  @override
  void dispose() {
    _interruptService?.stopTracking();
    _reminderFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ----------------------------------------------------------------
          // Audio
          // ----------------------------------------------------------------
          _SectionHeader(label: 'Audio', textTheme: tt),
          SwitchListTile(
            title: const Text('Interrupt audio for verse reminders'),
            subtitle: const Text(
              'After 1 hour of audio, play a memorized verse',
            ),
            value: settings.audioInterruptEnabled,
            onChanged: (value) => _onAudioInterruptChanged(
              context,
              settingsProvider,
              value,
            ),
          ),
          ListTile(
            title: const Text('Verse-of-week probability'),
            subtitle: const Text(
                'How often the verse of the week is chosen vs. a random memorized verse'),
            trailing: MergeSemantics(
              child: Text(
                '${(settings.audioInterruptProbability * 100).round()}%',
                style: tt.bodyMedium,
              ),
            ),
            onTap: () => _showProbabilityDialog(context, settingsProvider),
          ),
          // ----------------------------------------------------------------
          // Notifications
          // ----------------------------------------------------------------
          _SectionHeader(label: 'Notifications', textTheme: tt),
          ListTile(
            focusNode: _reminderFocusNode,
            title: const Text('Daily reminder'),
            subtitle: Text(
              settings.dailyNotificationTime?.format(context) ?? 'Off',
            ),
            trailing: settings.dailyNotificationTime != null
                ? IconButton(
                    icon: const Icon(
                      Symbols.cancel_rounded,
                      semanticLabel: 'Clear daily reminder',
                    ),
                    onPressed: () =>
                        _clearDailyNotification(context, settingsProvider),
                  )
                : const Icon(
                    Symbols.chevron_right_rounded,
                    semanticLabel: 'Set daily reminder',
                  ),
            onTap: () => _showTimePicker(context, settingsProvider),
          ),
          Semantics(
            label: 'Notification type',
            child: MergeSemantics(
              child: ListTile(
                title: const Text('Notification type'),
                trailing: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'verseOfWeek', label: Text('Verse of week')),
                    ButtonSegment(
                        value: 'reviewVerse', label: Text('Review verse')),
                  ],
                  selected: {settings.notificationType},
                  onSelectionChanged: (selected) {
                    settingsProvider.update(
                      settings.copyWith(notificationType: selected.first),
                      announcement:
                          'Notification type set to ${selected.first == 'verseOfWeek' ? 'verse of week' : 'review verse'}',
                    );
                  },
                ),
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Show on lock screen'),
            subtitle: const Text(
              'Verse reminders will appear on your lock screen and may be visible to others.',
            ),
            value: settings.showOnLockScreen,
            onChanged: (value) async {
              final updated = settings.copyWith(showOnLockScreen: value);
              await settingsProvider.update(
                updated,
                announcement: value
                    ? 'Lock screen visibility enabled'
                    : 'Lock screen visibility disabled',
              );
              if (context.mounted && updated.dailyNotificationTime != null) {
                final notifService = context.read<NotificationService>();
                await _applyNotificationSettings(
                  context,
                  notifService,
                  updated,
                );
              }
            },
          ),
          // ----------------------------------------------------------------
          // Appearance
          // ----------------------------------------------------------------
          _SectionHeader(label: 'Appearance', textTheme: tt),
          MergeSemantics(
            child: ListTile(
              title: const Text('Theme'),
              trailing: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'system', label: Text('System')),
                  ButtonSegment(value: 'light', label: Text('Light')),
                  ButtonSegment(value: 'dark', label: Text('Dark')),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (selected) {
                  settingsProvider.update(
                    settings.copyWith(themeMode: selected.first),
                    announcement: 'Theme set to ${selected.first}',
                  );
                },
              ),
            ),
          ),
          // ----------------------------------------------------------------
          // Data
          // ----------------------------------------------------------------
          _SectionHeader(label: 'Data', textTheme: tt),
          ListTile(
            leading: const Icon(Symbols.history_rounded),
            title: const Text('Test history'),
            subtitle: const Text('View past test results'),
            trailing:
                const Icon(Symbols.chevron_right_rounded, semanticLabel: ''),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TestHistoryScreen(),
              ),
            ),
          ),
          ListTile(
            title: const Text('Clear test history'),
            leading: Icon(
              Symbols.delete_outline_rounded,
              color: cs.error,
              semanticLabel: 'Destructive action',
            ),
            onTap: () => _confirmClearHistory(context),
          ),
          ListTile(
            leading: Icon(Symbols.bar_chart_rounded, color: cs.primary),
            title: const Text('Activity History'),
            subtitle: const Text('Streaks and verse review counts'),
            trailing: Icon(Icons.chevron_right_rounded, color: cs.outline),
            onTap: () => Navigator.of(context).pushNamed('/history'),
          ),
          ListTile(
            title: const Text('Clear Activity History'),
            leading: Icon(Icons.delete_outline_rounded, color: cs.error),
            onTap: () => _confirmClearActivityHistory(context),
          ),
          ListTile(
            leading: Icon(Symbols.menu_book_rounded, color: cs.primary),
            title: const Text('Book Name Variants'),
            subtitle: const Text(
                'Custom abbreviations recognized in reference test answers'),
            trailing:
                const Icon(Symbols.chevron_right_rounded, semanticLabel: ''),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const BookVariantsScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.backup_rounded),
            title: const Text('Data & Backup'),
            subtitle: const Text('Export, import, and Google Drive backup'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DataManagementScreen(),
              ),
            ),
          ),
          // ----------------------------------------------------------------
          // About
          // ----------------------------------------------------------------
          _SectionHeader(label: 'About', textTheme: tt),
          const ListTile(
            title: Text('Bible Flashcards'),
            subtitle: Text('Built for personal Bible memorization'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Audio interrupt
  // ---------------------------------------------------------------------------

  Future<void> _onAudioInterruptChanged(
    BuildContext context,
    SettingsProvider settingsProvider,
    bool enabled,
  ) async {
    if (enabled) {
      final verseProvider = context.read<VerseProvider>();
      final verseOfWeek = verseProvider.verseOfWeek;
      if (verseOfWeek == null) {
        if (context.mounted) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Cannot enable'),
              content: const Text('Set a verse of the week first'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      final memorized = verseProvider.memorizedVerses;
      final settings = settingsProvider.settings;
      final notifService = context.read<NotificationService>();

      _interruptService ??= AudioInterruptService(
        audioService: AudioService(),
        notificationService: notifService,
      );

      _interruptService!.startTracking(
        threshold: Duration(minutes: settings.audioInterruptAfterMinutes),
        interruptProbability: settings.audioInterruptProbability,
        memorizedVerses: memorized,
        verseOfWeek: verseOfWeek,
      );

      await settingsProvider.update(
        settings.copyWith(audioInterruptEnabled: true),
      );
    } else {
      _interruptService?.stopTracking();
      await settingsProvider.update(
        settingsProvider.settings.copyWith(audioInterruptEnabled: false),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Probability dialog
  // ---------------------------------------------------------------------------

  Future<void> _showProbabilityDialog(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) async {
    var current = settingsProvider.settings.audioInterruptProbability;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Verse-of-week probability'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(current * 100).round()}%',
                    style: Theme.of(ctx).textTheme.headlineSmall,
                  ),
                  Slider(
                    value: current,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    label: '${(current * 100).round()}%',
                    semanticFormatterCallback: (v) => '${(v * 100).round()}%',
                    onChanged: (value) {
                      setDialogState(() => current = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    settingsProvider.update(
                      settingsProvider.settings.copyWith(
                        audioInterruptProbability: current,
                      ),
                    );
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Time picker
  // ---------------------------------------------------------------------------

  Future<void> _showTimePicker(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) async {
    final notifService = context.read<NotificationService>();
    final current = settingsProvider.settings.dailyNotificationTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? TimeOfDay.now(),
      helpText: 'Set daily notification time',
      hourLabelText: 'Hour',
      minuteLabelText: 'Minute',
    );

    // Return focus to the trigger tile regardless of whether user picked a time.
    if (context.mounted) _reminderFocusNode.requestFocus();
    if (!context.mounted || picked == null) return;

    final updated = settingsProvider.settings.copyWith(
      dailyNotificationTime: picked,
    );
    await settingsProvider.update(
      updated,
      announcement: 'Daily reminder set to ${picked.format(context)}',
    );

    if (!context.mounted) return;
    await _applyNotificationSettings(context, notifService, updated);
  }

  // ---------------------------------------------------------------------------
  // Clear daily notification
  // ---------------------------------------------------------------------------

  Future<void> _clearDailyNotification(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) async {
    final notifService = context.read<NotificationService>();
    final updated = settingsProvider.settings.copyWith(
      dailyNotificationTime: null,
    );
    await settingsProvider.update(updated,
        announcement: 'Daily reminder turned off');
    await notifService.cancelDailyNotification();
  }

  // ---------------------------------------------------------------------------
  // Apply notification settings helper
  // Schedules (or cancels) the daily notification based on current settings.
  // ---------------------------------------------------------------------------

  Future<void> _applyNotificationSettings(
    BuildContext context,
    NotificationService notifService,
    AppSettings settings,
  ) async {
    if (settings.dailyNotificationTime == null) {
      await notifService.cancelDailyNotification();
      return;
    }
    final granted = await notifService.scheduleDailyNotification(
      settings.dailyNotificationTime!,
      showOnLockScreen: settings.showOnLockScreen,
      notificationType: settings.notificationType,
    );
    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Allow exact alarms in system settings to enable the daily reminder',
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Clear history
  // ---------------------------------------------------------------------------

  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear test history'),
        content: const Text(
          'This will permanently delete all test results. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await DatabaseHelper().clearTestHistory();
    }
  }

  Future<void> _confirmClearActivityHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear Activity History'),
        content: const Text(
          'This will permanently delete all streak and activity data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await DatabaseHelper().clearEngagementLog();
      if (!context.mounted) return;
      // ignore: unawaited_futures — load() notifies listeners; no need to await UI rebuild
      context.read<TrackingProvider>().load();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activity history cleared')),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Section header widget
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.textTheme});

  final String label;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label,
        style: textTheme.labelLarge?.copyWith(color: cs.primary),
      ),
    );
  }
}
