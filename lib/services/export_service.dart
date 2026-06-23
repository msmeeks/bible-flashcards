import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';
import '../models/test_result.dart';
import '../providers/settings_provider.dart';

class ExportService {
  const ExportService({
    required DatabaseHelper db,
    required SettingsProvider settingsProvider,
  })  : _db = db,
        _settingsProvider = settingsProvider;

  final DatabaseHelper _db;
  final SettingsProvider _settingsProvider;

  Future<String> _buildPayloadJson({
    required bool includeHistory,
    required bool includeScores,
  }) async {
    final verses = await _db.getVerses();
    final results = includeHistory
        ? await _db.getTestResults()
        : const <VerseTestResult>[];
    final settings = _settingsProvider.settings;

    final payload = <String, dynamic>{
      'schema_version': 1,
      'source_app': 'bible_flashcards',
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'verses': verses.map((v) => v.toMap()).toList(),
      if (includeHistory) 'test_results': results.map((r) => r.toMap()).toList(),
      if (includeScores) 'settings': settings.toMap(),
    };
    return jsonEncode(payload);
  }

  Future<void> shareExport({
    bool includeScores = true,
    bool includeHistory = true,
  }) async {
    final json = await _buildPayloadJson(
      includeHistory: includeHistory,
      includeScores: includeScores,
    );

    final dir = await getApplicationDocumentsDirectory();
    final rand = Random.secure().nextInt(0xFFFFFF).toRadixString(16);
    final file = File('${dir.path}/bible_flashcards_export_$rand.json');
    File? created;
    try {
      await file.writeAsString(json);
      created = file;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Bible Flashcards backup',
      );
    } finally {
      try {
        if (created != null && created.existsSync()) await created.delete();
      } catch (_) {}
    }
  }

  // Builds payload JSON string for Drive backup — no file I/O, no share sheet.
  Future<String> buildExportJson({
    bool includeScores = true,
    bool includeHistory = true,
  }) =>
      _buildPayloadJson(
        includeHistory: includeHistory,
        includeScores: includeScores,
      );
}
