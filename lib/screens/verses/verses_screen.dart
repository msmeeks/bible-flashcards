import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../database/database_helper.dart';
import '../../models/verse.dart';
import '../../providers/verse_provider.dart';
import '../../theme/app_colors.dart';

class VersesScreen extends StatefulWidget {
  const VersesScreen({super.key});

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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openAddVerse() async {
    final result = await Navigator.of(context).pushNamed('/verse-add');
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
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Copy lists before sorting to avoid mutating provider state.
          final memorized = [...provider.memorizedVerses]
            ..sort((a, b) {
              final aDate = a.memorizedAt ?? a.addedAt;
              final bDate = b.memorizedAt ?? b.addedAt;
              return bDate.compareTo(aDate);
            });

          final available = [...provider.availableVerses];

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
                  Navigator.of(context)
                      .pushNamed('/verse-detail', arguments: v.id);
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
    final cs = Theme.of(context).colorScheme;
    final firstLetter =
        verse.reference.isNotEmpty ? verse.reference[0].toUpperCase() : '?';
    final preview =
        verse.text.length > 60 ? '${verse.text.substring(0, 60)}…' : verse.text;

    return ListTile(
      leading: Semantics(
        label: '${verse.reference} verse',
        child: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Text(
            firstLetter,
            style: TextStyle(color: cs.onPrimaryContainer),
          ),
        ),
      ),
      title: Text(verse.reference),
      subtitle: Text(preview),
      trailing: FutureBuilder<double?>(
        future: DatabaseHelper().getLatestVerseAccuracy(verse.id),
        builder: (context, snapshot) => _ConfidenceBadge(
          accuracy: snapshot.data,
          verseRef: verse.reference,
        ),
      ),
      onTap: () =>
          Navigator.of(context).pushNamed('/verse-detail', arguments: verse.id),
      onLongPress: () =>
          Navigator.of(context).pushNamed('/verse-detail', arguments: verse.id),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final double? accuracy;
  final String verseRef;

  const _ConfidenceBadge({required this.accuracy, required this.verseRef});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final String tier;
    final Color bg;
    final Color fg;
    final IconData icon;

    if (accuracy == null) {
      tier = 'Memorized';
      bg = cs.successContainer;
      fg = cs.onSuccessContainer;
      icon = Symbols.check_circle_rounded;
    } else if (accuracy! < 0.7) {
      tier = 'Weak';
      bg = cs.errorContainer;
      fg = cs.onErrorContainer;
      icon = Symbols.cancel_rounded;
    } else if (accuracy! < 0.9) {
      tier = 'Learning';
      bg = cs.warningContainer;
      fg = cs.onWarningContainer;
      icon = Symbols.warning_rounded;
    } else {
      tier = 'Strong';
      bg = cs.successContainer;
      fg = cs.onSuccessContainer;
      icon = Symbols.check_circle_rounded;
    }

    return Semantics(
      label: 'Confidence: $tier — $verseRef',
      excludeSemantics: true,
      child: Chip(
        avatar: Icon(icon, color: fg, size: 16),
        backgroundColor: bg,
        label: Text(tier, style: tt.labelSmall?.copyWith(color: fg)),
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        visualDensity: VisualDensity.compact,
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

class _AvailableTab extends StatelessWidget {
  final List<Verse> verses;

  const _AvailableTab({required this.verses});

  @override
  Widget build(BuildContext context) {
    if (verses.isEmpty) {
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
    for (final verse in verses) {
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
      padding: const EdgeInsets.only(bottom: 88), // FAB clearance
      itemCount: items.length,
      separatorBuilder: (_, index) {
        if (items[index] is _PackHeader) return const SizedBox.shrink();
        return const Divider(height: 1, indent: 16);
      },
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is _PackHeader) {
          return _PackHeaderTile(packId: item.packId);
        }
        return _AvailableListTile(verse: (item as _VerseItem).verse);
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

  const _PackHeaderTile({required this.packId});

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

  const _AvailableListTile({required this.verse});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(verse.reference),
      subtitle: Text(verse.translation),
      trailing: _MemorizeButton(verse: verse),
    );
  }
}

class _MemorizeButton extends StatelessWidget {
  final Verse verse;

  const _MemorizeButton({required this.verse});

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      onPressed: () async {
        final provider = context.read<VerseProvider>();
        await provider.setVerseOfWeek(verse.id);
        await provider.markMemorized(verse.id);
      },
      child: const Text('Memorize'),
    );
  }
}
