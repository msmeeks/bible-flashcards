import 'package:bible_flashcards/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('text theme font family', () {
    test('light theme scripture styles resolve to Lora', () {
      final theme = AppTheme.light();
      expect(theme.textTheme.bodyLarge?.fontFamily, 'Lora');
      expect(theme.textTheme.headlineSmall?.fontFamily, 'Lora');
    });

    test('dark theme scripture styles resolve to Lora', () {
      final theme = AppTheme.dark();
      expect(theme.textTheme.bodyLarge?.fontFamily, 'Lora');
      expect(theme.textTheme.headlineSmall?.fontFamily, 'Lora');
    });
  });
}
