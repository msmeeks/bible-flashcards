import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/verse_provider.dart';
import 'pack_name_dialog.dart';

/// Dropdown of the packs a verse can go in, ending with "New pack…" which
/// creates a pack and selects it.
class PackPickerField extends StatefulWidget {
  const PackPickerField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<PackPickerField> createState() => _PackPickerFieldState();
}

class _PackPickerFieldState extends State<PackPickerField> {
  /// Item value for "New pack…". Never a real pack id.
  static const _newPackItem = '__new_pack__';

  /// Bumped to rebuild the field from [PackPickerField.value] when the user
  /// cancels "New pack…" (the field otherwise keeps showing "New pack…").
  int _resets = 0;

  Future<void> _onSelected(String? selected) async {
    if (selected == null || selected == widget.value) return;
    if (selected != _newPackItem) {
      widget.onChanged(selected);
      return;
    }
    final id = await promptCreatePack(context);
    if (!mounted) return;
    if (id == null) {
      setState(() => _resets++);
    } else {
      widget.onChanged(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VerseProvider>();
    return DropdownButtonFormField<String>(
      // initialValue is read once, so re-key whenever the shown pack must
      // change: a new value from the parent, or a cancelled "New pack…".
      key: ValueKey('${widget.value}#$_resets'),
      initialValue: widget.value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Pack'),
      items: [
        for (final id in provider.packIds)
          DropdownMenuItem(
            value: id,
            child: Text(
              provider.packNameFor(id),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const DropdownMenuItem(
          value: _newPackItem,
          child: Text('New pack…'),
        ),
      ],
      onChanged: _onSelected,
    );
  }
}
