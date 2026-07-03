import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../widgets/audio_player_bar.dart';
import 'home/home_screen.dart';
import 'review/review_screen.dart';
import 'settings/settings_screen.dart';
import 'test/test_screen.dart';
import 'verses/verses_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  int _versesActivationCount = 0;

  // One Navigator per tab, keyed so its nested history survives MainScaffold
  // rebuilds and tab switches — this is what keeps the navbar/audio bar
  // visible while a tab drills into a sub-screen.
  final List<GlobalKey<NavigatorState>> _tabNavigatorKeys =
      List.generate(5, (_) => GlobalKey<NavigatorState>());

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Symbols.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Symbols.menu_book_rounded),
      label: 'Verses',
    ),
    NavigationDestination(
      icon: Icon(Symbols.repeat_rounded),
      label: 'Review',
    ),
    NavigationDestination(
      icon: Icon(Symbols.quiz_rounded),
      label: 'Test',
    ),
    NavigationDestination(
      icon: Icon(Symbols.settings_rounded),
      label: 'Settings',
    ),
  ];

  void _onDestinationSelected(int index) {
    setState(() {
      if (index == 1) _versesActivationCount++;
      _selectedIndex = index;
    });
  }

  Widget _tabNavigator(int index, Widget root) {
    return Navigator(
      key: _tabNavigatorKeys[index],
      onDidRemovePage: (page) {
        // The tab root page is never poppable (guarded by PopScope below),
        // so there is nothing to react to here.
      },
      pages: [
        MaterialPage(key: ValueKey('tab-$index-root'), child: root),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final tabNavigator = _tabNavigatorKeys[_selectedIndex].currentState;
        if (tabNavigator != null && tabNavigator.canPop()) {
          tabNavigator.pop();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _tabNavigator(0, const HomeScreen()),
            _tabNavigator(
              1,
              VersesScreen(activationCount: _versesActivationCount),
            ),
            _tabNavigator(2, const ReviewScreen()),
            _tabNavigator(3, const TestScreen()),
            _tabNavigator(4, const SettingsScreen()),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Persistent audio bar — hidden when no verse is playing.
            const AudioPlayerBar(),
            NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              destinations: _destinations,
            ),
          ],
        ),
      ),
    );
  }
}
