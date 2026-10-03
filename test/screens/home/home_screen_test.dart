import 'package:bible_flashcards/database/database_helper.dart';
import 'package:bible_flashcards/models/settings.dart';
import 'package:bible_flashcards/providers/settings_provider.dart';
import 'package:bible_flashcards/providers/verse_provider.dart';
import 'package:bible_flashcards/screens/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Counts the auto-advance checks the screen asks for, so the wiring can be
/// tested without depending on what day it actually is.
class _CountingVerseProvider extends VerseProvider {
  _CountingVerseProvider() : super(DatabaseHelper());

  int loadCalls = 0;
  int advanceChecks = 0;

  @override
  Future<void> loadVerses() async {
    loadCalls++;
  }

  @override
  Future<void> autoAdvanceVerseOfWeekIfNeeded(
    AppSettings settings,
    void Function(AppSettings) onUpdate, {
    DateTime? now,
  }) async {
    advanceChecks++;
  }
}

Future<_CountingVerseProvider> _pumpHome(WidgetTester tester) async {
  final verses = _CountingVerseProvider();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<VerseProvider>.value(value: verses),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return verses;
}

void main() {
  testWidgets('checks auto-advance once when first shown', (tester) async {
    final verses = await _pumpHome(tester);
    expect(verses.advanceChecks, 1);
  });

  testWidgets('re-checks auto-advance when the app returns to the foreground',
      (tester) async {
    final verses = await _pumpHome(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(verses.advanceChecks, 2);
  });

  testWidgets('does not re-check while merely inactive', (tester) async {
    final verses = await _pumpHome(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();

    expect(verses.advanceChecks, 1);
  });
}
