import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/verse.dart';
import '../../providers/verse_provider.dart';

class AddVerseScreen extends StatefulWidget {
  const AddVerseScreen({super.key});

  @override
  State<AddVerseScreen> createState() => _AddVerseScreenState();
}

class _AddVerseScreenState extends State<AddVerseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _textController = TextEditingController();
  String _translation = 'ESV';
  bool _isSaving = false;
  String? _saveError;

  @override
  void dispose() {
    _referenceController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _saveVerse() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final reference = _referenceController.text.trim();
    final text = _textController.text.trim();

    // Build a stable ID from the reference — lowercase, replace spaces/colons.
    final id =
        '${_translation.toLowerCase()}_${reference.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

    final verse = Verse(
      id: id,
      reference: reference,
      text: text,
      translation: _translation,
      packId: 'custom',
      addedAt: DateTime.now(),
    );

    try {
      await context.read<VerseProvider>().addCustomVerse(verse);
      if (mounted) {
        Navigator.of(context).pop(true); // pop with success result
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveError = 'Failed to save verse. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Verse'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _referenceController,
              decoration: const InputDecoration(
                labelText: 'Reference e.g. Romans 8:28',
              ),
              textCapitalization: TextCapitalization.words,
              maxLength: 100,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Reference is required';
                }
                if (value.trim().length > 100) {
                  return 'Reference is too long';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Verse text',
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Verse text is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Translation',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'ESV', label: Text('ESV')),
                ButtonSegment(value: 'CSB', label: Text('CSB')),
                ButtonSegment(value: 'NLT', label: Text('NLT')),
              ],
              selected: {_translation},
              onSelectionChanged: (values) {
                if (values.isNotEmpty) {
                  setState(() => _translation = values.first);
                }
              },
            ),
            const SizedBox(height: 32),
            if (_saveError != null)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _saveError!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ),
              ),
            FilledButton(
              onPressed: _isSaving ? null : _saveVerse,
              child: _isSaving
                  ? Semantics(
                      label: 'Saving, please wait',
                      child: const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Text('Save Verse'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isSaving
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
