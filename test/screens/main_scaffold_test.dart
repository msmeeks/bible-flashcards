import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/providers/audio_provider.dart';
import 'package:bible_flashcards/providers/settings_provider.dart';
import 'package:bible_flashcards/providers/tracking_provider.dart';
import 'package:bible_flashcards/providers/verse_provider.dart';
import 'package:bible_flashcards/screens/main_scaffold.dart';
import 'package:bible_flashcards/services/notification_service.dart';

Widget _wrap() {
  final dbHelper = DatabaseHelper();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>(
        create: (_) => SettingsProvider(),
      ),
      ChangeNotifierProvider<VerseProvider>(
        create: (_) => VerseProvider(dbHelper),
      ),
      ChangeNotifierProvider<AudioProvider>(
        create: (_) => AudioProvider(
          notificationService: NotificationService(),
        ),
      ),
      ChangeNotifierProvider<TrackingProvider>(
        create: (_) => TrackingProvider(dbHelper),
      ),
    ],
    child: const MaterialApp(home: MainScaffold()),
  );
}

void main() {
  testWidgets('bottom nav has Review between Verses and Test', (tester) async {
    await tester.pumpWidget(_wrap());

    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();

    expect(labels, ['Home', 'Verses', 'Review', 'Test', 'Settings']);
  });
}
