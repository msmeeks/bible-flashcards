import 'package:flutter/services.dart';

/// Dart side of the system-audio platform channel.
///
/// Wraps the two Android capabilities periodic verse playback needs: asking
/// whether another app is currently playing audio, and holding transient audio
/// focus so that app ducks while a verse plays and resumes afterwards.
class SystemAudioService {
  static const MethodChannel channel =
      MethodChannel('bible_flashcards/system_audio');

  /// Whether another app is currently playing audio.
  ///
  /// Fails closed: if the platform is unreachable we report "no other audio",
  /// which skips the interval rather than talking over the user.
  Future<bool> isMusicActive() async {
    try {
      return await channel.invokeMethod<bool>('isMusicActive') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Requests transient audio focus so other audio ducks while a verse plays.
  ///
  /// Returns whether focus was granted. A denial means something with a
  /// stronger claim holds it (a call, say), so callers should stay silent.
  Future<bool> requestTransientFocus() async {
    try {
      return await channel.invokeMethod<bool>('requestTransientFocus') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Releases audio focus so the other app resumes. Never throws — a failed
  /// release must not take down the caller's playback path.
  Future<void> abandonFocus() async {
    try {
      await channel.invokeMethod<void>('abandonFocus');
    } on PlatformException {
      // Nothing useful to do; focus is reclaimed by the OS on process death.
    } on MissingPluginException {
      // Channel absent (e.g. non-Android host) — nothing to release.
    }
  }
}
