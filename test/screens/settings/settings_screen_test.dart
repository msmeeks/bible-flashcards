import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/providers/settings_provider.dart';
import 'package:bible_flashcards/providers/tracking_provider.dart';
import 'package:bible_flashcards/providers/verse_provider.dart';
import 'package:bible_flashcards/screens/settings/settings_screen.dart';
import 'package:bible_flashcards/services/notification_service.dart';

// Mirrors the provider tree BibleFlashcardsApp builds in lib/app.dart.
Widget _wrap() {
  final dbHelper = DatabaseHelper();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: SettingsProvider()),
      ChangeNotifierProvider<VerseProvider>.value(
        value: VerseProvider(dbHelper),
      ),
      ChangeNotifierProvider<TrackingProvider>.value(
        value: TrackingProvider(dbHelper),
      ),
      Provider<NotificationService>.value(value: NotificationService()),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'tapping Daily reminder opens the time picker when NotificationService is registered',
    (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Daily reminder'));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);
    },
  );

  testWidgets(
    'Audio review toggle is no longer shown',
    (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      expect(find.text('Daily reminder'), findsOneWidget);
      expect(find.text('Audio review'), findsNothing);
    },
  );
}
