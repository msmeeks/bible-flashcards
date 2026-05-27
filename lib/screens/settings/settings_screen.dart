import 'package:flutter/material.dart';

import 'test_history_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.history_rounded),
            title: const Text('Test History'),
            subtitle: const Text('View past test results'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TestHistoryScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
