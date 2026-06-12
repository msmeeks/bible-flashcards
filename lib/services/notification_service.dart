import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/verse.dart';

/// Manages local notifications for audio playback state and verse interrupts.
///
/// Privacy: notification bodies never contain verse text or references.
/// All notifications use [NotificationVisibility.private].
class NotificationService {
  static const _channelId = 'bible_flashcards_audio';
  static const _channelName = 'Audio Playback';
  static const _playbackNotifId = 1;
  static const _interruptNotifId = 2;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Callback invoked when the user taps a notification action.
  /// [actionId] values: 'pause', 'stop', 'play', 'dismiss'.
  void Function(String actionId)? onAction;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initializes channels and handlers. Call once at app startup.
  Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _handleResponse,
      onDidReceiveBackgroundNotificationResponse: _handleBackgroundResponse,
    );

    // Create the audio channel.
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  /// Shows a persistent ongoing notification while a verse is playing.
  ///
  /// Body is generic — no verse text or reference exposed.
  Future<void> showPlaybackNotification(Verse verse) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      visibility: NotificationVisibility.private,
      playSound: false,
      enableVibration: false,
      actions: const [
        AndroidNotificationAction('pause', 'Pause'),
        AndroidNotificationAction('stop', 'Stop'),
      ],
    );

    final notifDetails = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: _playbackNotifId,
      title: 'Bible Flashcards',
      body: 'Playing verse',
      notificationDetails: notifDetails,
    );
  }

  /// Shows a non-ongoing interrupt notification prompting the user to play a
  /// memorized verse.
  ///
  /// Body is generic — no verse text or reference exposed.
  Future<void> showVerseInterruptNotification(Verse verse) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: false,
      autoCancel: true,
      visibility: NotificationVisibility.private,
      playSound: false,
      enableVibration: false,
      actions: const [
        AndroidNotificationAction('play', 'Play'),
        AndroidNotificationAction('dismiss', 'Dismiss'),
      ],
    );

    final notifDetails = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: _interruptNotifId,
      title: 'Bible Flashcards — Time for a verse',
      body: 'Tap to hear your verse',
      notificationDetails: notifDetails,
    );
  }

  /// Cancels the persistent playback notification.
  Future<void> cancelNotification() async {
    await _plugin.cancel(id: _playbackNotifId);
  }

  /// Cancels all notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  void _handleResponse(NotificationResponse response) {
    final action = response.actionId;
    if (action != null) onAction?.call(action);
  }
}

// Top-level function required by flutter_local_notifications for background
// notification action handling.
@pragma('vm:entry-point')
void _handleBackgroundResponse(NotificationResponse response) {
  // Background actions are handled at app resume; no-op here.
}
