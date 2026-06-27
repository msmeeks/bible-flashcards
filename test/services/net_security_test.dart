import 'package:flutter_test/flutter_test.dart';

import 'package:bible_flashcards/services/net_security.dart';

void main() {
  group('assertAllowedHttpsHost', () {
    test('allows an https URL whose host is in the allowlist', () {
      expect(
        () => assertAllowedHttpsHost(
          Uri.parse('https://api.esv.org/v3/passage/text/'),
          {'api.esv.org'},
        ),
        returnsNormally,
      );
    });

    test('rejects a non-https scheme', () {
      expect(
        () => assertAllowedHttpsHost(
          Uri.parse('http://api.esv.org/v3/passage/text/'),
          {'api.esv.org'},
        ),
        throwsStateError,
      );
    });

    test('rejects a host not in the allowlist', () {
      expect(
        () => assertAllowedHttpsHost(
          Uri.parse('https://evil.example.com/'),
          {'api.esv.org'},
        ),
        throwsStateError,
      );
    });
  });
}
