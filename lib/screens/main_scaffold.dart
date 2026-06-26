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
  int _versesActivationCount = 0;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const HomeScreen(),
          VersesScreen(activationCount: _versesActivationCount),
          const ReviewScreen(),
          const TestScreen(),
          const SettingsScreen(),
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
    );
  }
}
