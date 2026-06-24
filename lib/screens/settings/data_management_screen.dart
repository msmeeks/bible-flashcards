import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../database/database_helper.dart';
import '../../providers/settings_provider.dart';
import '../../services/export_service.dart';
import '../../services/google_drive_service.dart';
import '../../services/import_service.dart';
import '../../theme/app_colors.dart';

// Increment when the Drive consent disclosure text materially changes.
const _driveConsentVersion = 1;

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  final _driveService = GoogleDriveService();

  bool _exportLoading = false;
  bool _importLoading = false;
  bool _saveLocallyLoading = false;
  bool _driveLoading = false;
  String _exportStatus = '';
  String _importStatus = '';
  String _saveLocallyStatus = '';
  String _driveStatus = '';

  bool _driveSignedIn = false;

  final _exportTileFocusNode = FocusNode();
  final _saveLocallyTileFocusNode = FocusNode();
  final _importTileFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadSignInState();
  }

  @override
  void dispose() {
    _exportTileFocusNode.dispose();
    _saveLocallyTileFocusNode.dispose();
    _importTileFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSignInState() async {
    final signedIn = await _driveService.isSignedIn;
    if (mounted) setState(() => _driveSignedIn = signedIn);
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Data & Backup')),
      body: ListView(
        children: [
          // ----------------------------------------------------------------
          // Export
          // ----------------------------------------------------------------
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text(
                'Export',
                style: tt.labelLarge?.copyWith(color: cs.primary),
              ),
            ),
          ),
          ListTile(
            focusNode: _exportTileFocusNode,
            leading: const Icon(Symbols.upload_rounded),
            title: const Text('Export Data'),
            subtitle: const Text('Save a backup file to share or transfer'),
            onTap: _exportLoading ? null : _showExportDialog,
          ),
          if (_exportLoading)
            const LinearProgressIndicator(minHeight: 6),
          // Always-mounted live region keeps screen reader updated without remounting
          Semantics(
            liveRegion: true,
            child: _exportStatus.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
                    child: Text(_exportStatus,
                        style: tt.bodySmall?.copyWith(color: cs.primary)),
                  )
                : const SizedBox.shrink(),
          ),
          ListTile(
            focusNode: _saveLocallyTileFocusNode,
            leading: const Icon(Symbols.save_rounded),
            title: const Text('Save Locally'),
            subtitle: const Text('Save a backup file to a location you choose'),
            onTap: _saveLocallyLoading ? null : _showSaveLocallyDialog,
          ),
          if (_saveLocallyLoading)
            const LinearProgressIndicator(minHeight: 6),
          Semantics(
            liveRegion: true,
            child: _saveLocallyStatus.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
                    child: Text(_saveLocallyStatus,
                        style: tt.bodySmall?.copyWith(color: cs.primary)),
                  )
                : const SizedBox.shrink(),
          ),
          // ----------------------------------------------------------------
          // Import
          // ----------------------------------------------------------------
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text(
                'Import',
                style: tt.labelLarge?.copyWith(color: cs.primary),
              ),
            ),
          ),
          ListTile(
            focusNode: _importTileFocusNode,
            leading: const Icon(Symbols.download_rounded),
            title: const Text('Import Data'),
            subtitle: const Text('Restore from a backup file'),
            onTap: _importLoading ? null : _showImportDialog,
          ),
          if (_importLoading)
            const LinearProgressIndicator(minHeight: 6),
          Semantics(
            liveRegion: true,
            child: _importStatus.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
                    child: Text(_importStatus,
                        style: tt.bodySmall?.copyWith(color: cs.primary)),
                  )
                : const SizedBox.shrink(),
          ),
          // ----------------------------------------------------------------
          // Google Drive
          // ----------------------------------------------------------------
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text(
                'Cloud Backup',
                style: tt.labelLarge?.copyWith(color: cs.primary),
              ),
            ),
          ),
          if (!_driveSignedIn) ...[
            ListTile(
              leading: const Icon(Symbols.backup_rounded),
              title: const Text('Connect Google Drive'),
              subtitle: const Text(
                'Backs up verse data and test history to your Google Drive. '
                'Data leaves this device.',
              ),
              onTap: _driveLoading ? null : _showDriveConsentDialog,
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Symbols.backup_rounded),
              title: const Text('Back Up Now'),
              subtitle: _buildLastBackupSubtitle(settings.lastBackupAt, tt),
              onTap: _driveLoading ? null : _doBackup,
            ),
            // onTap: null — SegmentedButton is the sole interaction target
            ListTile(
              title: const Text('Backup Frequency'),
              onTap: null,
              trailing: SegmentedButton<String>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                segments: const [
                  ButtonSegment(value: 'daily', label: Text('Daily')),
                  ButtonSegment(value: 'weekly', label: Text('Weekly')),
                  ButtonSegment(value: 'monthly', label: Text('Monthly')),
                ],
                selected: {settings.backupCadence},
                onSelectionChanged: (selected) {
                  settingsProvider.update(
                    settings.copyWith(backupCadence: selected.first),
                  );
                },
              ),
            ),
            ListTile(
              leading: Icon(Symbols.restore_rounded, color: cs.primary),
              title: const Text('Restore from Drive'),
              subtitle: const Text('Replace local data with latest backup'),
              onTap: _driveLoading ? null : _showRestoreDialog,
            ),
            ListTile(
              leading: ExcludeSemantics(
                child: Icon(Icons.delete_outline_rounded, color: cs.error),
              ),
              title: const Text('Delete Drive Backup'),
              subtitle: const Text('Remove all backup files from Google Drive'),
              onTap: _showDeleteDriveBackupDialog,
            ),
            ListTile(
              leading: const ExcludeSemantics(
                child: Icon(Icons.logout_rounded),
              ),
              title: const Text('Disconnect Google Drive'),
              onTap: _disconnectDrive,
            ),
          ],
          if (_driveLoading)
            const LinearProgressIndicator(minHeight: 6),
          Semantics(
            liveRegion: true,
            child: _driveStatus.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
                    child: Text(_driveStatus,
                        style: tt.bodySmall?.copyWith(color: cs.primary)),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget? _buildLastBackupSubtitle(DateTime? lastBackupAt, TextTheme tt) {
    if (lastBackupAt == null) return const Text('Never backed up');
    final diff = DateTime.now().difference(lastBackupAt);
    final label = diff.inDays > 0
        ? '${diff.inDays}d ago'
        : diff.inHours > 0
            ? '${diff.inHours}h ago'
            : 'Just now';
    return Text('Last backup: $label');
  }

  // ---------------------------------------------------------------------------
  // Export dialog
  // ---------------------------------------------------------------------------

  Future<void> _showExportDialog() async {
    var includeHistory = true;
    var includeSettings = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          semanticLabel: 'Export options',
          title: const Text('Export Data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose what to include in the backup file. '
                'The file will be shared from this device.',
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Include test history'),
                value: includeHistory,
                onChanged: (v) => setS(() => includeHistory = v ?? true),
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                title: const Text('Include app settings'),
                subtitle: const Text('Audio, notification, and theme preferences'),
                value: includeSettings,
                onChanged: (v) => setS(() => includeSettings = v ?? true),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Export'),
            ),
          ],
        ),
      ),
    );

    _exportTileFocusNode.requestFocus();
    if (confirmed != true || !mounted) return;

    final settingsProvider = context.read<SettingsProvider>();
    setState(() {
      _exportLoading = true;
      _exportStatus = 'Preparing export…';
    });

    try {
      final exportService = ExportService(
        db: DatabaseHelper(),
        settingsProvider: settingsProvider,
      );
      await exportService.shareExport(
        includeHistory: includeHistory,
        includeSettings: includeSettings,
      );
      if (mounted) setState(() => _exportStatus = 'Export complete');
    } catch (_) {
      if (mounted) {
        setState(() => _exportStatus = 'Export failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _exportLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Save Locally dialog
  // ---------------------------------------------------------------------------

  Future<void> _showSaveLocallyDialog() async {
    var includeHistory = true;
    var includeSettings = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          semanticLabel: 'Save locally options',
          title: const Text('Save Locally'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose what to include, then pick a location to save the '
                'backup file on this device.',
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Include test history'),
                value: includeHistory,
                onChanged: (v) => setS(() => includeHistory = v ?? true),
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                title: const Text('Include app settings'),
                subtitle: const Text('Audio, notification, and theme preferences'),
                value: includeSettings,
                onChanged: (v) => setS(() => includeSettings = v ?? true),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Choose Location'),
            ),
          ],
        ),
      ),
    );

    _saveLocallyTileFocusNode.requestFocus();
    if (confirmed != true || !mounted) return;

    final settingsProvider = context.read<SettingsProvider>();
    setState(() {
      _saveLocallyLoading = true;
      _saveLocallyStatus = 'Preparing backup…';
    });

    try {
      final exportService = ExportService(
        db: DatabaseHelper(),
        settingsProvider: settingsProvider,
      );
      final saved = await exportService.saveExportToFile(
        includeHistory: includeHistory,
        includeSettings: includeSettings,
      );
      _saveLocallyTileFocusNode.requestFocus();
      if (mounted) {
        setState(() => _saveLocallyStatus =
            saved ? 'Backup saved' : 'Save cancelled');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saveLocallyStatus = 'Save failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saveLocallyLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Import dialog
  // ---------------------------------------------------------------------------

  Future<void> _showImportDialog() async {
    var importMode = _ImportMode.merge;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          semanticLabel: 'Import options',
          title: const Text('Import Data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose how to handle existing data:'),
              const SizedBox(height: 8),
              RadioGroup<_ImportMode>(
                groupValue: importMode,
                onChanged: (v) {
                  if (v != null) setS(() => importMode = v);
                },
                child: Semantics(
                  label: 'Import mode',
                  explicitChildNodes: true,
                  child: const Column(
                    children: [
                      RadioListTile<_ImportMode>(
                        title: Text('Merge'),
                        subtitle: Text('Add new data without overwriting'),
                        value: _ImportMode.merge,
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<_ImportMode>(
                        title: Text('Replace'),
                        subtitle:
                            Text('Delete all existing data and replace'),
                        value: _ImportMode.replace,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              if (importMode == _ImportMode.replace)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Icon(
                        Symbols.warning_rounded,
                        color: Theme.of(ctx).colorScheme.warning,
                        semanticLabel: 'Warning',
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'All existing verses and test history will be '
                          'permanently deleted.',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(importMode == _ImportMode.replace
                  ? 'Replace All Data'
                  : 'Import'),
            ),
          ],
        ),
      ),
    );

    _importTileFocusNode.requestFocus();
    if (confirmed != true || !mounted) return;

    // Extra confirmation for replace mode
    if (importMode == _ImportMode.replace) {
      final doubleConfirmed = await _confirmReplaceAll();
      if (!doubleConfirmed || !mounted) return;
    }

    setState(() {
      _importLoading = true;
      _importStatus = 'Select a backup file…';
    });

    try {
      final jsonString = await _pickJsonFile();
      _importTileFocusNode.requestFocus();
      if (jsonString == null) {
        if (mounted) setState(() => _importStatus = 'Import cancelled');
        return;
      }
      if (!mounted) return;
      setState(() => _importStatus = 'Importing…');

      final importService = ImportService(db: DatabaseHelper());
      final summary = await importService.import(
        jsonString,
        replace: importMode == _ImportMode.replace,
      );

      if (mounted) {
        setState(() => _importStatus =
            'Imported ${summary.versesImported} verses, '
            '${summary.resultsImported} test results');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported ${summary.versesImported} verses, '
              '${summary.resultsImported} test results',
            ),
          ),
        );
      }
    } on ImportException catch (e) {
      if (mounted) {
        setState(() => _importStatus = 'Import failed: ${e.message}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: ${e.message}')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _importStatus = 'Import failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _importLoading = false);
    }
  }

  Future<bool> _confirmReplaceAll() async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        semanticLabel: 'Replace all data confirmation',
        title: Row(
          children: [
            Icon(Symbols.warning_rounded, color: cs.warning, semanticLabel: ''),
            const SizedBox(width: 8),
            const Text('Replace All Data?'),
          ],
        ),
        content: const Text(
          'This will permanently delete ALL existing verses and test history. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Replace All Data'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  // Reads picked bytes directly — never opens a raw filesystem path with
  // dart:io, since Android may hand back a SAF content:// URI rather than
  // a real path on some API levels/configs.
  Future<String?> _pickJsonFile() async {
    final result = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    final bytes = result?.files.firstOrNull?.bytes;
    if (bytes == null) return null;
    return utf8.decode(bytes);
  }

  // ---------------------------------------------------------------------------
  // Google Drive consent dialog
  // ---------------------------------------------------------------------------

  Future<void> _showDriveConsentDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        semanticLabel: 'Google Drive backup consent',
        title: const Text('Connect Google Drive?'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bible Flashcards will back up your verse data and test '
                'history to your personal Google Drive (appdata folder).',
              ),
              SizedBox(height: 12),
              Text('What this means:'),
              SizedBox(height: 4),
              Text('• Your data will be sent to Google\'s servers'),
              Text(
                  '• Google is the data processor — subject to their Terms of Service'),
              Text(
                '• This backup is not end-to-end encrypted. '
                'Google can access it under their terms.',
              ),
              Text('• You can delete the backup at any time from this screen'),
              SizedBox(height: 12),
              Text(
                'Only the drive.appdata scope is requested — backup files '
                'are not visible in your regular Drive.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No Thanks'),
          ),
          Semantics(
            label: 'Connect Google Drive account',
            child: FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Connect'),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _driveLoading = true;
      _driveStatus = 'Signing in to Google…';
    });

    try {
      await _driveService.signIn();
      if (!mounted) return;
      final now = DateTime.now().toUtc().toIso8601String();
      final settingsProvider = context.read<SettingsProvider>();
      await settingsProvider.update(settingsProvider.settings.copyWith(
        driveBackupEnabled: true,
        driveConsentAt: now,
        driveConsentVersion: _driveConsentVersion,
      ));
      if (mounted) {
        setState(() {
          _driveSignedIn = true;
          _driveStatus = 'Connected to Google Drive';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _driveStatus = 'Sign-in failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _driveLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Drive operations
  // ---------------------------------------------------------------------------

  Future<void> _doBackup() async {
    setState(() {
      _driveLoading = true;
      _driveStatus = 'Backing up…';
    });

    try {
      final settingsProvider = context.read<SettingsProvider>();
      final exportService = ExportService(
        db: DatabaseHelper(),
        settingsProvider: settingsProvider,
      );
      final json = await exportService.buildExportJson();
      await _driveService.backup(json);
      if (!mounted) return;
      final now = DateTime.now();
      await context
          .read<SettingsProvider>()
          .update(context.read<SettingsProvider>().settings.copyWith(lastBackupAt: now));
      if (mounted) setState(() => _driveStatus = 'Backup complete');
    } catch (_) {
      if (mounted) {
        setState(
            () => _driveStatus = 'Backup failed. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _driveLoading = false);
    }
  }

  Future<void> _showRestoreDialog() async {
    final confirmed = await _confirmReplaceAll();
    if (!confirmed || !mounted) return;

    setState(() {
      _driveLoading = true;
      _driveStatus = 'Downloading backup…';
    });

    try {
      final jsonString = await _driveService.restore();
      if (jsonString == null) {
        if (mounted) setState(() => _driveStatus = 'No backup found on Drive');
        return;
      }
      if (!mounted) return;
      setState(() => _driveStatus = 'Restoring…');
      final importService = ImportService(db: DatabaseHelper());
      final summary = await importService.import(jsonString, replace: true);
      if (mounted) {
        setState(() => _driveStatus = 'Restored ${summary.versesImported} verses');
      }
    } on ImportException catch (e) {
      if (mounted) {
        setState(() => _driveStatus = 'Restore failed: ${e.message}');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _driveStatus = 'Restore failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _driveLoading = false);
    }
  }

  Future<void> _showDeleteDriveBackupDialog() async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        semanticLabel: 'Delete Drive backup confirmation',
        title: const Text('Delete Drive Backup?'),
        content: const Text(
          'All backup files will be permanently deleted from Google Drive. '
          'Your local data will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Backup'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _driveLoading = true;
      _driveStatus = 'Deleting backup…';
    });

    try {
      await _driveService.deleteBackup();
      if (mounted) setState(() => _driveStatus = 'Backup deleted from Drive');
    } catch (_) {
      if (mounted) {
        setState(() => _driveStatus = 'Delete failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _driveLoading = false);
    }
  }

  Future<void> _disconnectDrive() async {
    await _driveService.signOut();
    if (!mounted) return;
    final settingsProvider = context.read<SettingsProvider>();
    await settingsProvider.update(
      settingsProvider.settings.copyWith(
        driveBackupEnabled: false,
        clearLastBackupAt: true,
      ),
    );
    if (mounted) {
      setState(() {
        _driveSignedIn = false;
        _driveStatus = 'Disconnected from Google Drive';
      });
    }
  }
}

enum _ImportMode { merge, replace }
