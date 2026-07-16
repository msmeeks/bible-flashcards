import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bundled verse pack assets', () {
    test(
        'navigators_pack.json references use ASCII hyphens for verse ranges, not Unicode dashes',
        () {
      final raw = File('assets/packs/navigators_pack.json').readAsStringSync();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final packs = json['packs'] as List<dynamic>;
      final verses = [
        for (final pack in packs)
          ...(pack as Map<String, dynamic>)['verses'] as List<dynamic>,
      ];

      final badReferences = [
        for (final v in verses)
          if ((v as Map<String, dynamic>)['reference'] as String case final ref
              when ref.contains('–') || ref.contains('—'))
            ref,
      ];

      expect(badReferences, isEmpty,
          reason: 'Verse ranges must use ASCII "-", not an en/em dash — '
              'these fail reference parsing used for lenient book-name '
              'scoring. Offending references: $badReferences');
    });
  });
}
