import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/verse_provider.dart';
import 'test_enums.dart';
import 'test_session_screen.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  TestMode _mode = TestMode.verseOfWeek;
  TestFormat _format = TestFormat.recite;
  PromptDirection _direction = PromptDirection.refToText;
  String? _prerequisiteError;

  void _startTest(VerseProvider provider) {
    if (_mode == TestMode.verseOfWeek) {
      if (provider.verseOfWeek == null) {
        setState(() {
          _prerequisiteError =
              'No verse of the week is set. Go to Home to set one.';
        });
        return;
      }
    } else {
      if (provider.memorizedVerses.length < 5) {
        setState(() {
          _prerequisiteError =
              'You need at least 5 memorized verses for Review mode. '
              'You have ${provider.memorizedVerses.length}.';
        });
        return;
      }
    }

    setState(() => _prerequisiteError = null);

    final verses = _mode == TestMode.verseOfWeek
        ? [provider.verseOfWeek!]
        : provider.getRandomMemorizedVerses(5);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TestSessionScreen(
          verses: verses,
          testMode: _mode,
          testFormat: _format,
          promptDirection: _direction,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test')),
      body: Consumer<VerseProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionLabel(label: 'Mode'),
                const SizedBox(height: 8),
                SegmentedButton<TestMode>(
                  segments: const [
                    ButtonSegment(
                      value: TestMode.verseOfWeek,
                      label: Text('Verse of Week'),
                      icon: Icon(Icons.star_outline),
                    ),
                    ButtonSegment(
                      value: TestMode.review,
                      label: Text('Review (5 verses)'),
                      icon: Icon(Icons.refresh),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (value) {
                    setState(() {
                      _mode = value.first;
                      _prerequisiteError = null;
                    });
                  },
                ),
                const SizedBox(height: 24),
                _SectionLabel(label: 'Format'),
                const SizedBox(height: 8),
                SegmentedButton<TestFormat>(
                  segments: const [
                    ButtonSegment(
                      value: TestFormat.recite,
                      label: Text('Recite'),
                      icon: Icon(Icons.record_voice_over_outlined),
                    ),
                    ButtonSegment(
                      value: TestFormat.type,
                      label: Text('Type'),
                      icon: Icon(Icons.keyboard_outlined),
                    ),
                    ButtonSegment(
                      value: TestFormat.fillBlank,
                      label: Text('Fill Blanks'),
                      icon: Icon(Icons.text_fields_outlined),
                    ),
                  ],
                  selected: {_format},
                  onSelectionChanged: (value) {
                    setState(() {
                      _format = value.first;
                      _prerequisiteError = null;
                    });
                  },
                ),
                const SizedBox(height: 24),
                _SectionLabel(label: 'Prompt direction'),
                const SizedBox(height: 8),
                SegmentedButton<PromptDirection>(
                  segments: const [
                    ButtonSegment(
                      value: PromptDirection.refToText,
                      label: Text('Reference → Text'),
                    ),
                    ButtonSegment(
                      value: PromptDirection.textToRef,
                      label: Text('Text → Reference'),
                    ),
                  ],
                  selected: {_direction},
                  onSelectionChanged: (value) {
                    setState(() {
                      _direction = value.first;
                      _prerequisiteError = null;
                    });
                  },
                ),
                const SizedBox(height: 32),
                if (_prerequisiteError != null) ...[
                  _ErrorCard(message: _prerequisiteError!),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => _startTest(provider),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start Test'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.onErrorContainer, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onErrorContainer,
                  ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
