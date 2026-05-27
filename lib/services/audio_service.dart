import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import '../models/verse.dart';

/// Playback state emitted by [AudioService.playbackStateStream].
enum AudioPlaybackState {
  idle,
  speakingReference,
  pausing,
  speakingText,
  completed,
  error,
}

/// Text-to-speech playback service using [flutter_tts].
///
/// Playback sequence per verse: speak reference → pause for text duration →
/// speak text → emit [AudioPlaybackState.completed].
///
/// [flutter_tts] has no native pause; pause is simulated by stopping and
/// re-queuing the remaining text segment.
class AudioService {
  AudioService() : _tts = FlutterTts();

  final FlutterTts _tts;
  bool _initialized = false;

  final StreamController<AudioPlaybackState> _stateController =
      StreamController<AudioPlaybackState>.broadcast();

  AudioPlaybackState _state = AudioPlaybackState.idle;
  AudioPlaybackState get state => _state;

  Stream<AudioPlaybackState> get playbackStateStream => _stateController.stream;

  _PlayPhase _pausedPhase = _PlayPhase.none;
  Verse? _pausedVerse;
  bool _isStopped = false;

  // Single completer for the current utterance — replaced atomically on each speak call.
  Completer<void>? _utteranceCompleter;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.85);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    // Register handlers once so they are never replaced mid-utterance.
    _tts.setCompletionHandler(() => _utteranceCompleter?.complete());
    _tts.setCancelHandler(() => _utteranceCompleter?.complete());
    _tts.setErrorHandler((dynamic _) {
      _emit(AudioPlaybackState.error);
      _utteranceCompleter?.complete();
    });
    _initialized = true;
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Plays [verse]: speaks the reference, pauses, then speaks the text.
  Future<void> playVerse(Verse verse) async {
    _isStopped = false;
    await _ensureInitialized();
    await _tts.stop();

    _emit(AudioPlaybackState.speakingReference);
    _pausedVerse = verse;
    _pausedPhase = _PlayPhase.reference;

    await _speakAndWait(verse.reference);
    if (_isStopped) return;

    _emit(AudioPlaybackState.pausing);
    _pausedPhase = _PlayPhase.pause;

    final pauseDuration = _estimatePauseDuration(verse.text);
    await Future<void>.delayed(pauseDuration);
    if (_isStopped) return;

    _emit(AudioPlaybackState.speakingText);
    _pausedPhase = _PlayPhase.text;

    await _speakAndWait(verse.text);
    if (_isStopped) return;

    _pausedPhase = _PlayPhase.none;
    _pausedVerse = null;
    _emit(AudioPlaybackState.completed);
  }

  /// Stops all playback immediately.
  Future<void> stop() async {
    _isStopped = true;
    _pausedPhase = _PlayPhase.none;
    _pausedVerse = null;
    await _tts.stop();
    _emit(AudioPlaybackState.idle);
  }

  /// Pauses playback. Stops TTS and records phase for [resume].
  Future<void> pause() async {
    // Stopping TTS will cause the _speakAndWait completer to resolve early.
    // _isStopped stays false so resume can continue.
    await _tts.stop();
  }

  /// Resumes from the recorded pause phase.
  Future<void> resume() async {
    final verse = _pausedVerse;
    if (verse == null) return;

    switch (_pausedPhase) {
      case _PlayPhase.reference:
        _emit(AudioPlaybackState.speakingReference);
        await _speakAndWait(verse.reference);
        if (_isStopped) return;
        _emit(AudioPlaybackState.pausing);
        _pausedPhase = _PlayPhase.pause;
        final pauseDuration = _estimatePauseDuration(verse.text);
        await Future<void>.delayed(pauseDuration);
        if (_isStopped) return;
        _emit(AudioPlaybackState.speakingText);
        _pausedPhase = _PlayPhase.text;
        await _speakAndWait(verse.text);
        if (_isStopped) return;
        _pausedPhase = _PlayPhase.none;
        _pausedVerse = null;
        _emit(AudioPlaybackState.completed);

      case _PlayPhase.pause:
        _emit(AudioPlaybackState.pausing);
        _pausedPhase = _PlayPhase.pause;
        final pauseDuration = _estimatePauseDuration(verse.text);
        await Future<void>.delayed(pauseDuration);
        if (_isStopped) return;
        _emit(AudioPlaybackState.speakingText);
        _pausedPhase = _PlayPhase.text;
        await _speakAndWait(verse.text);
        if (_isStopped) return;
        _pausedPhase = _PlayPhase.none;
        _pausedVerse = null;
        _emit(AudioPlaybackState.completed);

      case _PlayPhase.text:
        _emit(AudioPlaybackState.speakingText);
        await _speakAndWait(verse.text);
        if (_isStopped) return;
        _pausedPhase = _PlayPhase.none;
        _pausedVerse = null;
        _emit(AudioPlaybackState.completed);

      case _PlayPhase.none:
        break;
    }
  }

  void dispose() {
    _isStopped = true;
    _tts.stop();
    _stateController.close();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _speakAndWait(String text) async {
    _utteranceCompleter = Completer<void>();
    await _tts.speak(text);
    await _utteranceCompleter!.future;
    _utteranceCompleter = null;
  }

  void _emit(AudioPlaybackState state) {
    _state = state;
    if (!_stateController.isClosed) _stateController.add(state);
  }

  /// Estimates a comfortable pause duration: ~100ms per character, min 2s.
  static Duration _estimatePauseDuration(String text) {
    final ms = (text.length * 100).clamp(2000, 15000);
    return Duration(milliseconds: ms);
  }
}

enum _PlayPhase { none, reference, pause, text }
