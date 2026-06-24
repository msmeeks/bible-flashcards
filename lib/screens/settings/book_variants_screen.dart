import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../utils/book_name_variants.dart';

/// Settings screen for managing custom book-name variants used to score
/// reference-answer test questions leniently (see #30).
class BookVariantsScreen extends StatefulWidget {
  const BookVariantsScreen({super.key});

  @override
  State<BookVariantsScreen> createState() => _BookVariantsScreenState();
}

class _BookVariantsScreenState extends State<BookVariantsScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  late Future<List<Map<String, Object?>>> _variantsFuture;

  @override
  void initState() {
    super.initState();
    _loadVariants();
  }

  void _loadVariants() {
    _variantsFuture = _db.getBookNameVariants();
  }

  Future<void> _showAddDialog() async {
    String? selectedBookCode;
    final textController = TextEditingController();
    final bookFocusNode = FocusNode();
    final variantFocusNode = FocusNode();
    String? bookErrorText;
    String? variantErrorText;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          semanticLabel: 'Add custom variant',
          title: const Text('Add custom variant'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedBookCode,
                autofocus: true,
                focusNode: bookFocusNode,
                decoration: InputDecoration(
                  labelText: 'Book',
                  errorText: bookErrorText,
                ),
                items: [
                  for (final entry in bookDisplayNames.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) => setS(() {
                  selectedBookCode = value;
                  bookErrorText = null;
                }),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: textController,
                focusNode: variantFocusNode,
                decoration: InputDecoration(
                  labelText: 'Variant text',
                  errorText: variantErrorText,
                ),
                maxLength: maxVariantLength,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final book = selectedBookCode;
                final text = textController.text.trim();
                setS(() {
                  bookErrorText = book == null ? 'Select a book.' : null;
                  variantErrorText = text.isEmpty ? 'Enter a variant.' : null;
                });
                if (book == null) {
                  bookFocusNode.requestFocus();
                  return;
                }
                if (text.isEmpty) {
                  variantFocusNode.requestFocus();
                  return;
                }
                try {
                  await _db.addBookNameVariant(book, text);
                } catch (e) {
                  if (!ctx.mounted) return;
                  setS(() => variantErrorText = e is ArgumentError
                      ? (e.message?.toString() ?? 'Could not add variant.')
                      : 'Could not add variant.');
                  variantFocusNode.requestFocus();
                  return;
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    textController.dispose();
    bookFocusNode.dispose();
    variantFocusNode.dispose();
    if (mounted) setState(_loadVariants);
  }

  Future<void> _removeVariant(int id) async {
    await _db.removeBookNameVariant(id);
    if (mounted) setState(_loadVariants);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Book Name Variants')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _variantsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final variants = snapshot.data ?? [];
          if (variants.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No custom variants yet.\nAdd one if a book abbreviation '
                  'you use isn\'t recognized during reference tests.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: variants.length,
            itemBuilder: (context, index) {
              final row = variants[index];
              final id = row['id'] as int;
              final bookCode = row['book_code'] as String;
              final variantText = row['variant_text'] as String;
              final bookName = bookDisplayNames[bookCode] ?? bookCode;
              return ListTile(
                title: Text(variantText),
                subtitle: Text(bookName),
                trailing: Semantics(
                  label: "Remove variant '$variantText' for $bookName",
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                      onPressed: () => _removeVariant(id),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        tooltip: 'Add custom variant',
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
