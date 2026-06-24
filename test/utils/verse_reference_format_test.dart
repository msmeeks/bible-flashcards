import 'package:bible_flashcards/utils/verse_reference_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatVerseReference', () {
    test('single verse, short book slug', () {
      expect(formatVerseReference('esv_phil_4_13'), 'Phil 4:13 (ESV)');
    });

    test('verse range, numbered book slug', () {
      expect(
        formatVerseReference('esv_1cor_15_3_4'),
        '1 Cor 15:3-4 (ESV)',
      );
    });

    test('unknown book slug returns input unchanged', () {
      expect(formatVerseReference('esv_xyz_1_1'), 'esv_xyz_1_1');
    });

    test('malformed id with fewer than 4 parts returns input unchanged', () {
      expect(formatVerseReference('esv_phil_4'), 'esv_phil_4');
      expect(formatVerseReference('esv'), 'esv');
      expect(formatVerseReference(''), '');
    });

    test('multi-digit chapter and verse', () {
      expect(formatVerseReference('esv_ps_119_105'), 'Ps 119:105 (ESV)');
    });

    test('translation is upper-cased regardless of input case', () {
      expect(formatVerseReference('niv_john_3_16'), 'John 3:16 (NIV)');
    });

    test('numbered-book slugs beyond 1cor', () {
      expect(formatVerseReference('esv_1sam_1_1'), '1 Sam 1:1 (ESV)');
      expect(formatVerseReference('esv_2kgs_2_2'), '2 Kgs 2:2 (ESV)');
      expect(formatVerseReference('esv_3john_1_4'), '3 John 1:4 (ESV)');
    });

    test('range with identical start/end is not collapsed', () {
      expect(formatVerseReference('esv_rom_8_28_28'), 'Rom 8:28-28 (ESV)');
    });

    test('extra trailing parts beyond verseEnd are ignored', () {
      expect(
        formatVerseReference('esv_phil_4_13_14_extra'),
        'Phil 4:13-14 (ESV)',
      );
    });

    test('alternate psalm slug "psa" maps to the same display name', () {
      expect(formatVerseReference('esv_psa_23_1'), 'Ps 23:1 (ESV)');
    });
  });
}
