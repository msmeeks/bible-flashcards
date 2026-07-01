import 'package:bible_flashcards/theme/app_colors.dart';
import 'package:bible_flashcards/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/contrast.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('dark theme text contrast', () {
    testWidgets('bodyLarge text color meets 4.5:1 against surface', (
      tester,
    ) async {
      final theme = AppTheme.dark();
      final textColor = theme.textTheme.bodyLarge!.color!;
      final ratio = contrastRatio(textColor, theme.colorScheme.surface);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    testWidgets('titleMedium and headlineSmall text meet 4.5:1 against surface', (
      tester,
    ) async {
      final theme = AppTheme.dark();
      for (final style in [
        theme.textTheme.titleMedium,
        theme.textTheme.headlineSmall,
      ]) {
        final ratio = contrastRatio(style!.color!, theme.colorScheme.surface);
        expect(ratio, greaterThanOrEqualTo(4.5));
      }
    });
  });

  group('light theme text contrast is unchanged', () {
    testWidgets('bodyLarge text color still resolves to onSurface', (
      tester,
    ) async {
      final theme = AppTheme.light();
      expect(theme.textTheme.bodyLarge!.color, theme.colorScheme.onSurface);
    });
  });

  group('success/warning token contrast', () {
    for (final label in ['light', 'dark']) {
      ColorScheme scheme() =>
          (label == 'light' ? AppTheme.light() : AppTheme.dark()).colorScheme;

      testWidgets(
        '$label onSuccessContainer meets 4.5:1 against successContainer',
        (tester) async {
          final s = scheme();
          final ratio = contrastRatio(
            s.onSuccessContainer,
            s.successContainer,
          );
          expect(ratio, greaterThanOrEqualTo(4.5));
        },
      );

      testWidgets(
        '$label onWarningContainer meets 4.5:1 against warningContainer',
        (tester) async {
          final s = scheme();
          final ratio = contrastRatio(
            s.onWarningContainer,
            s.warningContainer,
          );
          expect(ratio, greaterThanOrEqualTo(4.5));
        },
      );

      testWidgets('$label success meets 3:1 against surface (icon/large use)', (
        tester,
      ) async {
        final s = scheme();
        final ratio = contrastRatio(s.success, s.surface);
        expect(ratio, greaterThanOrEqualTo(3.0));
      });

      testWidgets('$label warning meets 3:1 against surface (icon/large use)', (
        tester,
      ) async {
        final s = scheme();
        final ratio = contrastRatio(s.warning, s.surface);
        expect(ratio, greaterThanOrEqualTo(3.0));
      });

      testWidgets(
        '$label onErrorContainer meets 4.5:1 against errorContainer',
        (tester) async {
          final s = scheme();
          final ratio = contrastRatio(s.onErrorContainer, s.errorContainer);
          expect(ratio, greaterThanOrEqualTo(4.5));
        },
      );

      testWidgets('$label error meets 3:1 against surface (icon/large use)', (
        tester,
      ) async {
        final s = scheme();
        final ratio = contrastRatio(s.error, s.surface);
        expect(ratio, greaterThanOrEqualTo(3.0));
      });
    }
  });
}
