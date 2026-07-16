import 'dart:math';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../database/database_helper.dart';
import '../../models/test_result.dart';
import '../../models/verse.dart';
import '../../theme/app_colors.dart';
import '../../utils/scoring.dart';
import '../../widgets/esv_copyright_footer.dart';
import '../settings/settings_screen.dart';
import 'test_enums.dart';
import 'test_result_screen.dart';

class TestSessionScreen extends StatefulWidget {
  const TestSessionScreen({
    super.key,
    required this.verses,
    required this.testMode,
    required this.selectedFormats,
    required this.selectedDirections,
    this.blankDensity = BlankDensity.twenty,
    this.debugBlankIndices,
  });

  final List<Verse> verses;
  final TestMode testMode;
  final Set<TestFormat> selectedFormats;
  final Set<PromptDirection> selectedDirections;
  final BlankDensity blankDensity;

  // Lets tests force which fill-blank word indices get blanked instead of
  // the random selection; production code omits this (see _initBlankState).
  final List<int>? debugBlankIndices;

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
  final FocusNode _nextFocusNode = FocusNode();
  bool _showingTypeResult = false;
  double? _lastTypeScore;

  // Word-level alignment of the last checked answer (#162). Derived at check
  // time and held in memory only — it dies with this state, exactly like the
  // typed text it came from, and is never persisted or logged.
  List<DiffToken>? _lastTypeDiff;

  // Fill-blank mode state
  List<TextEditingController> _blankControllers = [];
  List<FocusNode> _blankFocusNodes = [];
  final FocusNode _retryFocusNode = FocusNode();
  bool _showingBlankResult = false;
  double? _lastBlankScore;
  List<String> _currentBlankWords = [];
  List<int> _currentBlankIndices = [];
  List<bool> _blankCorrectness = [];

  // Custom book-name variants for lenient reference-answer scoring (#30).
  Map<String, String> _customVariantLookup = const {};

  TestFormat get _currentFormat => _verseFormats[_currentIndex];

  bool get _promptIsReference =>
      _verseDirections[_currentIndex] == PromptDirection.refToText;

  Verse get _currentVerse => widget.verses[_currentIndex];

  String get _promptText =>
      _promptIsReference ? _currentVerse.reference : _currentVerse.text;

