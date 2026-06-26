import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bible_flashcards/services/bible_lookup_service.dart' show LookupException;
import 'package:bible_flashcards/services/esv_lookup_service.dart';

http.Client _mockClient(int status, String body) =>
    MockClient((_) async => http.Response(body, status));

http.Client _errorClient() => MockClient((_) async => throw Exception('network error'));

http.Client _timeoutClient() => MockClient((_) async {
      await Future<void>.delayed(const Duration(seconds: 15));
      return http.Response('{}', 200);
    });

void main() {
  group('EsvLookupService.lookup', () {
    test('returns VerseLookupResult with translation ESV on success', () async {
      final service = EsvLookupService(
        client: _mockClient(200, '{"passages": ["For God so loved the world. "]}'),
        apiKey: 'test-key',
      );
      final r = await service.lookup('John 3:16');
      expect(r.text, 'For God so loved the world.');
      expect(r.translation, 'ESV');
      expect(r.reference, 'John 3:16');
      service.dispose();
    });

    test('throws LookupException on 404', () async {
      final service = EsvLookupService(client: _mockClient(404, '{}'), apiKey: 'test-key');
      await expectLater(service.lookup('John 3:16'), throwsA(isA<LookupException>()));
      service.dispose();
    });

    test('throws LookupException on timeout', () async {
      final service = EsvLookupService(client: _timeoutClient(), apiKey: 'test-key');
      await expectLater(
        service.lookup('John 3:16'),
        throwsA(isA<LookupException>().having((e) => e.message, 'message', contains('timed out'))),
      );
      service.dispose();
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('throws LookupException on network error', () async {
      final service = EsvLookupService(client: _errorClient(), apiKey: 'test-key');
      await expectLater(service.lookup('John 3:16'), throwsA(isA<LookupException>()));
      service.dispose();
    });

    test('throws LookupException on bad JSON', () async {
      final service = EsvLookupService(client: _mockClient(200, 'not json {'), apiKey: 'test-key');
      await expectLater(service.lookup('John 3:16'), throwsA(isA<LookupException>()));
      service.dispose();
    });

    test('throws LookupException when passages list is empty', () async {
      final service =
          EsvLookupService(client: _mockClient(200, '{"passages": []}'), apiKey: 'test-key');
      await expectLater(service.lookup('John 3:16'), throwsA(isA<LookupException>()));
      service.dispose();
    });

    test('caches repeated calls (same ref = 1 HTTP call)', () async {
      var callCount = 0;
      final service = EsvLookupService(
        client: MockClient((_) async {
          callCount++;
          return http.Response('{"passages": ["Text. "]}', 200);
        }),
        apiKey: 'test-key',
      );
      await service.lookup('John 1:1');
      await service.lookup('John 1:1');
      expect(callCount, 1);
      service.dispose();
    });

    test('throws ArgumentError on invalid reference format', () async {
      final service =
          EsvLookupService(client: _mockClient(200, '{}'), apiKey: 'test-key');
      expect(
        () => service.lookup('<script>alert(1)</script>'),
        throwsA(isA<ArgumentError>()),
      );
      service.dispose();
    });

    test('throws LookupException for unknown book name', () async {
      final service = EsvLookupService(client: _mockClient(200, '{}'), apiKey: 'test-key');
      await expectLater(service.lookup('FakeBook 1:1'), throwsA(isA<LookupException>()));
      service.dispose();
    });

    test('isAvailable is false when API key is empty', () {
      final service = EsvLookupService(client: _mockClient(200, '{}'), apiKey: '');
      expect(service.isAvailable, isFalse);
      service.dispose();
    });

    test('isAvailable is true when API key is set', () {
      final service = EsvLookupService(client: _mockClient(200, '{}'), apiKey: 'test-key');
      expect(service.isAvailable, isTrue);
      service.dispose();
    });

    test('lookup throws StateError when API key is empty', () async {
      final service = EsvLookupService(client: _mockClient(200, '{}'), apiKey: '');
      await expectLater(service.lookup('John 3:16'), throwsA(isA<StateError>()));
      service.dispose();
    });

    test('sends Authorization header with Token prefix', () async {
      String? authHeader;
      final service = EsvLookupService(
        client: MockClient((req) async {
          authHeader = req.headers['Authorization'];
          return http.Response('{"passages": ["Text. "]}', 200);
        }),
        apiKey: 'my-secret-key',
      );
      await service.lookup('John 1:1');
      expect(authHeader, 'Token my-secret-key');
      service.dispose();
    });

    test('request goes only to api.esv.org over HTTPS', () async {
      Uri? requestedUri;
      final service = EsvLookupService(
        client: MockClient((req) async {
          requestedUri = req.url;
          return http.Response('{"passages": ["Text. "]}', 200);
        }),
        apiKey: 'test-key',
      );
      await service.lookup('John 1:1');
      expect(requestedUri!.scheme, 'https');
      expect(requestedUri!.host, 'api.esv.org');
      service.dispose();
    });
  });
}
