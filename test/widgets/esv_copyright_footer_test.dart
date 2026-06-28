import 'package:bible_flashcards/theme/app_theme.dart';
import 'package:bible_flashcards/widgets/esv_copyright_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
      await tester.pumpWidget(_wrap(EsvCopyrightFooter(
        hasEsvContent: false,
        onViewFullTerms: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.byType(EsvCopyrightFooter), findsOneWidget);
      expect(find.textContaining('ESV'), findsNothing);
    });

    testWidgets('pref absent renders expanded by default', (tester) async {
      await tester.pumpWidget(_wrap(EsvCopyrightFooter(
        hasEsvContent: true,
        onViewFullTerms: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('Scripture quotations'), findsOneWidget);
      expect(find.text('Full terms in Settings'), findsOneWidget);
    });

    testWidgets('collapsed pref renders collapsed chip', (tester) async {
      SharedPreferences.setMockInitialValues({'esv_footer_collapsed_v1': true});
      await tester.pumpWidget(_wrap(EsvCopyrightFooter(
        hasEsvContent: true,
        onViewFullTerms: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('ESV®'), findsOneWidget);
      expect(find.textContaining('Scripture quotations'), findsNothing);
    });

    testWidgets('tapping collapsed chip expands and persists pref',
        (tester) async {
      SharedPreferences.setMockInitialValues({'esv_footer_collapsed_v1': true});
      await tester.pumpWidget(_wrap(EsvCopyrightFooter(
        hasEsvContent: true,
        onViewFullTerms: () {},
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ESV®'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Scripture quotations'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('esv_footer_collapsed_v1'), false);
    });

    testWidgets('tapping collapse icon collapses and persists pref',
        (tester) async {
      await tester.pumpWidget(_wrap(EsvCopyrightFooter(
        hasEsvContent: true,
        onViewFullTerms: () {},
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Collapse copyright notice'));
      await tester.pumpAndSettle();

      expect(find.text('ESV®'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('esv_footer_collapsed_v1'), true);
    });

    testWidgets('tapping "Full terms in Settings" invokes the callback '
        'instead of navigating', (tester) async {
      var calls = 0;
      await tester.pumpWidget(_wrap(EsvCopyrightFooter(
        hasEsvContent: true,
        onViewFullTerms: () => calls++,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Full terms in Settings'));
      await tester.pumpAndSettle();

      expect(calls, 1);
      // No navigation occurred — original screen is still showing.
      expect(find.byType(EsvCopyrightFooter), findsOneWidget);
    });

    testWidgets('does not announce a live region on first mount',
        (tester) async {
      await tester.pumpWidget(_wrap(EsvCopyrightFooter(
        hasEsvContent: true,
        onViewFullTerms: () {},
      )));
      await tester.pumpAndSettle();

      final candidates = find.bySemanticsLabel('ESV copyright notice expanded');
      expect(candidates, findsOneWidget);
      final semantics = tester.getSemantics(candidates);
      expect(semantics.hasFlag(SemanticsFlag.isLiveRegion), false);
    });

    testWidgets('announces exactly once per real collapse/expand transition',
        (tester) async {
      await tester.pumpWidget(_wrap(EsvCopyrightFooter(
        hasEsvContent: true,
        onViewFullTerms: () {},
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Collapse copyright notice'));
      await tester.pump();

      final liveNodes = tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
      var liveRegionCount = 0;
      void visit(SemanticsNode node) {
        if (node.hasFlag(SemanticsFlag.isLiveRegion)) liveRegionCount++;
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }
      visit(liveNodes);
      expect(liveRegionCount, 1);

      await tester.pumpAndSettle();
      expect(find.text('ESV®'), findsOneWidget);
    });

    testWidgets('collapsed toggle is keyboard focusable', (tester) async {
      SharedPreferences.setMockInitialValues({'esv_footer_collapsed_v1': true});
      await tester.pumpWidget(_wrap(EsvCopyrightFooter(
        hasEsvContent: true,
        onViewFullTerms: () {},
      )));
      await tester.pumpAndSettle();

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      final iconFinder = find.descendant(
        of: find.byType(IconButton),
        matching: find.byType(Icon),
      );
      expect(iconFinder, findsWidgets);
      final node = Focus.of(tester.element(iconFinder.first));
      expect(node.canRequestFocus, true);
      expect(iconButton.onPressed, isNotNull);
    });

    testWidgets('collapsed toggle meets the 48x48dp minimum tap target',
        (tester) async {
      SharedPreferences.setMockInitialValues({'esv_footer_collapsed_v1': true});
      await tester.pumpWidget(_wrap(EsvCopyrightFooter(
        hasEsvContent: true,
        onViewFullTerms: () {},
      )));
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });
}
