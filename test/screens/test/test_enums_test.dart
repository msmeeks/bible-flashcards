import 'package:bible_flashcards/screens/test/test_enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TestFormat.label', () {
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

    // Rows written before #165 removed the format still carry "recite";
    // callers render the raw string rather than crashing on the null.
    test('returns null for the retired "recite" format', () {
      expect(TestFormatLabel.tryFromName('recite'), isNull);
    });
  });

  group('BlankDensity.label', () {
    test('fixed percentages', () {
      expect(BlankDensity.twenty.label, '20%');
      expect(BlankDensity.thirty.label, '30%');
      expect(BlankDensity.fifty.label, '50%');
      expect(BlankDensity.seventyFive.label, '75%');
    });

    test('random', () {
      expect(BlankDensity.random.label, 'Random');
    });
  });

  group('BlankDensity.percentage', () {
    test('fixed options return their percentage', () {
      expect(BlankDensity.twenty.percentage, 20);
      expect(BlankDensity.thirty.percentage, 30);
      expect(BlankDensity.fifty.percentage, 50);
      expect(BlankDensity.seventyFive.percentage, 75);
    });

    test('random throws — callers must roll a fixed percentage instead', () {
      expect(() => BlankDensity.random.percentage, throwsStateError);
    });
  });
}
