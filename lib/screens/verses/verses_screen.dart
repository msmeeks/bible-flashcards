import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../database/database_helper.dart';
import '../../models/verse.dart';
import '../../providers/verse_provider.dart';
import '../../widgets/confidence_badge.dart';
import 'add_verse_screen.dart';
import 'verse_detail_screen.dart';

/// Pushes [VerseDetailScreen] for [verseId] onto the current navigator.
void openVerseDetail(BuildContext context, String verseId) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => VerseDetailScreen(verseId: verseId)),
  );
}

class VersesScreen extends StatefulWidget {
  const VersesScreen({super.key, this.activationCount = 0});

  final int activationCount;

  @override
  State<VersesScreen> createState() => _VersesScreenState();
}

class _VersesScreenState extends State<VersesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(VersesScreen old) {
    super.didUpdateWidget(old);
    if (widget.activationCount != old.activationCount) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openAddVerse() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddVerseScreen()),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verse added')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAvailableTab = _tabController.index == 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verses'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Memorized'),
            Tab(text: 'Available'),
          ],
        ),
        actions: [
          _VerseSearchButton(),
        ],
      ),
      body: Consumer<VerseProvider>(
        builder: (context, provider, _) {
          // Copy lists before sorting to avoid mutating provider state.
          final memorized = [...provider.memorizedVerses]..sort((a, b) {
              final aDate = a.memorizedAt ?? a.addedAt;
              final bDate = b.memorizedAt ?? b.addedAt;
              return bDate.compareTo(aDate);
            });

          final available = [...provider.availableVerses];

          // Only block on the spinner for the very first load. A reload
          // triggered by a mutation (e.g. markMemorized) already has data
          // to show, so keep the tabs (and their scroll state) mounted
          // instead of tearing them down behind a full-screen spinner.
          if (provider.isLoading && memorized.isEmpty && available.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _MemorizedTab(verses: memorized),
              _AvailableTab(verses: available),
            ],
          );
        },
      ),
      floatingActionButton: isAvailableTab
          ? FloatingActionButton.extended(
              onPressed: _openAddVerse,
              icon: const Icon(Symbols.add_rounded),
              label: const Text('Add Verse'),
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Search button widget — placed in AppBar actions
// ---------------------------------------------------------------------------

class _VerseSearchButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      builder: (context, controller) {
        return Semantics(
          label: 'Search verses',
          button: true,
          child: Tooltip(
            message: 'Search verses',
            child: IconButton(
              icon: const Icon(Symbols.search_rounded),
              onPressed: () => controller.openView(),
            ),
          ),
        );
      },
      viewHintText: 'Search verses…',
      suggestionsBuilder: (context, controller) {
        final query = controller.text.toLowerCase();
        if (query.isEmpty) return const [];
        final provider = Provider.of<VerseProvider>(context, listen: false);
        final all = [
          ...provider.memorizedVerses,
          ...provider.availableVerses,
        ];
        return all
            .where((v) =>
                v.reference.toLowerCase().contains(query) ||
                v.text.toLowerCase().contains(query))
            .map(
              (v) => ListTile(
                title: Text(v.reference),
                onTap: () {
                  controller.closeView(v.reference);
                  openVerseDetail(context, v.id);
                },
              ),
            )
            .toList();
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Memorized tab
// ---------------------------------------------------------------------------

class _MemorizedTab extends StatelessWidget {
  final List<Verse> verses;

  const _MemorizedTab({required this.verses});

  @override
  Widget build(BuildContext context) {
    if (verses.isEmpty) {
      return const _EmptyMemorizedState();
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: verses.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        return _MemorizedListTile(verse: verses[index]);
      },
    );
  }
}

class _MemorizedListTile extends StatelessWidget {
  final Verse verse;

  const _MemorizedListTile({required this.verse});

  @override
  Widget build(BuildContext context) {
    final preview =
        verse.text.length > 60 ? '${verse.text.substring(0, 60)}…' : verse.text;

    return Semantics(
      label: '${verse.reference} verse',
      child: ListTile(
        title: Text(verse.reference),
        subtitle: Text(preview),
        trailing: FutureBuilder<double?>(
          future: DatabaseHelper().getLatestVerseAccuracy(verse.id),
          builder: (context, snapshot) => ConfidenceBadge(
            accuracy: snapshot.data,
            verseRef: verse.reference,
          ),
        ),
        onTap: () => openVerseDetail(context, verse.id),
      ),
    );
  }
}

class _EmptyMemorizedState extends StatelessWidget {
  const _EmptyMemorizedState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: 'No verses memorized yet',
              child: Icon(
                Symbols.menu_book_rounded,
                size: 64,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No verses memorized yet',
              style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                // Switch to Available tab (index 1) via the ancestor scaffold state.
                final ancestor =
                    context.findAncestorStateOfType<_VersesScreenState>();
                ancestor?._tabController.animateTo(1);
              },
              child: const Text('Browse Verses'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Available tab
// ---------------------------------------------------------------------------

class _AvailableTab extends StatefulWidget {
  final List<Verse> verses;

  const _AvailableTab({required this.verses});

  @override
  State<_AvailableTab> createState() => _AvailableTabState();
}

class _AvailableTabState extends State<_AvailableTab> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.verses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: 'All verses memorized',
                child: Icon(
                  Symbols.check_circle_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'All verses memorized!',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Group verses by packId and build a flat list with headers.
    final groupedPacks = <String, List<Verse>>{};
    for (final verse in widget.verses) {
      groupedPacks.putIfAbsent(verse.packId, () => []).add(verse);
    }

    final items = <_ListItem>[];
    for (final packId in groupedPacks.keys) {
      items.add(_PackHeader(packId: packId));
      for (final verse in groupedPacks[packId]!) {
        items.add(_VerseItem(verse: verse));
      }
    }

    return ListView.separated(
      key: const Key('availableVerseList'),
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 88), // FAB clearance
      itemCount: items.length,
      separatorBuilder: (_, index) {
        if (items[index] is _PackHeader) return const SizedBox.shrink();
        return const Divider(height: 1, indent: 16);
      },
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is _PackHeader) {
          return _PackHeaderTile(
            key: ValueKey('header-${item.packId}'),
            packId: item.packId,
          );
        }
        final verse = (item as _VerseItem).verse;
        return _AvailableListTile(
          key: ValueKey(verse.id),
          verse: verse,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Sealed list item types for the available tab flat list
// ---------------------------------------------------------------------------

sealed class _ListItem {}

final class _PackHeader extends _ListItem {
  final String packId;
  _PackHeader({required this.packId});
}

final class _VerseItem extends _ListItem {
  final Verse verse;
  _VerseItem({required this.verse});
}

// ---------------------------------------------------------------------------
// Available tab sub-widgets
// ---------------------------------------------------------------------------

class _PackHeaderTile extends StatelessWidget {
  final String packId;

  const _PackHeaderTile({super.key, required this.packId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final packNames = context.watch<VerseProvider>().packNames;
    final displayName = packNames[packId] ?? 'Unknown Pack';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: cs.secondary),
      ),
    );
  }
}

class _AvailableListTile extends StatelessWidget {
  final Verse verse;

  const _AvailableListTile({super.key, required this.verse});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(verse.reference),
      subtitle: Text(verse.translation),
      trailing: _MemorizeButton(
        key: Key('memorize-button-${verse.id}'),
        verse: verse,
      ),
    );
  }
}

class _MemorizeButton extends StatefulWidget {
  final Verse verse;

  const _MemorizeButton({super.key, required this.verse});

  @override
  State<_MemorizeButton> createState() => _MemorizeButtonState();
}

class _MemorizeButtonState extends State<_MemorizeButton> {
  bool _isMemorizing = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onPressed() async {
    if (_isMemorizing) return;
    final hadFocus = _focusNode.hasFocus;
    setState(() => _isMemorizing = true);
    try {
      final provider = context.read<VerseProvider>();
      await provider.setVerseOfWeek(widget.verse.id);
      await provider.markMemorized(widget.verse.id);
    } catch (_) {
      // No error surface exists for this button today; swallow so a
      // transient failure doesn't crash the app, and fall through to the
      // focus-restore logic below.
    } finally {
      if (mounted) {
        setState(() => _isMemorizing = false);
        if (hadFocus) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _focusNode.requestFocus());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      focusNode: _focusNode,
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      onPressed: _isMemorizing ? null : _onPressed,
      child: _isMemorizing
          ? Semantics(
              liveRegion: true,
              label: 'Memorizing, please wait',
              child: const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : const Text('Memorize'),
    );
  }
}
