import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/verse.dart';
import 'esv_audio_cache_service.dart';

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
  AudioService({EsvAudioCacheService? esvAudio})
      : _tts = FlutterTts(),
        _esvAudio = esvAudio ?? EsvAudioCacheService();

  final FlutterTts _tts;
  final EsvAudioCacheService _esvAudio;
  AudioPlayer? _activePlayer;
  Completer<void>? _playerCompleter;
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

    _pausedVerse = verse;
    await _runFromPhase(_PlayPhase.reference, verse);
  }

  /// Stops all playback immediately.
  Future<void> stop() async {
    _isStopped = true;
    _pausedPhase = _PlayPhase.none;
    _pausedVerse = null;
    await _stopActivePlayer();
    await _tts.stop();
    _emit(AudioPlaybackState.idle);
  }

  /// Pauses playback. Stops TTS/audio and records phase for [resume].
  Future<void> pause() async {
    // Stopping playback will cause the _speakAndWait/_playMp3AndWait
    // completer to resolve early. _isStopped stays false so resume can
    // continue.
    await _stopActivePlayer();
    await _tts.stop();
  }

  /// Resumes from the recorded pause phase.
  Future<void> resume() async {
    final verse = _pausedVerse;
    if (verse == null || _pausedPhase == _PlayPhase.none) return;
    await _runFromPhase(_pausedPhase, verse);
  }

  /// Runs the reference → pause → text sequence starting at [startPhase],
  /// skipping any phases before it. Shared by [playVerse] (always starts at
  /// [_PlayPhase.reference]) and [resume] (starts at the recorded phase).
  Future<void> _runFromPhase(_PlayPhase startPhase, Verse verse) async {
    if (startPhase == _PlayPhase.reference) {
      _emit(AudioPlaybackState.speakingReference);
      _pausedPhase = _PlayPhase.reference;
      await _speakAndWait(verse.reference);
      if (_isStopped) return;
    }

    if (startPhase == _PlayPhase.reference || startPhase == _PlayPhase.pause) {
      _emit(AudioPlaybackState.pausing);
      _pausedPhase = _PlayPhase.pause;
      final pauseDuration = _estimatePauseDuration(verse.text);
      await Future<void>.delayed(pauseDuration);
      if (_isStopped) return;
    }

    _emit(AudioPlaybackState.speakingText);
    _pausedPhase = _PlayPhase.text;
    await _speakTextPhase(verse);
    if (_isStopped) return;

    _pausedPhase = _PlayPhase.none;
    _pausedVerse = null;
    _emit(AudioPlaybackState.completed);
  }

  void dispose() {
    _isStopped = true;
    _activePlayer?.dispose();
    _tts.stop();
    _stateController.close();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Plays the text phase: real ESV recording when available, TTS otherwise.
  /// Cache/network failures fall back to TTS silently — no error shown.
  Future<void> _speakTextPhase(Verse verse) async {
    if (verse.translation == 'ESV') {
      try {
        final audioPath = await _esvAudio.getAudioPath(verse.reference);
        if (_isStopped) return;
        await _playMp3AndWait(audioPath);
        return;
      } catch (_) {
        if (_isStopped) return;
      }
    }
    await _speakAndWait(verse.text);
  }

  Future<void> _playMp3AndWait(String path) async {
    final player = AudioPlayer();
    _activePlayer = player;
    final completer = Completer<void>();
    _playerCompleter = completer;
    final subscription = player.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });
    try {
      await player.play(DeviceFileSource(path));
      await completer.future;
    } finally {
      await subscription.cancel();
      if (identical(_activePlayer, player)) _activePlayer = null;
      if (identical(_playerCompleter, completer)) _playerCompleter = null;
      await player.dispose();
    }
  }

  Future<void> _stopActivePlayer() async {
    final player = _activePlayer;
    if (player == null) return;
    _activePlayer = null;
    await player.stop();
    // stop() does not fire onPlayerComplete — resolve manually so any
    // pending _playMp3AndWait await (from pause()/stop()) completes.
    final completer = _playerCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

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
