import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/verse.dart';

/// State provider for audio playback.
/// Full playback implementation is handled by the audio feature agent.
class AudioProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;
  Verse? _currentVerse;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool get isPlaying => _isPlaying;
  Verse? get currentVerse => _currentVerse;
  Duration get position => _position;
  Duration get duration => _duration;

  // ---------------------------------------------------------------------------
  // Stubs — audio feature agent implements these
  // ---------------------------------------------------------------------------

  /// Begins playback of [verse] text-to-speech audio.
  Future<void> playVerse(Verse verse) async {
    // TODO(audio-agent): implement TTS loading and playback via AudioService
    _currentVerse = verse;
    _isPlaying = true;
    notifyListeners();
  }

  Future<void> pause() async {
    // TODO(audio-agent): implement pause
    await _player.pause();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> resume() async {
    // TODO(audio-agent): implement resume
    await _player.play();
    _isPlaying = true;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    // TODO(audio-agent): implement seek
    await _player.seek(position);
    _position = position;
    notifyListeners();
  }

  Future<void> stop() async {
    // TODO(audio-agent): implement stop
    await _player.stop();
    _isPlaying = false;
    _currentVerse = null;
    _position = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
