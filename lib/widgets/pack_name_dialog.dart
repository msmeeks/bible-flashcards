import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/verse_provider.dart';

/// Asks for a pack name, validated by [VerseProvider.validatePackName].
/// Returns the trimmed name, or null if cancelled. Pass [renaming] (a pack id)
/// and [initialName] to rename an existing pack.
Future<String?> showPackNameDialog(
  BuildContext context, {
  String title = 'New pack',
  String confirmLabel = 'Create',
  String initialName = '',
  String? renaming,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PackNameDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialName: initialName,
      renaming: renaming,
    ),
  );
}

/// Prompts for a name and creates the pack. Returns the new pack's id, or
/// null if the user cancelled.
Future<String?> promptCreatePack(BuildContext context) async {
  final provider = context.read<VerseProvider>();
  final name = await showPackNameDialog(context);
  if (name == null) return null;
  return provider.createPack(name);
}

class _PackNameDialog extends StatefulWidget {
  const _PackNameDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialName,
    required this.renaming,
  });

  final String title;
  final String confirmLabel;
  final String initialName;
  final String? renaming;

  @override
  State<_PackNameDialog> createState() => _PackNameDialogState();
}

class _PackNameDialogState extends State<_PackNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final error = context
        .read<VerseProvider>()
        .validatePackName(_controller.text, renaming: widget.renaming);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('pack-name-field'),
        controller: _controller,
        autofocus: true,
        maxLength: VerseProvider.maxPackNameLength,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(labelText: 'Pack name', errorText: _error),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
