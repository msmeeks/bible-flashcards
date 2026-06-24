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
  final Set<TestFormat> _selectedFormats = TestFormat.values.toSet();
  final Set<PromptDirection> _selectedDirections = PromptDirection.values.toSet();
  String? _prerequisiteError;

  void _startTest(VerseProvider provider) {
    if (_selectedFormats.isEmpty) {
      setState(() {
        _prerequisiteError = 'Select at least one format.';
      });
      return;
    }
    if (_selectedDirections.isEmpty) {
      setState(() {
        _prerequisiteError = 'Select at least one prompt direction.';
      });
      return;
    }

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
          selectedFormats: _selectedFormats,
          selectedDirections: _selectedDirections,
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
                const _SectionLabel(label: 'Mode'),
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
                const _SectionLabel(label: 'Format'),
                const SizedBox(height: 8),
                Semantics(
                  label: 'Format — select one or more',
                  explicitChildNodes: true,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      _FormatChip(
                        format: TestFormat.recite,
                        icon: Icons.record_voice_over_outlined,
                        selected: _selectedFormats.contains(TestFormat.recite),
                        onSelected: (on) => setState(() {
                          on
                              ? _selectedFormats.add(TestFormat.recite)
                              : _selectedFormats.remove(TestFormat.recite);
                          _prerequisiteError = null;
                        }),
                      ),
                      _FormatChip(
                        format: TestFormat.type,
                        icon: Icons.keyboard_outlined,
                        selected: _selectedFormats.contains(TestFormat.type),
                        onSelected: (on) => setState(() {
                          on
                              ? _selectedFormats.add(TestFormat.type)
                              : _selectedFormats.remove(TestFormat.type);
                          _prerequisiteError = null;
                        }),
                      ),
                      _FormatChip(
                        format: TestFormat.fillBlank,
                        icon: Icons.text_fields_outlined,
                        selected:
                            _selectedFormats.contains(TestFormat.fillBlank),
                        onSelected: (on) => setState(() {
                          on
                              ? _selectedFormats.add(TestFormat.fillBlank)
                              : _selectedFormats.remove(TestFormat.fillBlank);
                          _prerequisiteError = null;
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionLabel(label: 'Prompt direction'),
                const SizedBox(height: 8),
                Semantics(
                  label: 'Prompt direction — select one or more',
                  explicitChildNodes: true,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Reference → Text'),
                        selected: _selectedDirections
                            .contains(PromptDirection.refToText),
                        onSelected: (on) => setState(() {
                          on
                              ? _selectedDirections
                                  .add(PromptDirection.refToText)
                              : _selectedDirections
                                  .remove(PromptDirection.refToText);
                          _prerequisiteError = null;
                        }),
                      ),
                      FilterChip(
                        label: const Text('Text → Reference'),
                        selected: _selectedDirections
                            .contains(PromptDirection.textToRef),
                        onSelected: (on) => setState(() {
                          on
                              ? _selectedDirections
                                  .add(PromptDirection.textToRef)
                              : _selectedDirections
                                  .remove(PromptDirection.textToRef);
                          _prerequisiteError = null;
                        }),
                      ),
                    ],
                  ),
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

class _FormatChip extends StatelessWidget {
  const _FormatChip({
    required this.format,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final TestFormat format;
  final IconData icon;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    // The format icon lives in the label row (not `avatar`) so the
    // selected-state checkmark has its own space and doesn't overlap it.
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(format.label),
        ],
      ),
      selected: selected,
      onSelected: onSelected,
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
