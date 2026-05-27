import '../models/verse.dart';

/// Handles TTS generation and audio file management for verse playback.
/// Full implementation by the audio feature agent.
class AudioService {
  /// Generates or retrieves cached TTS audio for [verse].
  /// Returns the local file path of the audio file.
  Future<String> prepareAudio(Verse verse) async {
    // TODO(audio-agent): implement TTS via flutter_tts or cached MP3 assets
    throw UnimplementedError('AudioService.prepareAudio');
  }

  /// Clears cached audio files for the given [verseIds].
  Future<void> clearCachedAudio(List<String> verseIds) async {
    // TODO(audio-agent): implement cache eviction
    throw UnimplementedError('AudioService.clearCachedAudio');
  }

  /// Returns true if cached audio exists for [verseId].
  Future<bool> hasCachedAudio(String verseId) async {
    // TODO(audio-agent): check filesystem for cached file
    throw UnimplementedError('AudioService.hasCachedAudio');
  }
}
