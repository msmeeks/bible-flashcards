import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bible_flashcards/services/esv_audio_cache_service.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('esv_audio_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('EsvAudioCacheService.getAudioPath', () {
    test('throws EsvAudioConsentRequired when consent not granted', () async {
      SharedPreferences.setMockInitialValues({});
      var called = false;
      final service = EsvAudioCacheService(
        client: MockClient((_) async {
          called = true;
          return http.Response('', 302);
        }),
        apiKey: 'test-key',
        cacheDir: tempDir,
      );

      await expectLater(
        service.getAudioPath('John 3:16'),
        throwsA(isA<EsvAudioConsentRequired>()),
      );
      expect(called, isFalse);
    });

    test('cache miss: resolves redirect, fetches MP3 without auth, writes file', () async {
      SharedPreferences.setMockInitialValues({'esv_lookup_consent_v1': true});
      String? authHeaderOnCdnRequest = 'unset';
      var resolveCalls = 0;

      final service = EsvAudioCacheService(
        client: MockClient((request) async {
          if (request.url.host == 'api.esv.org') {
            resolveCalls++;
            expect(request.headers['Authorization'], 'Token test-key');
            return http.Response('', 302, headers: {
              'location': 'https://audio.esv.org/john-3-16.mp3',
            });
          }
          if (request.url.host == 'audio.esv.org') {
            authHeaderOnCdnRequest = request.headers['Authorization'];
            return http.Response.bytes(List<int>.filled(10, 1), 200);
          }
          throw StateError('Unexpected host: ${request.url.host}');
        }),
        apiKey: 'test-key',
        cacheDir: tempDir,
      );

      final filePath = await service.getAudioPath('John 3:16');

      expect(resolveCalls, 1);
      expect(authHeaderOnCdnRequest, isNull);
      expect(File(filePath).existsSync(), isTrue);
      expect(File(filePath).readAsBytesSync().length, 10);
    });

    test('cache hit: returns path without making a network call', () async {
      SharedPreferences.setMockInitialValues({'esv_lookup_consent_v1': true});
      var networkCalls = 0;

      final service = EsvAudioCacheService(
        client: MockClient((request) async {
          networkCalls++;
          if (request.url.host == 'api.esv.org') {
            return http.Response('', 302, headers: {
              'location': 'https://audio.esv.org/john-3-16.mp3',
            });
          }
          return http.Response.bytes(List<int>.filled(10, 1), 200);
        }),
        apiKey: 'test-key',
        cacheDir: tempDir,
      );

      final firstPath = await service.getAudioPath('John 3:16');
      expect(networkCalls, 2);

      final secondPath = await service.getAudioPath('John 3:16');
      expect(secondPath, firstPath);
      expect(networkCalls, 2);
    });

    test('network failure resolving redirect throws EsvAudioException', () async {
      SharedPreferences.setMockInitialValues({'esv_lookup_consent_v1': true});
      final service = EsvAudioCacheService(
        client: MockClient((_) async => throw Exception('network down')),
        apiKey: 'test-key',
        cacheDir: tempDir,
      );

      await expectLater(
        service.getAudioPath('John 3:16'),
        throwsA(isA<EsvAudioException>()),
      );
    });

    test('non-redirect status from api.esv.org throws EsvAudioException', () async {
      SharedPreferences.setMockInitialValues({'esv_lookup_consent_v1': true});
      final service = EsvAudioCacheService(
        client: MockClient((_) async => http.Response('', 500)),
        apiKey: 'test-key',
        cacheDir: tempDir,
      );

      await expectLater(
        service.getAudioPath('John 3:16'),
        throwsA(isA<EsvAudioException>()),
      );
    });

    test('disallowed redirect host throws EsvAudioException (SSRF guard)', () async {
      SharedPreferences.setMockInitialValues({'esv_lookup_consent_v1': true});
      final service = EsvAudioCacheService(
        client: MockClient((request) async {
          if (request.url.host == 'api.esv.org') {
            return http.Response('', 302, headers: {
              'location': 'https://evil.example.com/payload.mp3',
            });
          }
          throw StateError('Should not contact evil.example.com');
        }),
        apiKey: 'test-key',
        cacheDir: tempDir,
      );

      await expectLater(
        service.getAudioPath('John 3:16'),
        throwsA(isA<EsvAudioException>()),
      );
    });

    test('cache filename is a safe hash even for path-traversal-like references', () async {
      SharedPreferences.setMockInitialValues({'esv_lookup_consent_v1': true});
      final service = EsvAudioCacheService(
        client: MockClient((request) async {
          if (request.url.host == 'api.esv.org') {
            return http.Response('', 302, headers: {
              'location': 'https://audio.esv.org/x.mp3',
            });
          }
          return http.Response.bytes(List<int>.filled(4, 9), 200);
        }),
        apiKey: 'test-key',
        cacheDir: tempDir,
      );

      final filePath = await service.getAudioPath('../../../etc/passwd');
      expect(path.isWithin(tempDir.path, filePath), isTrue);
      expect(filePath.contains('..'), isFalse);
      expect(RegExp(r'^[0-9a-f]{64}\.mp3$').hasMatch(path.basename(filePath)), isTrue);
    });

    test('in-flight deduplication: concurrent calls for same reference share one fetch', () async {
      SharedPreferences.setMockInitialValues({'esv_lookup_consent_v1': true});
      var resolveCalls = 0;

      final service = EsvAudioCacheService(
        client: MockClient((request) async {
          if (request.url.host == 'api.esv.org') {
            resolveCalls++;
            return http.Response('', 302, headers: {
              'location': 'https://audio.esv.org/x.mp3',
            });
          }
          return http.Response.bytes(List<int>.filled(4, 9), 200);
        }),
        apiKey: 'test-key',
        cacheDir: tempDir,
      );

      final results = await Future.wait([
        service.getAudioPath('John 3:16'),
        service.getAudioPath('John 3:16'),
      ]);

      expect(results[0], results[1]);
      expect(resolveCalls, 1);
    });

    test('evicts oldest file once cache exceeds the configured cap', () async {
      SharedPreferences.setMockInitialValues({'esv_lookup_consent_v1': true});
      final service = EsvAudioCacheService(
        client: MockClient((request) async {
          if (request.url.host == 'api.esv.org') {
            final ref = request.url.queryParameters['q'];
            return http.Response('', 302, headers: {
              'location': 'https://audio.esv.org/$ref.mp3',
            });
          }
          return http.Response.bytes(List<int>.filled(4, 9), 200);
        }),
        apiKey: 'test-key',
        cacheDir: tempDir,
        maxCachedFiles: 2,
      );

      final firstPath = await service.getAudioPath('Verse 1');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await service.getAudioPath('Verse 2');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await service.getAudioPath('Verse 3');

      expect(File(firstPath).existsSync(), isFalse);
    });
  });
}
