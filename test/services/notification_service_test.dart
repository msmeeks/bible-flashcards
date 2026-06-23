import 'package:flutter_test/flutter_test.dart';

import 'package:bible_flashcards/services/notification_service.dart';

// NotificationService wraps FlutterLocalNotificationsPlugin which requires
// FlutterLocalNotificationsPlatform.instance to be initialized by native
// plugin registration. That registration only happens on a real device or
// emulator — it cannot be satisfied in a headless unit test environment
// without injecting the platform instance.
//
// Coverage for the scheduling, visibility, and permission-denied paths is
// provided by integration tests (run via `flutter drive` on the emulator).
//
// Unit-testable behavior is covered below.

void main() {
  group('NotificationService onAction', () {
    test('onAction is null by default', () {
      final service = NotificationService();
      expect(service.onAction, isNull);
    });

    test('onAction can be set and replaced', () {
      final service = NotificationService();
      service.onAction = (_) {};
      expect(service.onAction, isNotNull);
      service.onAction = null;
      expect(service.onAction, isNull);
    });
  });
}
