import 'dart:math';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../database/database_helper.dart';
import '../../models/test_result.dart';
import '../../models/verse.dart';
import '../../services/speech_recognition_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/scoring.dart';
import 'test_enums.dart';
import 'test_result_screen.dart';

class TestSessionScreen extends StatefulWidget {
  const TestSessionScreen({
    super.key,
    required this.verses,
    required this.testMode,
    required this.selectedFormats,
    required this.selectedDirections,
  });

  final List<Verse> verses;
  final TestMode testMode;
  final Set<TestFormat> selectedFormats;
  final Set<PromptDirection> selectedDirections;

  @override
  State<TestSessionScreen> createState() => _TestSessionScreenState();
}

class _TestSessionScreenState extends State<TestSessionScreen> {
  int _currentIndex = 0;
  final List<VerseTestResult> _results = [];

  late final List<TestFormat> _verseFormats;
  late final List<PromptDirection> _verseDirections;

  // Type mode state
  final TextEditingController _typeController = TextEditingController();
  final FocusNode _checkFocusNode = FocusNode();
  bool _showingTypeResult = false;
  double? _lastTypeScore;

  // Fill-blank mode state
  List<TextEditingController> _blankControllers = [];
  List<FocusNode> _blankFocusNodes = [];
  final FocusNode _retryFocusNode = FocusNode();
  bool _showingBlankResult = false;
  double? _lastBlankScore;
  List<String> _currentBlankWords = [];
  List<int> _currentBlankIndices = [];
  List<bool> _blankCorrectness = [];

  // Recite mode voice state
  final SpeechRecognitionService _speechService = SpeechRecognitionService();
  bool _isListening = false;
  bool _micBusy = false;
  int? _listeningVerseIndex;
  bool _showingReciteScore = false;
  double? _lastReciteScore;
  String _micAnnouncement = '';

  TestFormat get _currentFormat => _verseFormats[_currentIndex];

  bool get _promptIsReference =>
      _verseDirections[_currentIndex] == PromptDirection.refToText;

  Verse get _currentVerse => widget.verses[_currentIndex];

  String get _promptText =>
      _promptIsReference ? _currentVerse.reference : _currentVerse.text;

