import 'package:bible_flashcards/utils/reference_normalization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeReferenceForSave', () {
    test('resolves a built-in abbreviation to the full book name', () {
      final result = normalizeReferenceForSave('Phil 4:13');

      expect(result.isSuccess, isTrue);
      expect(result.reference, 'Philippians 4:13');
    });

    test('resolves a caller-supplied custom variant', () {
      final result = normalizeReferenceForSave(
        'Philippos 4:13',
        customVariants: const {'philippos': 'PHP'},
      );

      expect(result.isSuccess, isTrue);
      expect(result.reference, 'Philippians 4:13');
    });

    test('normalizes non-standard separators and range connectors', () {
      final dotSeparated = normalizeReferenceForSave('John 3.16');
      final wordedRange = normalizeReferenceForSave('Romans 8:28 to 30');

      expect(dotSeparated.reference, 'John 3:16');
      expect(wordedRange.reference, 'Romans 8:28-30');
    });

    test('fails with unresolvedBook when the book name is unrecognized', () {
      final result = normalizeReferenceForSave('Xyzzy 1:1');

      expect(result.isSuccess, isFalse);
      expect(result.reference, isNull);
      expect(result.failure, ReferenceNormalizationFailure.unresolvedBook);
    });

    test('fails with invalidFormat when the string has no chapter:verse', () {
      final result = normalizeReferenceForSave('Romans');

      expect(result.isSuccess, isFalse);
      expect(result.failure, ReferenceNormalizationFailure.invalidFormat);
    });
  });
}