  String get _answerText =>
      _promptIsReference ? _currentVerse.text : _currentVerse.reference;

  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    final formats = widget.selectedFormats.toList();
    final directions = widget.selectedDirections.toList();
    _verseFormats = List.generate(
      widget.verses.length,
      (_) => formats[_rng.nextInt(formats.length)],
    );
    _verseDirections = List.generate(
      widget.verses.length,
      (_) => directions[_rng.nextInt(directions.length)],
    );
    _initBlankState();
    _loadCustomVariants();
  }

  Future<void> _loadCustomVariants() async {
    final lookup = await DatabaseHelper().getCustomVariantLookup();
    if (mounted) setState(() => _customVariantLookup = lookup);
  }

  /// The text [given] should actually be compared against [_answerText].
  /// When the answer is a reference (textToRef), a recognized book-name
  /// variant is rewritten to the correct wording first (#30). Both the score
  /// and the diff are derived from this, so they can never disagree — a
  /// forgiven "1 Thess" must not render as an extra word beside 100%.
  String _comparableAnswer(String given) => _promptIsReference
      ? given
      : canonicalizeReferenceAnswer(
          given,
          _answerText,
          customVariants: _customVariantLookup,
        );

  void _initBlankState() {
    _currentBlankWords = splitAnswerTokens(_answerText);
    final percentage = widget.blankDensity == BlankDensity.random
        ? BlankDensityLabel.fixedPercentages[
            _rng.nextInt(BlankDensityLabel.fixedPercentages.length)]
        : widget.blankDensity.percentage;
    final candidateCount = _currentBlankWords.where((w) => w != ':').length;
    final blankCount = blankCountForPercentage(candidateCount, percentage);
    _currentBlankIndices = widget.debugBlankIndices ??
        blankIndices(_currentBlankWords, blankCount, random: _rng);
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
    _nextFocusNode.dispose();
    _retryFocusNode.dispose();
    _disposeBlankControllers();
    super.dispose();
  }

  Future<void> _recordAndAdvance(double accuracy) async {
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
        _lastTypeDiff = null;
        _showingBlankResult = false;
        _lastBlankScore = null;
        _typeController.clear();
        _disposeBlankControllers();
        _initBlankState();
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

  void _onTypeCheck() {
    final comparable = _comparableAnswer(_typeController.text);
    final score = computeScore(comparable, _answerText);
    final diff = diffWords(comparable, _answerText);
    _typeController.clear(); // discard typed input immediately

    setState(() {
      _showingTypeResult = true;
      _lastTypeScore = score;
      _lastTypeDiff = diff;
    });

    // The score stays on screen until the user asks to move on (#166) —
    // there is no timer here. Focus the Next control so a keyboard/screen
    // reader user lands on the only forward action rather than the diff.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nextFocusNode.requestFocus();
    });
  }

  void _onTypeNext() {
    // Guard against a double-tap recording the same verse twice: the first
    // tap flips this false, and the control only renders while it's true.
    if (!_showingTypeResult || _lastTypeScore == null) return;
    final score = _lastTypeScore!;
    setState(() => _showingTypeResult = false);
    _recordAndAdvance(score);
  }

  void _onBlankCheck() {
    final bookNameCorrectness = _promptIsReference
        ? const <int, bool>{}
        : scoreBlankedBookNameTokens(
            _answerText,
            _currentBlankWords,
            {
              for (var i = 0; i < _currentBlankIndices.length; i++)
                _currentBlankIndices[i]: _blankControllers[i].text,
            },
            customVariants: _customVariantLookup,
          );

    final correctness = <bool>[];
    var correctCount = 0;
    for (var i = 0; i < _currentBlankIndices.length; i++) {
      final wordIndex = _currentBlankIndices[i];
      bool isCorrect;
      if (bookNameCorrectness.containsKey(wordIndex)) {
        isCorrect = bookNameCorrectness[wordIndex]!;
      } else {
        // Same normalization as Type-mode scoring, so an omitted or curly
        // apostrophe is forgiven identically in both modes (#161).
        final correct = normalizeWords(_currentBlankWords[wordIndex]).join(' ');
        final given = normalizeWords(_blankControllers[i].text).join(' ');
        isCorrect = given == correct;
      }
      correctness.add(isCorrect);
      if (isCorrect) correctCount++;
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
    for (final controller in _blankControllers) {
      controller.clear();
    }
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
                        icon: const Icon(Symbols.close_rounded),
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
            EsvCopyrightFooter(
              hasEsvContent: _currentVerse.translation == 'ESV',
              onViewFullTerms: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerArea(ColorScheme cs, TextTheme tt) {
    return switch (_currentFormat) {
      TestFormat.type => _buildTypeArea(cs, tt),
      TestFormat.fillBlank => _buildFillBlankArea(cs, tt),
    };
  }

  Widget _buildTypeArea(ColorScheme cs, TextTheme tt) {
    final isVerseInput = _promptIsReference;
    final labelText = isVerseInput ? 'Type the verse' : 'Type the reference';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('type-answer-field'),
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
        if (_showingTypeResult && _lastTypeScore != null) ...[
          _ScoreReveal(score: _lastTypeScore!, cs: cs),
          if (_lastTypeDiff != null) ...[
            _AnswerDiff(tokens: _lastTypeDiff!),
            const SizedBox(height: 16),
          ],
          SizedBox(
            height: 48,
            child: FilledButton(
              key: const Key('type-next-button'),
              focusNode: _nextFocusNode,
              onPressed: _onTypeNext,
              child: const Text('Next'),
            ),
          ),
        ],
        if (!_showingTypeResult)
          SizedBox(
            height: 48,
            child: FilledButton(
              key: const Key('type-check-button'),
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
              child: Semantics(
                label:
                    'Blank ${blankIdx + 1} of ${_currentBlankIndices.length}',
                textField: true,
                child: TextField(
                  controller: _blankControllers[blankIdx],
                  focusNode: _blankFocusNodes[blankIdx],
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    errorText:
                        (isCorrect == false) ? _currentBlankWords[i] : null,
                    errorStyle: TextStyle(color: cs.onErrorContainer),
                    errorMaxLines: 2,
                    suffixIcon: isCorrect == false
                        ? Semantics(
                            label: 'Incorrect',
                            child: Icon(Symbols.cancel_rounded,
                                color: cs.onErrorContainer, size: 16),
                          )
                        : isCorrect == true
                            ? Semantics(
                                label: 'Correct',
                                child: Icon(Symbols.check_circle_rounded,
                                    color: cs.onSuccessContainer, size: 16),
                              )
                            : null,
                  ),
                  style: tt.bodyLarge,
                  enabled: !_showingBlankResult,
                  textCapitalization: TextCapitalization.none,
                ),
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
      final isColon = _currentBlankWords[i] == ':';
      final nextIsColon =
          i + 1 < _currentBlankWords.length && _currentBlankWords[i + 1] == ':';
      if (!isColon && !nextIsColon) {
        spans.add(const SizedBox(width: 4));
      }
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

/// Renders a [diffWords] alignment of the user's answer against the source
/// (#162). Every state carries a non-colour cue as well as a colour —
/// strikethrough for a missed word, underline for an extra one — and a
/// `Semantics` label, so nothing here is conveyed by colour alone.
class _AnswerDiff extends StatelessWidget {
  const _AnswerDiff({required this.tokens});

  final List<DiffToken> tokens;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final missed = tokens.where((t) => t.op == DiffOp.delete).length;
    final extra = tokens.where((t) => t.op == DiffOp.insert).length;

    return Column(
      key: const Key('type-answer-diff'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 2,
          children: [
            // Keys carry the token's position: verses repeat words constantly
            // ("the", "is"), and a word-only key throws "Duplicate keys found"
            // and blanks the whole answer area.
            for (final (i, token) in tokens.indexed)
              switch (token.op) {
                DiffOp.match => Text(
                    token.word,
                    key: Key('diff-$i-match-${token.word}'),
                    style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                  ),
                DiffOp.delete => Semantics(
                    label: 'Missing word: ${token.word}',
                    excludeSemantics: true,
                    child: Text(
                      token.word,
                      key: Key('diff-$i-delete-${token.word}'),
                      style: tt.bodyLarge?.copyWith(
                        color: cs.error,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: cs.error,
                      ),
                    ),
                  ),
                DiffOp.insert => Semantics(
                    label: 'Extra word: ${token.word}',
                    excludeSemantics: true,
                    child: Text(
                      token.word,
                      key: Key('diff-$i-insert-${token.word}'),
                      style: tt.bodyLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                        decoration: TextDecoration.underline,
                        decorationColor: cs.onSurfaceVariant,
                        decorationStyle: TextDecorationStyle.wavy,
                      ),
                    ),
                  ),
              },
          ],
        ),
        // Only worth the vertical space once there's actually something to
        // decode; a perfect answer is self-explanatory.
        if (missed > 0 || extra > 0) ...[
          const SizedBox(height: 8),
          Text(
            key: const Key('type-answer-diff-legend'),
            [
              if (missed > 0) '$missed missed (struck through)',
              if (extra > 0) '$extra extra (underlined)',
            ].join(' · '),
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ],
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
      icon = Symbols.check_circle_rounded;
    } else if (score >= 0.7) {
      bg = cs.warningContainer;
      fg = cs.onWarningContainer;
      icon = Symbols.warning_amber_rounded;
    } else {
      bg = cs.errorContainer;
      fg = cs.onErrorContainer;
      icon = Symbols.cancel_rounded;
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
