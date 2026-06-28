import 'package:bible_flashcards/widgets/announce_on_change.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnnounceOnChange', () {
    testWidgets('does not announce on first mount', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AnnounceOnChange(
          value: 'first',
          builder: (context, liveRegion) => Semantics(
            liveRegion: liveRegion,
            label: 'first',
            child: const Text('first'),
          ),
        ),
      ));

      final semantics = tester.getSemantics(find.text('first'));
      expect(semantics.hasFlag(SemanticsFlag.isLiveRegion), false);
    });

    testWidgets('announces once on a real value transition', (tester) async {
      String value = 'collapsed';
      late StateSetter setState;

      await tester.pumpWidget(MaterialApp(
        home: StatefulBuilder(
          builder: (context, setter) {
            setState = setter;
            return AnnounceOnChange(
              value: value,
              builder: (context, liveRegion) => Semantics(
                liveRegion: liveRegion,
                label: value,
                child: Text(value),
              ),
            );
          },
        ),
      ));

      setState(() => value = 'expanded');
      await tester.pump();

      final semantics = tester.getSemantics(find.text('expanded'));
      expect(semantics.hasFlag(SemanticsFlag.isLiveRegion), true);

      // Live flag resets after the post-frame callback fires.
      await tester.pump();
      final settled = tester.getSemantics(find.text('expanded'));
      expect(settled.hasFlag(SemanticsFlag.isLiveRegion), false);
    });

    testWidgets('does not re-announce on an unrelated rebuild', (tester) async {
      const value = 'steady';
      late StateSetter setState;
      var unrelated = 0;

      await tester.pumpWidget(MaterialApp(
        home: StatefulBuilder(
          builder: (context, setter) {
            setState = setter;
            return AnnounceOnChange(
              value: value,
              builder: (context, liveRegion) => Semantics(
                liveRegion: liveRegion,
                label: '$value-$unrelated',
                child: Text('$value-$unrelated'),
              ),
            );
          },
        ),
      ));

      setState(() => unrelated++);
      await tester.pump();

      final semantics = tester.getSemantics(find.text('steady-1'));
      expect(semantics.hasFlag(SemanticsFlag.isLiveRegion), false);
    });
  });
}
