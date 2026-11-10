import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/models/verse_pack.dart';
import 'package:bible_flashcards/providers/settings_provider.dart';
import 'package:bible_flashcards/providers/verse_provider.dart';
import 'package:bible_flashcards/services/export_service.dart';
import 'package:bible_flashcards/services/import_service.dart';

import '../helpers/fake_database_helper.dart';
import '../helpers/verse_factory.dart';

void main() {
  late DatabaseHelper db;
  late VerseProvider provider;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    await setUpFakeDatabase();
    db = DatabaseHelper();
    provider = VerseProvider(db);
  });

  tearDown(tearDownFakeDatabase);

  Future<String> exportJson() => ExportService(
        db: db,
        settingsProvider: SettingsProvider(),
      ).buildExportJson(includeSettings: false, includeHistory: false);

  Future<void> importJson(String json, {bool replace = false}) =>
      ImportService(db: db).import(json, replace: replace);

  Map<String, dynamic> backupWithPacks(List<Object?> packs) => {
        'schema_version': 1,
        'source_app': 'bible_flashcards',
        'verses': [makeVerse('v1', packId: 'user_1').toMap()],
        'packs': packs,
      };

  test('a user pack and its verses survive export and replace-import',
      () async {
    final packId = await provider.createPack('Romans Road');
    await db.insertVerse(makeVerse('v1', packId: packId));
    final json = await exportJson();

    await provider.deletePack(packId);
    await importJson(json, replace: true);
    await provider.loadVerses();

    expect(provider.packNameFor(packId), 'Romans Road');
    expect((await db.getVerses()).single.packId, packId);
  });

  test('exports only user packs, not built-in ones', () async {
    await db.insertPack('nav_tms_part1', 'TMS');
    await provider.createPack('Romans Road');

    final payload = jsonDecode(await exportJson()) as Map<String, dynamic>;
    final packs = (payload['packs'] as List).cast<Map<String, dynamic>>();

    expect(packs.map((p) => p['name']), ['Romans Road']);
  });

  test('replace-import removes user packs missing from the file', () async {
    final packId = await provider.createPack('Old Pack');
    final json = jsonEncode(backupWithPacks([]));

    await importJson(json, replace: true);
    await provider.loadVerses();

    expect(provider.packIds, isNot(contains(packId)));
  });

  test('merge-import keeps an existing pack name on id conflict', () async {
    await db.insertPack('user_1', 'Mine');

    await importJson(jsonEncode(backupWithPacks([
      {'id': 'user_1', 'name': 'Theirs'},
    ])));
    await provider.loadVerses();

    expect(provider.packNameFor('user_1'), 'Mine');
  });

  test('skips invalid pack entries', () async {
    await importJson(jsonEncode(backupWithPacks([
      {'id': 'nav_tms_part1', 'name': 'Hijacked built-in'},
      {'id': 'user_${'x' * 100}', 'name': 'Too long id'},
      {'id': 'user_2', 'name': '   '},
      {'id': 'user_3', 'name': 'n' * 41},
      {'id': 'user_4'},
      'not a map',
      {'id': 'user_1', 'name': '  Kept  '},
    ])));
    await provider.loadVerses();

    expect(provider.packIds, [VersePack.myVersesId, 'user_1']);
    expect(provider.packNameFor('user_1'), 'Kept');
  });

  test('a backup without packs still imports', () async {
    final json = jsonEncode(backupWithPacks([])..remove('packs'));

    await importJson(json);

    expect((await db.getVerses()).single.id, 'v1');
  });
}
