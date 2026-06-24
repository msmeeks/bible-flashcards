import 'package:bible_flashcards/utils/book_name_variants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeBookNameKey', () {
    test('lowercases and strips spaces and dots', () {
      expect(normalizeBookNameKey('1 Pt.'), '1pt');
      expect(normalizeBookNameKey('  Mark  '), 'mark');
    });
  });

  group('bookNameToUsfm', () {
    test('resolves built-in abbreviations', () {
      expect(bookNameToUsfm('1 Pt'), '1PE');
      expect(bookNameToUsfm('Mark'), 'MRK');
      expect(bookNameToUsfm('Acts'), 'ACT');
    });

    test('resolves longhand and spoken-number forms', () {
      expect(bookNameToUsfm('The Gospel of Mark'), 'MRK');
      expect(bookNameToUsfm('First Peter'), '1PE');
      expect(bookNameToUsfm('The Book of Acts'), 'ACT');
    });

    test('returns null for unrecognized names', () {
      expect(bookNameToUsfm('Frodo'), isNull);
    });

    test('custom variants take precedence and add new mappings', () {
      expect(
        bookNameToUsfm('JPet', customVariants: {'jpet': '1PE'}),
        '1PE',
      );
    });

    test('bookDisplayNames covers every USFM code referenced by built-ins', () {
      for (final code in builtInBookNameVariants.values) {
        expect(bookDisplayNames.containsKey(code), isTrue,
            reason: '$code missing from bookDisplayNames');
      }
    });
  });
}
