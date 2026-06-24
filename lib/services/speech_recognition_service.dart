import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum MicPermissionResult { granted, denied, permanentlyDenied }

/// Wraps on-device speech-to-text for recite-mode testing.
///
/// Recognition is forced on-device (`onDevice: true`): if the platform
/// cannot recognize locally, the listen attempt fails outright rather than
/// falling back to a cloud recognizer. Transcripts are never persisted or
/// logged by this service — callers must discard them after scoring.
class SpeechRecognitionService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;

  // Reassigned on every listen() call; the onStatus/onError listeners below
  // are only registered once (at first initialize), so they must always
  // dispatch to whichever caller is currently listening.
  void Function()? _onStopped;

  bool get isListening => _speech.isListening;

  Future<MicPermissionResult> requestPermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return MicPermissionResult.granted;
    if (status.isPermanentlyDenied) {
      return MicPermissionResult.permanentlyDenied;
    }
    return MicPermissionResult.denied;
  }

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      debugLogging: false,
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') _onStopped?.call();
      },
      onError: (error) => _onStopped?.call(),
    );
    return _initialized;
  }

  /// Starts listening. Callers must call [requestPermission] first and
  /// only proceed on [MicPermissionResult.granted] — this keeps permission
  /// denial handling (e.g. routing to app settings) in the UI layer.
  /// Returns false if the recognizer can't be initialized, or if the
  /// platform can't honor on-device-only recognition.
  ///
  /// [onStopped] fires whenever the recognizer stops listening on its own
  /// (timeout, no speech detected, or error) so the caller can reset any
  /// "listening" UI state even when no final transcript ever arrives.
  Future<bool> listen({
    required void Function(String transcript, bool isFinal) onTranscript,
    required void Function() onStopped,
  }) async {
    _onStopped = onStopped;
    final ready = await _ensureInitialized();
    if (!ready) return false;

    await _speech.listen(
      onResult: (result) =>
          onTranscript(result.recognizedWords, result.finalResult),
      listenOptions: SpeechListenOptions(
        onDevice: true,
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
    );
    return true;
  }

  Future<void> stopListening() {
    _onStopped = null;
    return _speech.stop();
  }

  Future<void> cancel() {
    _onStopped = null;
    return _speech.cancel();
  }

  void dispose() {
    _onStopped = null;
    _speech.cancel();
  }
}
