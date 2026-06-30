import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bible_flashcards/widgets/inline_status_banner.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders nothing when message is null', (tester) async {
    await tester.pumpWidget(_wrap(
      const InlineStatusBanner(severity: BannerSeverity.error, message: null),
    ));

    expect(find.byType(Card), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('renders the message text when set', (tester) async {
    await tester.pumpWidget(_wrap(
      const InlineStatusBanner(
        severity: BannerSeverity.error,
        message: 'Something went wrong.',
      ),
    ));

    expect(find.text('Something went wrong.'), findsOneWidget);
  });

  testWidgets('filled (default) renders the message on a Card surface',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const InlineStatusBanner(
        severity: BannerSeverity.warning,
        message: 'At the limit.',
      ),
    ));

    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('filled: false renders the message without a Card surface',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const InlineStatusBanner(
        severity: BannerSeverity.error,
        message: 'Invalid reference.',
        filled: false,
      ),
    ));

    expect(find.byType(Card), findsNothing);
    expect(find.text('Invalid reference.'), findsOneWidget);
  });

  testWidgets('exposes the message as a live-region semantics label',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(
      const InlineStatusBanner(
        severity: BannerSeverity.error,
        message: 'Failed to save.',
      ),
    ));

    expect(find.bySemanticsLabel('Failed to save.'), findsWidgets);
    handle.dispose();
  });
}
