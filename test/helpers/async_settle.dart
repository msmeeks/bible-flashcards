import 'package:flutter_test/flutter_test.dart';

/// Drives a pending sqflite round-trip (or other real-async work started
/// inside a widget test) to completion: pump, pump 100ms, wait out a real
/// 200ms delay, then pump [finalPump] to let any resulting rebuild settle.
Future<void> pumpUntilAsyncSettled(
  WidgetTester tester, {
  Duration finalPump = const Duration(milliseconds: 200),
}) =>
    tester.runAsync(() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump(finalPump);
    });
