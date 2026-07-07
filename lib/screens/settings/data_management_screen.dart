import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../database/database_helper.dart';
import '../../providers/settings_provider.dart';
import '../../services/export_service.dart';
import '../../services/import_service.dart';
import '../../theme/app_colors.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  bool _exportLoading = false;
  bool _importLoading = false;
  bool _saveLocallyLoading = false;
  String _exportStatus = '';
  String _importStatus = '';
  String _saveLocallyStatus = '';

  final _exportTileFocusNode = FocusNode();
  final _saveLocallyTileFocusNode = FocusNode();
  final _importTileFocusNode = FocusNode();

  @override
  void dispose() {
    _exportTileFocusNode.dispose();
    _saveLocallyTileFocusNode.dispose();
    _importTileFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 24),
        ],
      ),
    );
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
            OutlinedButton(
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
            OutlinedButton(
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
            OutlinedButton(
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
          OutlinedButton(
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
}

enum _ImportMode { merge, replace }
