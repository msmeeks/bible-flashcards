import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bible_flashcards/services/bible_lookup_service.dart';

// Chapter response with specific verse numbers.
Map<String, dynamic> _chapterResponse({required List<Map<String, dynamic>> verses}) => {
      'verses': verses,
    };

Map<String, dynamic> _singleVerse(int verseNum, String text) =>
    {'verse': verseNum, 'text': text};

http.Client _mockClient(int status, Map<String, dynamic> body) =>
    MockClient((_) async => http.Response(jsonEncode(body), status));

http.Client _rawClient(int status, String body) =>
    MockClient((_) async => http.Response(body, status));

http.Client _errorClient() =>
    MockClient((_) async => throw Exception('network error'));

http.Client _timeoutClient() =>
    MockClient((_) async {
      await Future<void>.delayed(const Duration(seconds: 15));
      return http.Response('{}', 200);
    });

http.Client _countingClient(int Function() onCall, {int verseNum = 1}) =>
    MockClient((_) async {
      onCall();
      return http.Response(
        jsonEncode(_chapterResponse(verses: [_singleVerse(verseNum, 'Verse text.')])),
        200,
      );
    });

void main() {
  group('BibleLookupService.lookup', () {
    test('returns result on 200 for valid reference', () async {
      final service = BibleLookupService(
        client: _mockClient(200, _chapterResponse(verses: [_singleVerse(16, 'For God so loved.')])),
      );
      final r = await service.lookup('John 3:16', 'BSB');
      expect(r.text, 'For God so loved.');
      expect(r.reference, 'John 3:16');
      expect(r.translation, 'BSB');
      service.dispose();
    });

    test('caches repeated calls (same ref + translation = 1 HTTP call)', () async {
      var callCount = 0;
      final service = BibleLookupService(
        client: _countingClient(() => callCount++, verseNum: 1),
      );
      await service.lookup('John 1:1', 'BSB');
      await service.lookup('John 1:1', 'BSB');
      expect(callCount, 1);
      service.dispose();
    });

    test('different translations produce separate HTTP calls', () async {
      var callCount = 0;
      final service = BibleLookupService(
        client: _countingClient(() => callCount++, verseNum: 16),
      );
      await service.lookup('John 3:16', 'BSB');
      await service.lookup('John 3:16', 'KJV');
      expect(callCount, 2);
      service.dispose();
    });

    test('throws LookupException on 404', () async {
      final service = BibleLookupService(client: _mockClient(404, {}));
      await expectLater(
        service.lookup('Genesis 999:1', 'BSB'),
        throwsA(isA<LookupException>()),
      );
      service.dispose();
    });

    test('throws LookupException on non-200 non-404', () async {
      final service = BibleLookupService(client: _mockClient(500, {}));
      await expectLater(
        service.lookup('John 1:1', 'BSB'),
        throwsA(isA<LookupException>()),
      );
      service.dispose();
    });

    test('throws LookupException on network error', () async {
      final service = BibleLookupService(client: _errorClient());
      await expectLater(
        service.lookup('John 1:1', 'BSB'),
        throwsA(isA<LookupException>()),
      );
      service.dispose();
    });

    test('throws LookupException on timeout', () async {
      final service = BibleLookupService(client: _timeoutClient());
      await expectLater(
        service.lookup('John 1:1', 'BSB'),
        throwsA(
          isA<LookupException>().having((e) => e.message, 'message', contains('timed out')),
        ),
      );
      service.dispose();
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('throws ArgumentError on invalid reference (special chars)', () async {
      final service = BibleLookupService(client: _mockClient(200, {}));
      expect(
        () => service.lookup('<script>alert(1)</script>', 'BSB'),
        throwsA(isA<ArgumentError>()),
      );
      service.dispose();
    });

    test('throws ArgumentError on reference over 100 chars', () async {
      final service = BibleLookupService(client: _mockClient(200, {}));
      expect(
        () => service.lookup('A' * 101, 'BSB'),
        throwsA(isA<ArgumentError>()),
      );
      service.dispose();
    });

    test('accepts reference exactly 100 chars', () async {
      // Construct a valid 100-char reference: padded with extra spaces
      // "John 3:16" + spaces to reach 100 (regex allows spaces)
      final ref = 'John 3:16${' ' * 91}'; // 100 chars
      final service = BibleLookupService(
        client: _mockClient(200, _chapterResponse(verses: [_singleVerse(16, 'Text.')])),
      );
      // Regex allows it; parse will succeed (trim handles trailing spaces)
      final r = await service.lookup(ref, 'BSB');
      expect(r.translation, 'BSB');
      service.dispose();
    });

    test('accepts reference exactly 1 char — fails parse, not regex', () async {
      final service = BibleLookupService(client: _mockClient(200, {}));
      await expectLater(
        service.lookup('J', 'BSB'),
        throwsA(isA<LookupException>()),
      );
      service.dispose();
    });

    test('throws ArgumentError on unsupported translation', () async {
      final service = BibleLookupService(client: _mockClient(200, {}));
      expect(
        () => service.lookup('John 3:16', 'ESV'),
        throwsA(isA<ArgumentError>()),
      );
      service.dispose();
    });

    test('throws LookupException when verses list is empty', () async {
      final service = BibleLookupService(
        client: _mockClient(200, _chapterResponse(verses: [])),
      );
      await expectLater(
        service.lookup('John 1:1', 'BSB'),
        throwsA(isA<LookupException>()),
      );
      service.dispose();
    });

    test('throws LookupException when verses key is absent', () async {
      final service = BibleLookupService(client: _mockClient(200, {}));
      await expectLater(
        service.lookup('John 1:1', 'BSB'),
        throwsA(isA<LookupException>()),
      );
      service.dispose();
    });

    test('throws LookupException when all verse texts are whitespace', () async {
      final service = BibleLookupService(
        client: _mockClient(200, _chapterResponse(verses: [
          {'verse': 1, 'text': '   '},
        ])),
      );
      await expectLater(
        service.lookup('John 1:1', 'BSB'),
        throwsA(isA<LookupException>()),
      );
      service.dispose();
    });

    test('throws LookupException on malformed JSON', () async {
      final service = BibleLookupService(client: _rawClient(200, 'not valid json {'));
      await expectLater(
        service.lookup('John 1:1', 'BSB'),
        throwsA(isA<LookupException>()),
      );
      service.dispose();
    });

    test('throws LookupException when body is a JSON array (not object)', () async {
      final service = BibleLookupService(client: _rawClient(200, '[]'));
      await expectLater(
        service.lookup('John 1:1', 'BSB'),
        throwsA(isA<LookupException>()),
      );
      service.dispose();
    });

    test('concatenates multiple verses for a range', () async {
      final service = BibleLookupService(
        client: _mockClient(200, _chapterResponse(verses: [
          _singleVerse(1, 'Part one.'),
          _singleVerse(2, 'Part two.'),
          _singleVerse(3, 'Part three.'),
        ])),
      );
      final r = await service.lookup('Psalm 23:1-2', 'BSB');
      expect(r.text, 'Part one. Part two.');
      service.dispose();
    });

    test('parses book abbreviation (Rom → Romans)', () async {
      final service = BibleLookupService(
        client: _mockClient(200, _chapterResponse(verses: [_singleVerse(28, 'All things.')])),
      );
      final r = await service.lookup('Rom 8:28', 'BSB');
      expect(r.reference, 'Rom 8:28');
      service.dispose();
    });

    test('throws LookupException for unknown book name', () async {
      final service = BibleLookupService(client: _mockClient(200, {}));
      await expectLater(
        service.lookup('FakeBook 1:1', 'BSB'),
        throwsA(isA<LookupException>()),
      );
      service.dispose();
    });
  });
}
