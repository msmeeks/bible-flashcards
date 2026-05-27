import 'package:flutter/material.dart';

import '../../models/test_result.dart';
import '../../models/verse.dart';
import '../../theme/app_colors.dart';
import 'test_enums.dart';
import 'test_result_screen.dart';

/// Computes a 0.0–1.0 similarity score using word-level LCS.
/// The typed input is consumed here and not returned or stored.
double _computeScore(String typed, String correct) {
  String normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r"[^\w\s']"), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  final typedWords =
      normalize(typed).split(' ').where((w) => w.isNotEmpty).toList();
  final correctWords =
      normalize(correct).split(' ').where((w) => w.isNotEmpty).toList();

  if (typedWords.isEmpty && correctWords.isEmpty) return 1.0;
  if (typedWords.isEmpty || correctWords.isEmpty) return 0.0;

  // LCS dynamic programming
  final m = typedWords.length;
  final n = correctWords.length;
  final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      if (typedWords[i - 1] == correctWords[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else {
        dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
      }
    }
  }
  final lcs = dp[m][n];
  final maxLen = m > n ? m : n;
  return lcs / maxLen;
}

/// Determines which word indices in [words] should be blanks,
/// selecting approximately every 3rd–5th word.
List<int> _blankIndices(List<String> words) {
  final indices = <int>[];
  var step = 3;
  var nextBlank = step - 1;
  for (var i = 0; i < words.length; i++) {
    if (i == nextBlank) {
      indices.add(i);
      // Cycle step through 3, 4, 5
      step = 3 + (indices.length % 3);
      nextBlank = i + step;
    }
  }
  return indices;
}

class TestSessionScreen extends StatefulWidget {
  const TestSessionScreen({
    super.key,
    required this.verses,
    required this.testMode,
    required this.testFormat,
    required this.promptDirection,
  });

  final List<Verse> verses;
  final TestMode testMode;
  final TestFormat testFormat;
  final PromptDirection promptDirection;

  @override
  State<TestSessionScreen> createState() => _TestSessionScreenState();
}

class _TestSessionScreenState extends State<TestSessionScreen> {
  int _currentIndex = 0;
  final List<VerseTestResult> _results = [];

  // Type mode state
  final TextEditingController _typeController = TextEditingController();
  final FocusNode _checkFocusNode = FocusNode();
  bool _showingTypeResult = false;
  double? _lastTypeScore;

  // Fill-blank mode state
  List<TextEditingController> _blankControllers = [];
  List<FocusNode> _blankFocusNodes = [];
  bool _showingBlankResult = false;
  double? _lastBlankScore;
  List<String> _currentBlankWords = [];
  List<int> _currentBlankIndices = [];

  Verse get _currentVerse => widget.verses[_currentIndex];

  bool get _promptIsReference =>
      widget.promptDirection == PromptDirection.refToText;

  String get _promptText =>
      _promptIsReference ? _currentVerse.reference : _currentVerse.text;

  String get _answerText =>
      _promptIsReference ? _currentVerse.text : _currentVerse.reference;

  @override
  void initState() {
    super.initState();
    _initBlankState();
  }

  void _initBlankState() {
    _currentBlankWords = _answerText.split(' ');
    _currentBlankIndices = _blankIndices(_currentBlankWords);
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
    _disposeBlankControllers();
    super.dispose();
  }

  void _recordAndAdvance(double accuracy) {
    final result = VerseTestResult(
      verseId: _currentVerse.id,
      accuracy: accuracy,
      testMode: widget.testMode.name,
      testFormat: widget.testFormat.name,
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
      });
    }
  }

  Future<void> _finishSession() async {
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

  Future<void> _onTypeCheck() async {
    final score = _computeScore(_typeController.text, _answerText);
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

  Future<void> _onBlankCheck() async {
    var correctCount = 0;
    for (var i = 0; i < _currentBlankIndices.length; i++) {
      final wordIndex = _currentBlankIndices[i];
      final correct = _currentBlankWords[wordIndex]
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w]'), '');
      final given = _blankControllers[i]
          .text
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w]'), '');
      if (given == correct) correctCount++;
      _blankControllers[i].clear(); // discard typed input immediately
    }

    final total = _currentBlankIndices.length;
    final score = total > 0 ? correctCount / total : 1.0;

    setState(() {
      _showingBlankResult = true;
      _lastBlankScore = score;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      _checkFocusNode.requestFocus();
      _recordAndAdvance(score);
    }
  }

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
    return switch (widget.testFormat) {
      TestFormat.recite => _buildReciteArea(cs),
      TestFormat.type => _buildTypeArea(cs, tt),
      TestFormat.fillBlank => _buildFillBlankArea(cs, tt),
    };
  }

  Widget _buildReciteArea(ColorScheme cs) {
    return Row(
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
    );
  }

  Widget _buildTypeArea(ColorScheme cs, TextTheme tt) {
    final isVerseInput = _promptIsReference;
    final labelText =
        isVerseInput ? 'Type the verse' : 'Type the reference';

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
        spans.add(
          SizedBox(
            width: 80,
            child: TextField(
              controller: _blankControllers[blankIdx],
              focusNode: _blankFocusNodes[blankIdx],
              decoration: InputDecoration(
                labelText: 'Blank ${blankIdx + 1} of ${_currentBlankIndices.length}',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              style: tt.bodyLarge,
              enabled: !_showingBlankResult,
              textCapitalization: TextCapitalization.none,
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
        if (_showingBlankResult && _lastBlankScore != null)
          _ScoreReveal(score: _lastBlankScore!, cs: cs),
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
      label: isReference ? 'Prompt: reference — $text' : 'Prompt: verse text — $text',
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
