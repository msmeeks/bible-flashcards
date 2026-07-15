import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../database/database_helper.dart';
import '../../models/settings.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tracking_provider.dart';
import '../../providers/verse_provider.dart';
import '../../services/audio_interrupt_service.dart';
import '../../services/audio_service.dart';
import '../../services/esv_lookup_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/announce_on_change.dart';
import '../../widgets/inline_status_banner.dart';
import '../history/history_screen.dart';
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

  /// Why the daily reminder could not be scheduled, or null when it is fine.
  String? _reminderError;

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
    // Saved default may be 'ESV' from a build that had a key configured;
    // fall back to BSB for display when this build has none, mirroring
    // AddVerseScreen's fallback for the same situation.
    final effectiveDefaultTranslation = settings.defaultTranslation == 'ESV' &&
            !EsvLookupService.isApiKeyConfigured
        ? 'BSB'
        : settings.defaultTranslation;
    final esvSelected = effectiveDefaultTranslation == 'ESV';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ----------------------------------------------------------------
          // Audio
          // ----------------------------------------------------------------
          _SectionHeader(label: 'Audio', textTheme: tt),
          SwitchListTile(
            title: const Text('Play verses periodically'),
            subtitle: Text(
              settings.audioInterruptTriggerMode ==
                      AudioTriggerMode.whileOtherAudioPlaying
                  ? 'Every ${settings.audioInterruptIntervalMinutes} minutes, '
                      'while other audio is playing'
                  : 'Every ${settings.audioInterruptIntervalMinutes} minutes',
            ),
            value: settings.audioInterruptEnabled,
            onChanged: (value) => _onAudioInterruptChanged(
              context,
              settingsProvider,
              value,
            ),
          ),
          // One merged node, as the "Notification type" and "Theme" rows do, so
          // the value is announced as part of the control that changes it.
          MergeSemantics(
            key: const Key('interval-row'),
            child: Semantics(
              button: true,
              child: ListTile(
                enabled: settings.audioInterruptEnabled,
                title: const Text('Play a verse every'),
                subtitle: Text(
                  settings.audioInterruptEnabled
                      ? 'How often a memorized verse is played'
                      : 'Turn on "Play verses periodically" to choose an '
                          'interval',
                ),
                trailing: Text(
                  '${settings.audioInterruptIntervalMinutes} min',
                  style: tt.labelMedium,
                ),
                onTap: settings.audioInterruptEnabled
                    ? () => _showIntervalDialog(context, settingsProvider)
                    : null,
              ),
            ),
          ),
          // The choices are laid out under the title rather than in the
          // trailing slot: their labels are too wide for a ListTile trailing
          // widget at a 375px viewport.
          ListTile(
            enabled: settings.audioInterruptEnabled,
            title: const Text('When to play'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!settings.audioInterruptEnabled)
                  const Text(
                      'Turn on "Play verses periodically" to choose when'),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    key: const Key('trigger-mode-group'),
                    label: 'When to play a verse',
                    enabled: settings.audioInterruptEnabled,
                    explicitChildNodes: true,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final mode in AudioTriggerMode.values)
                          ChoiceChip(
                            label: Text(_triggerModeLabel(mode)),
                            selected:
                                settings.audioInterruptTriggerMode == mode,
                            onSelected: settings.audioInterruptEnabled
                                ? (_) => _onTriggerModeChanged(
                                    settingsProvider, mode)
                                : null,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          MergeSemantics(
            key: const Key('probability-row'),
            child: Semantics(
              button: true,
              child: ListTile(
                title: const Text('Verse-of-week probability'),
                subtitle: const Text('How often the verse of the week is '
                    'chosen vs. a random memorized verse'),
                trailing: Text(
                  '${(settings.audioInterruptProbability * 100).round()}%',
                  style: tt.labelMedium,
                ),
                onTap: () => _showProbabilityDialog(context, settingsProvider),
              ),
            ),
          ),
          // ----------------------------------------------------------------
          // Notifications
          // ----------------------------------------------------------------
          _SectionHeader(label: 'Notifications', textTheme: tt),
          Semantics(
            key: const Key('daily-reminder'),
            // Carries the failure reason on the control itself; the banner's
            // live region only announces it once, as it arrives.
            label: _reminderError,
            child: ListTile(
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
          ),
          // Always mounted so the live region is in the tree before the message
          // arrives; it collapses to zero height while _reminderError is null.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InlineStatusBanner(
              severity: BannerSeverity.error,
              message: _reminderError,
            ),
          ),
          Semantics(
            label: 'Notification type',
            child: MergeSemantics(
              child: ListTile(
                title: const Text('Notification type'),
                // Under the title, not trailing: these labels overflow a
                // ListTile trailing slot on a ~360dp phone.
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SegmentedButton<String>(
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
                await _applyNotificationSettings(notifService, updated);
              }
            },
          ),
          SwitchListTile(
            title: const Text('Auto-advance verse of the week'),
            subtitle: const Text('Picks a new verse every Sunday'),
            value: settings.autoAdvanceVerseOfWeek,
            onChanged: (value) {
              settingsProvider.update(
                settings.copyWith(autoAdvanceVerseOfWeek: value),
                announcement: value
                    ? 'Auto-advance verse of the week enabled'
                    : 'Auto-advance verse of the week disabled',
              );
            },
          ),
          // ----------------------------------------------------------------
          // Verses
          // ----------------------------------------------------------------
          _SectionHeader(label: 'Verses', textTheme: tt),
          MergeSemantics(
            child: ListTile(
              title: const Text('Default translation'),
              subtitle: AnnounceOnChange(
                value: esvSelected.toString(),
                builder: (context, liveRegion) => esvSelected
                    ? Semantics(
                        liveRegion: liveRegion,
                        label: 'ESV is for personal, non-commercial use only.',
                        child: Text(
                          'ESV is for personal, non-commercial use only.',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              trailing: SegmentedButton<String>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                segments: [
                  const ButtonSegment(value: 'BSB', label: Text('BSB')),
                  const ButtonSegment(value: 'KJV', label: Text('KJV')),
                  const ButtonSegment(value: 'WEB', label: Text('WEB')),
                  if (EsvLookupService.isApiKeyConfigured)
                    const ButtonSegment(value: 'ESV', label: Text('ESV')),
                ],
                selected: {effectiveDefaultTranslation},
                onSelectionChanged: (selected) {
                  settingsProvider.update(
                    settings.copyWith(defaultTranslation: selected.first),
                    announcement:
                        'Default translation set to ${selected.first}',
                  );
                },
              ),
            ),
          ),
          // ----------------------------------------------------------------
          // Appearance
          // ----------------------------------------------------------------
          _SectionHeader(label: 'Appearance', textTheme: tt),
          MergeSemantics(
            child: ListTile(
              title: const Text('Theme'),
              // Under the title, not trailing: these labels overflow a
              // ListTile trailing slot on a ~360dp phone.
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SegmentedButton<String>(
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
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const HistoryScreen(),
              ),
            ),
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
            subtitle: const Text('Export and import your data'),
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
          // ----------------------------------------------------------------
          // ESV Bible
          // ----------------------------------------------------------------
          _SectionHeader(label: 'ESV Bible', textTheme: tt),
          const ListTile(
            title: Text(
              'Scripture quotations are from the ESV® Bible '
              '(The Holy Bible, English Standard Version®), '
              '© 2001 by Crossway, a publishing ministry of '
              'Good News Publishers. Used by permission. All rights reserved.',
            ),
          ),
          ListTile(
            title: const Text('ESV.org'),
            subtitle: const Text('Full terms and copyright'),
            trailing: const Icon(Symbols.open_in_new_rounded),
            onTap: () async {
              final uri = Uri.parse('https://www.esv.org');
              bool launched = false;
              try {
                launched =
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {
                launched = false;
              }
              if (!launched && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open ESV.org.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Audio interrupt
  // ---------------------------------------------------------------------------

  Future<void> _onAudioInterruptChanged(
    BuildContext launchContext,
    SettingsProvider settingsProvider,
    bool enabled,
  ) async {
    if (enabled) {
      final verseProvider = launchContext.read<VerseProvider>();
      final verseOfWeek = verseProvider.verseOfWeek;
      if (verseOfWeek == null) {
        if (launchContext.mounted) {
          await showDialog<void>(
            context: launchContext,
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

      _startTracking(launchContext, settingsProvider.settings);

      await settingsProvider.update(
        settingsProvider.settings.copyWith(audioInterruptEnabled: true),
      );
    } else {
      _interruptService?.stopTracking();
      await settingsProvider.update(
        settingsProvider.settings.copyWith(audioInterruptEnabled: false),
      );
    }
  }

  static String _triggerModeLabel(AudioTriggerMode mode) => switch (mode) {
        AudioTriggerMode.whileOtherAudioPlaying => 'While other audio plays',
        AudioTriggerMode.always => 'Anytime',
      };

  /// (Re)starts tracking against [settings]. Also called when the interval or
  /// trigger mode changes, since the running timer captured the old values.
  void _startTracking(BuildContext lookupContext, AppSettings settings) {
    final verseProvider = lookupContext.read<VerseProvider>();
    final verseOfWeek = verseProvider.verseOfWeek;
    if (verseOfWeek == null) return;

    _interruptService ??= AudioInterruptService(
      audioService: AudioService(),
      notificationService: lookupContext.read<NotificationService>(),
    );

    _interruptService!.startTracking(
      interval: Duration(minutes: settings.audioInterruptIntervalMinutes),
      triggerMode: settings.audioInterruptTriggerMode,
      interruptProbability: settings.audioInterruptProbability,
      memorizedVerses: verseProvider.memorizedVerses,
      verseOfWeek: verseOfWeek,
    );
  }

  Future<void> _onTriggerModeChanged(
    SettingsProvider settingsProvider,
    AudioTriggerMode mode,
  ) async {
    final updated =
        settingsProvider.settings.copyWith(audioInterruptTriggerMode: mode);
    await settingsProvider.update(
      updated,
      announcement: mode == AudioTriggerMode.whileOtherAudioPlaying
          ? 'Verses play only while other audio is playing'
          : 'Verses play at any time',
    );
    if (updated.audioInterruptEnabled && mounted) {
      _startTracking(context, updated);
    }
  }

  // ---------------------------------------------------------------------------
  // Interval dialog
  // ---------------------------------------------------------------------------

  static const _intervalPresets = <int>[15, 30, 45, 60, 90];

  Future<void> _showIntervalDialog(
    BuildContext launchContext,
    SettingsProvider settingsProvider,
  ) async {
    final selected = await showDialog<int>(
      context: launchContext,
      builder: (dialogContext) {
        final current = settingsProvider.settings.audioInterruptIntervalMinutes;
        return AlertDialog(
          title: const Text('Play a verse every'),
          content: Semantics(
            label: 'Playback interval presets',
            explicitChildNodes: true,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minutes in _intervalPresets)
                  ChoiceChip(
                    label: Text('$minutes min'),
                    selected: minutes == current,
                    onSelected: (_) => Navigator.of(dialogContext).pop(minutes),
                  ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selected == null) return;
    final updated = settingsProvider.settings
        .copyWith(audioInterruptIntervalMinutes: selected);
    await settingsProvider.update(
      updated,
      announcement: 'Playing a verse every $selected minutes',
    );
    // The State's context, not launchContext: the tile that opened the dialog
    // may be gone by the time it resolves.
    if (updated.audioInterruptEnabled && mounted) {
      _startTracking(context, updated);
    }
  }

  // ---------------------------------------------------------------------------
  // Probability dialog
  // ---------------------------------------------------------------------------

  Future<void> _showProbabilityDialog(
    BuildContext launchContext,
    SettingsProvider settingsProvider,
  ) async {
    var current = settingsProvider.settings.audioInterruptProbability;

    await showDialog<void>(
      context: launchContext,
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
                OutlinedButton(
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
    BuildContext launchContext,
    SettingsProvider settingsProvider,
  ) async {
    final notifService = launchContext.read<NotificationService>();
    final current = settingsProvider.settings.dailyNotificationTime;
    final picked = await showTimePicker(
      context: launchContext,
      initialTime: current ?? TimeOfDay.now(),
      helpText: 'Set daily notification time',
      hourLabelText: 'Hour',
      minuteLabelText: 'Minute',
    );

    // Return focus to the trigger tile regardless of whether user picked a time.
    if (mounted) _reminderFocusNode.requestFocus();
    if (!mounted || picked == null) return;

    final updated = settingsProvider.settings.copyWith(
      dailyNotificationTime: picked,
    );
    await settingsProvider.update(
      updated,
      announcement: 'Daily reminder set to ${picked.format(context)}',
    );

    if (!mounted) return;
    await _applyNotificationSettings(notifService, updated);
  }

  // ---------------------------------------------------------------------------
  // Clear daily notification
  // ---------------------------------------------------------------------------

  Future<void> _clearDailyNotification(
    BuildContext lookupContext,
    SettingsProvider settingsProvider,
  ) async {
    final notifService = lookupContext.read<NotificationService>();
    final updated = settingsProvider.settings.copyWith(
      dailyNotificationTime: null,
    );
    // Cleared before the platform call: the error describes a reminder that no
    // longer exists, so a failing cancel must not strand the banner.
    setState(() => _reminderError = null);
    await settingsProvider.update(updated,
        announcement: 'Daily reminder turned off');
    await notifService.cancelDailyNotification();
  }

  // ---------------------------------------------------------------------------
  // Apply notification settings helper
  // Schedules (or cancels) the daily notification based on current settings.
  // ---------------------------------------------------------------------------

  Future<void> _applyNotificationSettings(
    NotificationService notifService,
    AppSettings settings,
  ) async {
    if (settings.dailyNotificationTime == null) {
      // No reminder left for an earlier failure to describe.
      setState(() => _reminderError = null);
      await notifService.cancelDailyNotification();
      return;
    }
    final result = await notifService.scheduleDailyNotification(
      settings.dailyNotificationTime!,
      showOnLockScreen: settings.showOnLockScreen,
      notificationType: settings.notificationType,
    );
    if (!mounted) return;
    setState(() => _reminderError = switch (result) {
          DailyReminderResult.scheduled => null,
          DailyReminderResult.notificationsDenied =>
            'Allow notifications in system settings to enable the daily reminder',
          DailyReminderResult.exactAlarmsDenied =>
            'Allow exact alarms in system settings to enable the daily reminder',
        });
  }

  // ---------------------------------------------------------------------------
  // Clear history
  // ---------------------------------------------------------------------------

  Future<void> _confirmClearHistory(BuildContext launchContext) async {
    final confirmed = await showDialog<bool>(
      context: launchContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear test history'),
        content: const Text(
          'This will permanently delete all test results. This cannot be undone.',
        ),
        actions: [
          OutlinedButton(
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

    if (confirmed == true && mounted) {
      await DatabaseHelper().clearTestHistory();
    }
  }

  Future<void> _confirmClearActivityHistory(BuildContext launchContext) async {
    final confirmed = await showDialog<bool>(
      context: launchContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear Activity History'),
        content: const Text(
          'This will permanently delete all streak and activity data. This cannot be undone.',
        ),
        actions: [
          OutlinedButton(
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

    if (confirmed == true && mounted) {
      await DatabaseHelper().clearEngagementLog();
      if (!mounted) return;
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
