import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

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
    final submitFocusNode = FocusNode();
    String? bookErrorText;
    String? variantErrorText;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setS) => PopScope(
          canPop: !isSubmitting,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && isSubmitting) {
              SemanticsService.sendAnnouncement(
                View.of(ctx),
                'Please wait for the current action to finish.',
                TextDirection.ltr,
              );
            }
          },
          child: AlertDialog(
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
                  onChanged: isSubmitting
                      ? null
                      : (value) => setS(() {
                            selectedBookCode = value;
                            bookErrorText = null;
                          }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: textController,
                  focusNode: variantFocusNode,
                  enabled: !isSubmitting,
                  decoration: InputDecoration(
                    labelText: 'Variant text',
                    errorText: variantErrorText,
                  ),
                  maxLength: maxVariantLength,
                ),
              ],
            ),
            actions: [
              OutlinedButton(
                onPressed:
                    isSubmitting ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                focusNode: submitFocusNode,
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final book = selectedBookCode;
                        final text = textController.text.trim();
                        setS(() {
                          bookErrorText =
                              book == null ? 'Select a book.' : null;
                          variantErrorText =
                              text.isEmpty ? 'Enter a variant.' : null;
                        });
                        if (book == null) {
                          bookFocusNode.requestFocus();
                          return;
                        }
                        if (text.isEmpty) {
                          variantFocusNode.requestFocus();
                          return;
                        }
                        final hadFocus = submitFocusNode.hasFocus;
                        setS(() => isSubmitting = true);
                        var focusRedirected = false;
                        try {
                          await _db.addBookNameVariant(book, text);
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        } catch (e) {
                          if (!ctx.mounted) return;
                          setS(() => variantErrorText = e is ArgumentError
                              ? (e.message?.toString() ??
                                  'Could not add variant.')
                              : 'Could not add variant.');
                          variantFocusNode.requestFocus();
                          focusRedirected = true;
                        } finally {
                          if (ctx.mounted) {
                            setS(() => isSubmitting = false);
                            if (hadFocus && !focusRedirected) {
                              submitFocusNode.requestFocus();
                            }
                          }
                        }
                      },
                child: isSubmitting
                    ? Semantics(
                        liveRegion: true,
                        label: 'Adding variant, please wait',
                        child: SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(ctx).colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : const Text('Add'),
              ),
            ],
          ),
        ),
      ),
    );

    // Defer disposal by a frame: the dialog route's exit transition still
    // renders the (about-to-be-removed) content for one more frame after
    // showDialog's future resolves, so disposing synchronously here throws
    // "FocusNode used after being disposed" mid-transition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      textController.dispose();
      bookFocusNode.dispose();
      variantFocusNode.dispose();
      submitFocusNode.dispose();
    });
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
