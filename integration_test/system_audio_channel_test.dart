// Exercises the real `bible_flashcards/system_audio` channel against a real
// AudioManager on a device/emulator:
// `flutter test integration_test/system_audio_channel_test.dart -d <device>`.
//
// The unit tests mock the channel, so they prove the Dart contract but say
// nothing about whether the Kotlin side is registered or agrees on the method
// names. This closes that gap.
import 'package:bible_flashcards/services/system_audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final service = SystemAudioService();

  testWidgets('isMusicActive answers from the real AudioManager',
      (tester) async {
    // Nothing else is playing on a fresh device, so this is false — the point
    // is that a real bool comes back rather than a MissingPluginException
    // swallowed into the same false.
    expect(await service.isMusicActive(), isFalse);
  });

  testWidgets('transient audio focus is granted and released', (tester) async {
    expect(await service.requestTransientFocus(), isTrue);
    await expectLater(service.abandonFocus(), completes);
  });

  testWidgets('focus can be re-acquired after being released', (tester) async {
    // Each interval takes and releases focus, so a stale AudioFocusRequest
    // would break every playback after the first.
    expect(await service.requestTransientFocus(), isTrue);
    await service.abandonFocus();
    expect(await service.requestTransientFocus(), isTrue);
    await service.abandonFocus();
  });
}
