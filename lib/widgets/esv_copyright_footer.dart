import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/settings/settings_screen.dart';

const _prefsKey = 'esv_footer_collapsed_v1';

class EsvCopyrightFooter extends StatefulWidget {
  final bool hasEsvContent;

  const EsvCopyrightFooter({super.key, required this.hasEsvContent});

  @override
  State<EsvCopyrightFooter> createState() => _EsvCopyrightFooterState();
}

class _EsvCopyrightFooterState extends State<EsvCopyrightFooter> {
  bool _collapsed = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _collapsed = prefs.getBool(_prefsKey) ?? false;
      _loaded = true;
    });
  }

  Future<void> _setCollapsed(bool collapsed) async {
    setState(() => _collapsed = collapsed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, collapsed);
  }

  void _navigateToEsvSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  Widget _buildCollapsed(TextTheme tt) {
    return Semantics(
      button: true,
      expanded: false,
      label: 'ESV copyright notice. Collapsed. Activate to expand.',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _setCollapsed(false),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              const SizedBox(width: 16),
              Text('ESV®', style: tt.labelSmall),
              const SizedBox(width: 4),
              const Icon(Symbols.expand_more_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpanded(TextTheme tt) {
    return Semantics(
      expanded: true,
      label: 'ESV copyright notice. Expanded.',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Scripture quotations are from the ESV® Bible, '
                    '© 2001 by Crossway. Used by permission.',
                    style: tt.labelSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Collapse copyright notice',
                  icon: const Icon(Symbols.expand_less_rounded, size: 16),
                  onPressed: () => _setCollapsed(true),
                ),
              ],
            ),
            Semantics(
              label: 'View full ESV copyright terms in Settings',
              excludeSemantics: true,
              child: TextButton(
                onPressed: _navigateToEsvSettings,
                child: const Text('Full terms in Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.hasEsvContent) return const SizedBox.shrink();
    if (!_loaded) return const SizedBox.shrink();

    final tt = Theme.of(context).textTheme;
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final content = _collapsed ? _buildCollapsed(tt) : _buildExpanded(tt);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          label: _collapsed
              ? 'ESV copyright notice collapsed'
              : 'ESV copyright notice expanded',
          child: const SizedBox.shrink(),
        ),
        reducedMotion
            ? content
            : AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: content,
              ),
      ],
    );
  }
}