  String get _answerText =>
      _promptIsReference ? _currentVerse.text : _currentVerse.reference;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    final formats = widget.selectedFormats.toList();
    final directions = widget.selectedDirections.toList();
    _verseFormats = List.generate(
      widget.verses.length,
      (_) => formats[rng.nextInt(formats.length)],
    );
    _verseDirections = List.generate(
      widget.verses.length,
      (_) => directions[rng.nextInt(directions.length)],
    );
    _initBlankState();
  }

  void _initBlankState() {
    _currentBlankWords = _answerText.split(' ');
    _currentBlankIndices = blankIndices(_currentBlankWords);
    _blankCorrectness = [];
    _blankControllers = List.generate(
      _currentBlankIndices.length,
      (_) => TextEditingController(),
    );
    _blankFocusNodes = List.generate(
      _currentBlankIndices.length,
      (_) => FocusNode(),
    );
  }

  void _disposeBlankControllers() {
    for (final c in _blankControllers) {
      c.dispose();
    }
    for (final f in _blankFocusNodes) {
      f.dispose();
    }
  }

  @override
  void dispose() {
    _typeController.dispose();
    _checkFocusNode.dispose();
    _retryFocusNode.dispose();
    _disposeBlankControllers();
    _speechService.dispose();
    super.dispose();
  }

  Future<void> _recordAndAdvance(double accuracy) async {
    if (_isListening) {
      _isListening = false;
      _listeningVerseIndex = null;
      await _speechService.cancel();
      if (!mounted) return;
    }

    final result = VerseTestResult(
      verseId: _currentVerse.id,
      accuracy: accuracy,
      testMode: widget.testMode.name,
      testFormat: _currentFormat.name,
      testedAt: DateTime.now(),
    );
    _results.add(result);

    if (_currentIndex + 1 >= widget.verses.length) {
      _finishSession();
    } else {
      setState(() {
        _currentIndex++;
        _showingTypeResult = false;
        _lastTypeScore = null;
        _showingBlankResult = false;
        _lastBlankScore = null;
        _typeController.clear();
        _disposeBlankControllers();
        _initBlankState();
        _isListening = false;
        _listeningVerseIndex = null;
        _showingReciteScore = false;
        _lastReciteScore = null;
        _micAnnouncement = '';
      });
    }
  }

  Future<void> _finishSession() async {
    await DatabaseHelper().logEngagement('test_complete');

    final sessionResult = TestSessionResult(
      verseResults: List.unmodifiable(_results),
      sessionAt: DateTime.now(),
    );

    if (mounted) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TestResultScreen(sessionResult: sessionResult),
        ),
      );
    }
  }

  void _onReciteKnew() => _recordAndAdvance(1.0);
  void _onReciteDidntKnow() => _recordAndAdvance(0.0);

  Future<void> _onMicPressed() async {
    if (_isListening) {
      await _speechService.stopListening();
      if (mounted) {
        setState(() {
          _isListening = false;
          _listeningVerseIndex = null;
          _micAnnouncement = '';
        });
      }
      return;
    }

    if (_micBusy) return;
    _micBusy = true;

    final permission = await _speechService.requestPermission();
    if (!mounted) {
      _micBusy = false;
      return;
    }
    if (permission == MicPermissionResult.permanentlyDenied) {
      setState(() => _micAnnouncement =
          'Microphone permission denied. You can still self-rate below.');
      await _showMicSettingsDialog();
      _micBusy = false;
      return;
    }
    if (permission != MicPermissionResult.granted) {
      setState(() => _micAnnouncement =
          'Microphone permission denied. You can still self-rate below.');
      _micBusy = false;
      return;
    }

    final verseIndex = _currentIndex;
    setState(() {
      _isListening = true;
      _listeningVerseIndex = verseIndex;
      _showingReciteScore = false;
      _lastReciteScore = null;
      _micAnnouncement = 'Listening';
    });

    final started = await _speechService.listen(
      onTranscript: (transcript, isFinal) {
        if (!mounted || !isFinal || _listeningVerseIndex != verseIndex) {
          return;
        }
        _onReciteTranscriptFinal(transcript, verseIndex);
      },
      onStopped: () {
        if (!mounted || _listeningVerseIndex != verseIndex) return;
        setState(() {
          _isListening = false;
          _listeningVerseIndex = null;
          if (!_showingReciteScore) {
            _micAnnouncement =
                'No speech recognized. Try again, or self-rate below.';
          }
        });
      },
    );

    _micBusy = false;
    if (!started && mounted) {
      setState(() {
        _isListening = false;
        _listeningVerseIndex = null;
        _micAnnouncement = 'On-device speech recognition is unavailable';
      });
    }
  }

  Future<void> _showMicSettingsDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone access needed'),
        content: const Text(
          'To recite aloud, allow microphone access in system settings. '
          'You can still self-rate with "I knew it" / "Didn\'t know" instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _onReciteTranscriptFinal(String transcript, int verseIndex) {
    // _answerText reflects the verse at verseIndex since the caller already
    // confirmed _listeningVerseIndex == verseIndex == _currentIndex.
    final score = computeScore(transcript, _answerText);
    // Transcript is discarded immediately after scoring; never persisted.
    setState(() {
      _isListening = false;
      _listeningVerseIndex = null;
      _showingReciteScore = true;
      _lastReciteScore = score;
      // No separate "Done listening" announcement here — _ScoreReveal's own
      // liveRegion announces the result, avoiding a double SR announcement.
      _micAnnouncement = '';
    });
  }

  Future<void> _onTypeCheck() async {
    final score = computeScore(_typeController.text, _answerText);
    _typeController.clear(); // discard typed input immediately

    setState(() {
      _showingTypeResult = true;
      _lastTypeScore = score;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      _checkFocusNode.requestFocus();
      _recordAndAdvance(score);
    }
  }

  void _onBlankCheck() {
    final correctness = <bool>[];
    var correctCount = 0;
    for (var i = 0; i < _currentBlankIndices.length; i++) {
      final wordIndex = _currentBlankIndices[i];
      final correct = _currentBlankWords[wordIndex]
          .toLowerCase()
          .replaceAll(RegExp(r"[^\w\s']"), '');
      final given = _blankControllers[i]
          .text
          .toLowerCase()
          .replaceAll(RegExp(r"[^\w\s']"), '');
      final isCorrect = given.trim() == correct.trim();
      correctness.add(isCorrect);
      if (isCorrect) correctCount++;
      _blankControllers[i].clear(); // discard typed input immediately
    }

    final total = _currentBlankIndices.length;
    final score = total > 0 ? correctCount / total : 1.0;

    setState(() {
      _blankCorrectness = correctness;
      _showingBlankResult = true;
      _lastBlankScore = score;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _retryFocusNode.requestFocus();
    });
  }

  void _onBlankRetry() {
    setState(() {
      _blankCorrectness = [];
      _showingBlankResult = false;
      _lastBlankScore = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _blankFocusNodes.isNotEmpty) {
        _blankFocusNodes.first.requestFocus();
      }
    });
  }

  void _onBlankContinue(double score) => _recordAndAdvance(score);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final total = widget.verses.length;
    final progress = _currentIndex / total;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress bar row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label:
                          'Test progress: verse ${_currentIndex + 1} of $total',
                      value: '${(progress * 100).round()}%',
                      child: ClipRRect(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(50)),
                        child: SizedBox(
                          height: 6,
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: cs.primaryContainer,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(cs.primary),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'End test',
                    child: Semantics(
                      label: 'End test',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(
                'Verse ${_currentIndex + 1} of $total',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            // Prompt card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _PromptCard(
                text: _promptText,
                isReference: _promptIsReference,
              ),
            ),
            const SizedBox(height: 24),
            // Answer area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildAnswerArea(cs, tt),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerArea(ColorScheme cs, TextTheme tt) {
    return switch (_currentFormat) {
      TestFormat.recite => _buildReciteArea(cs),
      TestFormat.type => _buildTypeArea(cs, tt),
      TestFormat.fillBlank => _buildFillBlankArea(cs, tt),
    };
  }

  Widget _buildReciteArea(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_showingReciteScore && _lastReciteScore != null) ...[
          _ScoreReveal(score: _lastReciteScore!, cs: cs),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: () => _recordAndAdvance(_lastReciteScore!),
              child: const Text('Continue'),
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor:
                    _isListening ? cs.primary : cs.primaryContainer,
                foregroundColor:
                    _isListening ? cs.onPrimary : cs.onPrimaryContainer,
              ),
              icon: Icon(
                _isListening ? Symbols.mic_rounded : Symbols.mic_none_rounded,
              ),
              label: Text(_isListening ? 'Listening…' : 'Recite aloud'),
              onPressed: _onMicPressed,
            ),
          ),
          if (_micAnnouncement.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _micAnnouncement,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.success,
                    foregroundColor: cs.onPrimary,
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('I knew it'),
                  onPressed: _onReciteKnew,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                  ),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text("Didn't know"),
                  onPressed: _onReciteDidntKnow,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeArea(ColorScheme cs, TextTheme tt) {
    final isVerseInput = _promptIsReference;
    final labelText = isVerseInput ? 'Type the verse' : 'Type the reference';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _typeController,
          decoration: InputDecoration(labelText: labelText),
          maxLines: isVerseInput ? null : 1,
          keyboardType:
              isVerseInput ? TextInputType.multiline : TextInputType.text,
          style: isVerseInput ? tt.headlineSmall : tt.titleMedium,
          textCapitalization: TextCapitalization.sentences,
          enabled: !_showingTypeResult,
        ),
        const SizedBox(height: 16),
        if (_showingTypeResult && _lastTypeScore != null)
          _ScoreReveal(score: _lastTypeScore!, cs: cs),
        if (!_showingTypeResult)
          SizedBox(
            height: 48,
            child: FilledButton(
              focusNode: _checkFocusNode,
              onPressed: _onTypeCheck,
              child: const Text('Check Answer'),
            ),
          ),
      ],
    );
  }

  Widget _buildFillBlankArea(ColorScheme cs, TextTheme tt) {
    final spans = <Widget>[];
    for (var i = 0; i < _currentBlankWords.length; i++) {
      final blankIdx = _currentBlankIndices.indexOf(i);
      if (blankIdx >= 0) {
        final isCorrect = _blankCorrectness.length > blankIdx
            ? _blankCorrectness[blankIdx]
            : null;
        spans.add(
          SizedBox(
            width: 90,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isCorrect == null
                    ? Colors.transparent
                    : isCorrect
                        ? cs.successContainer
                        : cs.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _blankControllers[blankIdx],
                focusNode: _blankFocusNodes[blankIdx],
                decoration: InputDecoration(
                  labelText: 'Blank ${blankIdx + 1}',
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  errorText: (isCorrect == false) ? 'Incorrect' : null,
                  suffixIcon: isCorrect == false
                      ? Icon(Icons.close, color: cs.onErrorContainer, size: 16)
                      : isCorrect == true
                          ? Icon(Icons.check,
                              color: cs.onSuccessContainer, size: 16)
                          : null,
                ),
                style: tt.bodyLarge,
                enabled: !_showingBlankResult,
                textCapitalization: TextCapitalization.none,
              ),
            ),
          ),
        );
      } else {
        spans.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Text(
              _currentBlankWords[i],
              style: tt.bodyLarge,
            ),
          ),
        );
      }
      spans.add(const SizedBox(width: 4));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: spans,
        ),
        const SizedBox(height: 20),
        if (_showingBlankResult && _lastBlankScore != null) ...[
          _ScoreReveal(score: _lastBlankScore!, cs: cs),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    focusNode: _retryFocusNode,
                    onPressed: _onBlankRetry,
                    child: const Text('Try Again'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: () => _onBlankContinue(_lastBlankScore!),
                    child: const Text('Continue'),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (!_showingBlankResult)
          SizedBox(
            height: 48,
            child: FilledButton(
              focusNode: _checkFocusNode,
              onPressed: _onBlankCheck,
              child: const Text('Check Answer'),
            ),
          ),
      ],
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.text, required this.isReference});

  final String text;
  final bool isReference;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Semantics(
      label: isReference
          ? 'Prompt: reference — $text'
          : 'Prompt: verse text — $text',
      child: Container(
        constraints: const BoxConstraints(minHeight: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.tertiaryContainer,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: Center(
          child: Text(
            text,
            style: isReference
                ? tt.titleMedium?.copyWith(color: cs.onTertiaryContainer)
                : tt.headlineMedium?.copyWith(color: cs.onTertiaryContainer),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _ScoreReveal extends StatelessWidget {
  const _ScoreReveal({required this.score, required this.cs});

  final double score;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final pct = (score * 100).round();
    final Color bg;
    final Color fg;
    final IconData icon;
    if (score >= 0.9) {
      bg = cs.successContainer;
      fg = cs.onSuccessContainer;
      icon = Icons.check_circle_rounded;
    } else if (score >= 0.7) {
      bg = cs.warningContainer;
      fg = cs.onWarningContainer;
      icon = Icons.warning_amber_rounded;
    } else {
      bg = cs.errorContainer;
      fg = cs.onErrorContainer;
      icon = Icons.cancel_rounded;
    }

    return Semantics(
      liveRegion: true,
      label: 'Score: $pct%',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: 8),
            Text(
              '$pct%',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w400,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
