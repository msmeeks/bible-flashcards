import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bible_flashcards/services/system_audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  late SystemAudioService service;

  /// Installs a handler standing in for the Android side of the channel.
  /// [respond] returns the value the platform would send back; throwing from
  /// it simulates a platform error.
  void mockPlatform(Object? Function(MethodCall call) respond) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemAudioService.channel, (call) async {
      calls.add(call);
      return respond(call);
    });
  }

  setUp(() {
    calls = [];
    service = SystemAudioService();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemAudioService.channel, null);
  });

  group('SystemAudioService.isMusicActive', () {
    test('reports true when the platform says other audio is playing',
        () async {
      mockPlatform((_) => true);
      expect(await service.isMusicActive(), isTrue);
      expect(calls.single.method, 'isMusicActive');
    });

    test('reports false when the platform says no other audio is playing',
        () async {
      mockPlatform((_) => false);
      expect(await service.isMusicActive(), isFalse);
    });

    test('reports false rather than throwing when the platform errors',
        () async {
      mockPlatform((_) => throw PlatformException(code: 'UNAVAILABLE'));
      expect(await service.isMusicActive(), isFalse);
    });

    test('reports false when the channel is not registered at all', () async {
      // No mock handler installed -> MissingPluginException.
      expect(await service.isMusicActive(), isFalse);
    });

    test('reports false when the platform returns a null result', () async {
      mockPlatform((_) => null);
      expect(await service.isMusicActive(), isFalse);
    });
  });

  group('SystemAudioService audio focus', () {
    test('requestTransientFocus reports the grant from the platform', () async {
      mockPlatform((_) => true);
      expect(await service.requestTransientFocus(), isTrue);
      expect(calls.single.method, 'requestTransientFocus');
    });

    test('requestTransientFocus reports denial from the platform', () async {
      mockPlatform((_) => false);
      expect(await service.requestTransientFocus(), isFalse);
    });

    test('requestTransientFocus reports denial when the platform errors',
        () async {
      mockPlatform((_) => throw PlatformException(code: 'UNAVAILABLE'));
      expect(await service.requestTransientFocus(), isFalse);
    });

    test('abandonFocus invokes the platform', () async {
      mockPlatform((_) => null);
      await service.abandonFocus();
      expect(calls.single.method, 'abandonFocus');
    });

    test('abandonFocus swallows platform errors so release never throws',
        () async {
      mockPlatform((_) => throw PlatformException(code: 'UNAVAILABLE'));
      await expectLater(service.abandonFocus(), completes);
    });
  });
}
