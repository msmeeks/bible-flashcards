import 'package:bible_flashcards/theme/app_theme.dart';
import 'package:bible_flashcards/widgets/esv_copyright_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    );

void main() {
  group('EsvCopyrightFooter', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('hasEsvContent false renders nothing', (tester) async {
      await tester
          .pumpWidget(_wrap(const EsvCopyrightFooter(hasEsvContent: false)));
      await tester.pumpAndSettle();

      expect(find.byType(EsvCopyrightFooter), findsOneWidget);
      expect(find.textContaining('ESV'), findsNothing);
    });

    testWidgets('pref absent renders expanded by default', (tester) async {
      await tester
          .pumpWidget(_wrap(const EsvCopyrightFooter(hasEsvContent: true)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Scripture quotations'), findsOneWidget);
      expect(find.text('Full terms in Settings'), findsOneWidget);
    });

    testWidgets('collapsed pref renders collapsed chip', (tester) async {
      SharedPreferences.setMockInitialValues({'esv_footer_collapsed_v1': true});
      await tester
          .pumpWidget(_wrap(const EsvCopyrightFooter(hasEsvContent: true)));
      await tester.pumpAndSettle();

      expect(find.text('ESV®'), findsOneWidget);
      expect(find.textContaining('Scripture quotations'), findsNothing);
    });

    testWidgets('tapping collapsed chip expands and persists pref',
        (tester) async {
      SharedPreferences.setMockInitialValues({'esv_footer_collapsed_v1': true});
      await tester
          .pumpWidget(_wrap(const EsvCopyrightFooter(hasEsvContent: true)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ESV®'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Scripture quotations'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('esv_footer_collapsed_v1'), false);
    });

    testWidgets('tapping collapse icon collapses and persists pref',
        (tester) async {
      await tester
          .pumpWidget(_wrap(const EsvCopyrightFooter(hasEsvContent: true)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Collapse copyright notice'));
      await tester.pumpAndSettle();

      expect(find.text('ESV®'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('esv_footer_collapsed_v1'), true);
    });

    testWidgets('live region node present in both states', (tester) async {
      await tester
          .pumpWidget(_wrap(const EsvCopyrightFooter(hasEsvContent: true)));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('ESV copyright notice expanded'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Collapse copyright notice'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('ESV copyright notice collapsed'),
        findsOneWidget,
      );
    });
  });
}
