import 'package:bible_flashcards/screens/test/test_enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TestFormat.label', () {
    test('recite', () {
      expect(TestFormat.recite.label, 'Recite');
    });

    test('type', () {
      expect(TestFormat.type.label, 'Type');
    });

    test('fillBlank', () {
      expect(TestFormat.fillBlank.label, 'Fill Blanks');
    });
  });

  group('TestFormatLabel.tryFromName', () {
    test('matches a valid persisted name', () {
      expect(TestFormatLabel.tryFromName('fillBlank'), TestFormat.fillBlank);
    });

    test('returns null for an unrecognized name', () {
      expect(TestFormatLabel.tryFromName('fill_blank'), isNull);
    });
  });
}
