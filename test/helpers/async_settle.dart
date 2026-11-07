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

/// Pumps, with short real-time waits in between, until [condition] holds.
/// For real-async work (sqflite round-trips) whose duration depends on
/// machine load — a fixed delay passes alone but flakes in the full suite.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('pumpUntil timed out after $timeout'
          '${reason == null ? '' : ': $reason'}');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
}
