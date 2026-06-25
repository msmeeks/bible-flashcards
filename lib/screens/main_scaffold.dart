import 'package:flutter/material.dart';
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

  static const _screens = [
    HomeScreen(),
    VersesScreen(),
    ReviewScreen(),
    TestScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Persistent audio bar — hidden when no verse is playing.
          const AudioPlayerBar(),
          NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            destinations: _destinations,
          ),
        ],
      ),
    );
  }
}
