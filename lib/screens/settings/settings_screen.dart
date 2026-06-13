import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/database_helper.dart';
import '../../providers/settings_provider.dart';
import '../../providers/verse_provider.dart';
import '../../services/audio_interrupt_service.dart';
import '../../services/audio_review_service.dart';
import '../../services/audio_service.dart';
import '../../services/notification_service.dart';
import 'data_management_screen.dart';
import 'test_history_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Review / interrupt services are instantiated lazily when the feature is
  // enabled, so they can be stopped cleanly when disabled.
  AudioReviewService? _reviewService;
  AudioInterruptService? _interruptService;

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
            title: const Text('Audio Review'),
            subtitle: const Text(
              'Continuously play memorized verses in the background',
            ),
            value: settings.audioReviewEnabled,
            onChanged: (value) => _onAudioReviewChanged(
              context,
              settingsProvider,
              value,
            ),
          ),
          SwitchListTile(
            title: const Text('Interrupt Audio for Verse Reminders'),
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
            title: const Text('Interrupt Probability'),
            subtitle: const Text('How often to interrupt with a verse'),
            trailing: Text(
              '${(settings.audioInterruptProbability * 100).round()}%',
              style: tt.bodyMedium,
            ),
            onTap: () => _showProbabilityDialog(context, settingsProvider),
          ),
          // ----------------------------------------------------------------
          // Notifications
          // ----------------------------------------------------------------
          _SectionHeader(label: 'Notifications', textTheme: tt),
          ListTile(
            leading: Icon(Icons.lock_outline_rounded, color: cs.primary),
            title: const Text('Notification content is kept private'),
            subtitle: const Text(
              'Verse text never appears on the lock screen',
            ),
            enabled: false,
          ),
          // ----------------------------------------------------------------
          // Appearance
          // ----------------------------------------------------------------
          _SectionHeader(label: 'Appearance', textTheme: tt),
          ListTile(
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
                );
              },
            ),
          ),
          // ----------------------------------------------------------------
          // Data
          // ----------------------------------------------------------------
          _SectionHeader(label: 'Data', textTheme: tt),
          ListTile(
            leading: const Icon(Icons.history_rounded),
            title: const Text('Test History'),
            subtitle: const Text('View past test results'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TestHistoryScreen(),
              ),
            ),
          ),
          ListTile(
            title: const Text('Clear Test History'),
            leading: Icon(Icons.delete_outline_rounded, color: cs.error),
            onTap: () => _confirmClearHistory(context),
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
          ListTile(
            title: Text(
              'Bible Flashcards',
              style: tt.titleMedium,
            ),
            subtitle: const Text('Built for personal Bible memorization'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Audio review
  // ---------------------------------------------------------------------------

  Future<void> _onAudioReviewChanged(
    BuildContext context,
    SettingsProvider settingsProvider,
    bool enabled,
  ) async {
    if (enabled) {
      final verseProvider = context.read<VerseProvider>();
      final verses = verseProvider.memorizedVerses;
      if (verses.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No memorized verses — mark verses as memorized first',
              ),
            ),
          );
        }
        return;
      }

      final verseOfWeek = verseProvider.verseOfWeek;
      final vowId = verseOfWeek?.id ?? verses.first.id;

      _reviewService ??= AudioReviewService(AudioService());
      _reviewService!.startReview(verses, verseOfWeekId: vowId);

      await settingsProvider.update(
        settingsProvider.settings.copyWith(audioReviewEnabled: true),
      );
    } else {
      await _reviewService?.stopReview();
      await settingsProvider.update(
        settingsProvider.settings.copyWith(audioReviewEnabled: false),
      );
    }
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Set a verse of the week first')),
          );
        }
        return;
      }

      final memorized = verseProvider.memorizedVerses;
      final settings = settingsProvider.settings;

      _interruptService ??= AudioInterruptService(
        audioService: AudioService(),
        notificationService: NotificationService(),
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
    double current = settingsProvider.settings.audioInterruptProbability;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Interrupt Probability'),
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
  // Clear history
  // ---------------------------------------------------------------------------

  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear Test History'),
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test history cleared')),
        );
      }
    }
  }

  @override
  void dispose() {
    _reviewService?.stopReview();
    _interruptService?.stopTracking();
    super.dispose();
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
