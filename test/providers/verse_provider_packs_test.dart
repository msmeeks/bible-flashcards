import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/models/verse_pack.dart';
import 'package:bible_flashcards/providers/verse_provider.dart';

import '../helpers/fake_database_helper.dart';
import '../helpers/verse_factory.dart';

void main() {
  late VerseProvider provider;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    await setUpFakeDatabase();
    provider = VerseProvider(DatabaseHelper());
  });

  tearDown(tearDownFakeDatabase);

  group('createPack', () {
    test('persists a user pack that survives a reload', () async {
      final id = await provider.createPack('Romans Road');

      final reloaded = VerseProvider(DatabaseHelper());
      await reloaded.loadVerses();

      expect(VersePack.isUserPackId(id), isTrue);
      expect(reloaded.packNameFor(id), 'Romans Road');
      expect(reloaded.packIds, contains(id));
    });
  });

  group('validatePackName', () {
    test('rejects blank names', () {
      expect(provider.validatePackName('   '), 'Enter a pack name');
    });

    test('accepts 40 characters and rejects 41', () {
      expect(provider.validatePackName('a' * 40), isNull);
      expect(provider.validatePackName('a' * 41),
          'Pack name must be 40 characters or fewer');
    });

    test('rejects a name already in use, ignoring case and spacing', () async {
      await provider.createPack('Romans Road');

      expect(provider.validatePackName('  romans road '),
          'You already have a pack with that name');
    });

    test('rejects "My Verses"', () {
      expect(provider.validatePackName('my verses'),
          'You already have a pack with that name');
    });

    test('lets a pack keep its own name when renaming', () async {
      final id = await provider.createPack('Romans Road');

      expect(provider.validatePackName('ROMANS ROAD', renaming: id), isNull);
    });

    test('createPack refuses an invalid name', () async {
      await expectLater(provider.createPack(''), throwsArgumentError);
      expect(provider.packIds, [VersePack.myVersesId]);
    });
  });

  group('renamePack', () {
    test('renames a user pack', () async {
      final id = await provider.createPack('Romans Road');

      await provider.renamePack(id, '  Gospel  ');

      expect(provider.packNameFor(id), 'Gospel');
    });

    test('refuses an invalid name and keeps the old one', () async {
      final id = await provider.createPack('Romans Road');

      await expectLater(provider.renamePack(id, ''), throwsArgumentError);
      expect(provider.packNameFor(id), 'Romans Road');
    });

    test('refuses to rename a built-in pack', () async {
      await DatabaseHelper().insertPack('nav_tms_part1', 'TMS');
      await provider.loadVerses();

      await expectLater(
          provider.renamePack('nav_tms_part1', 'Mine'), throwsArgumentError);
      expect(provider.packNameFor('nav_tms_part1'), 'TMS');
    });
  });

  group('deletePack', () {
    test('removes the pack and moves its verses to My Verses', () async {
      final id = await provider.createPack('Romans Road');
      await DatabaseHelper().insertVerse(makeVerse('v1', packId: id));
      await provider.loadVerses();

      await provider.deletePack(id);

      expect(provider.packIds, isNot(contains(id)));
      final verses = await DatabaseHelper().getVerses();
      expect(verses.single.packId, VersePack.myVersesId);
    });

    test('refuses to delete a built-in pack', () async {
      await DatabaseHelper().insertPack('nav_tms_part1', 'TMS');
      await provider.loadVerses();

      await expectLater(
          provider.deletePack('nav_tms_part1'), throwsArgumentError);
      expect(provider.packIds, contains('nav_tms_part1'));
    });
  });

  group('moveVerseToPack', () {
    test('saves the verse under the new pack', () async {
      final id = await provider.createPack('Romans Road');
      await DatabaseHelper()
          .insertVerse(makeVerse('v1', packId: 'custom', isMemorized: false));
      await provider.loadVerses();

      await provider.moveVerseToPack('v1', id);

      expect(provider.availableVerses.single.packId, id);
      final verses = await DatabaseHelper().getVerses();
      expect(verses.single.packId, id);
    });

    test('refuses an unknown pack', () async {
      await DatabaseHelper()
          .insertVerse(makeVerse('v1', packId: 'custom', isMemorized: false));
      await provider.loadVerses();

      await expectLater(
          provider.moveVerseToPack('v1', 'user_gone'), throwsArgumentError);
      expect(provider.availableVerses.single.packId, 'custom');
    });
  });
}
