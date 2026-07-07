import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bible_flashcards/app.dart';
import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/providers/settings_provider.dart';
import 'package:bible_flashcards/services/notification_service.dart';

import 'helpers/async_settle.dart';
import 'helpers/fake_database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpFakeDatabase();
  });

  tearDown(() async {
    await tearDownFakeDatabase();
  });

  testWidgets(
    'first-launch Activity Tracking dialog uses OutlinedButton for the '
    'negative action, not a bare TextButton',
    (tester) async {
      await tester.pumpWidget(
        BibleFlashcardsApp(
          dbHelper: DatabaseHelper(),
          settingsProvider: SettingsProvider(),
          notificationService: NotificationService(),
        ),
      );
      await pumpUntilAsyncSettled(tester);

      expect(find.text('Activity Tracking'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'No thanks'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'No thanks'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Got it'), findsOneWidget);
    },
  );
}
