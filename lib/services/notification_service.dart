import '../models/verse.dart';

/// Manages local notifications for verse-of-week reminders and audio interrupts.
/// Full implementation by the audio feature agent.
///
/// Notification visibility is set to VISIBILITY_PRIVATE — no PII on lock screen.
class NotificationService {
  /// Initialises the notification channels. Call once at app startup.
  Future<void> init() async {
    // TODO(audio-agent): initialise flutter_local_notifications channels
    // Channel must use VISIBILITY_PRIVATE and appropriate importance.
    throw UnimplementedError('NotificationService.init');
  }

  /// Schedules a daily reminder notification for [verse].
  Future<void> scheduleVerseReminder(Verse verse, DateTime scheduledAt) async {
    // TODO(audio-agent): schedule via flutter_local_notifications
    throw UnimplementedError('NotificationService.scheduleVerseReminder');
  }

  /// Cancels all scheduled verse reminder notifications.
  Future<void> cancelAllReminders() async {
    // TODO(audio-agent): cancel all notifications
    throw UnimplementedError('NotificationService.cancelAllReminders');
  }

  /// Shows an in-progress notification while audio review is playing.
  Future<void> showAudioReviewNotification(Verse verse) async {
    // TODO(audio-agent): show foreground service notification
    throw UnimplementedError('NotificationService.showAudioReviewNotification');
  }

  /// Dismisses the audio review notification.
  Future<void> dismissAudioReviewNotification() async {
    // TODO(audio-agent): cancel audio review notification
    throw UnimplementedError(
        'NotificationService.dismissAudioReviewNotification');
  }
}
