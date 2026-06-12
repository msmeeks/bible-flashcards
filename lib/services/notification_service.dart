import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Manages local notifications for audio playback state and verse interrupts.
///
/// Privacy: notification bodies never contain verse text or references.
/// All notifications use [NotificationVisibility.private] unless the user
/// explicitly opts into lock-screen visibility.
class NotificationService {
  static const _channelId = 'bible_flashcards_audio';
  static const _channelName = 'Audio Playback';
  static const _dailyChannelId = 'bible_flashcards_daily';
  static const _dailyChannelName = 'Daily Reminder';
  static const _playbackNotifId = 1;
  static const _interruptNotifId = 2;
  static const _dailyNotifId = 42;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Callback invoked when the user taps a notification action.
  /// [actionId] values: 'pause', 'stop', 'play', 'dismiss'.
  void Function(String actionId)? onAction;

  static const _validActions = {'pause', 'stop', 'play', 'dismiss'};

  AndroidFlutterLocalNotificationsPlugin? get _androidImpl =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Call once at app startup.
  Future<void> initialize() async {
    tz.initializeTimeZones();
    final zoneName = await FlutterTimezone.getLocalTimezone();
    try {
      tz.setLocalLocation(tz.getLocation(zoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
      ),
      onDidReceiveNotificationResponse: _handleResponse,
      onDidReceiveBackgroundNotificationResponse: _handleBackgroundResponse,
    );

    await _androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      ),
    );

    await _androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _dailyChannelId,
        _dailyChannelName,
        importance: Importance.defaultImportance,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Daily notification
  // ---------------------------------------------------------------------------

  /// Schedules a daily notification at [time].
  ///
  /// [showOnLockScreen] defaults to false per privacy policy. Verse content is
  /// never included in the notification body — body is always generic.
  ///
  /// Returns false if the exact alarm permission is denied; caller should
  /// surface a message to the user.
  Future<bool> scheduleDailyNotification(
    TimeOfDay time, {
    bool showOnLockScreen = false,
    String notificationType = 'verseOfWeek',
  }) async {
    // Request exact alarm permission (required on API 31+). On API < 31 the
    // plugin returns true automatically — no user action needed.
    final hasPermission =
        await _androidImpl?.requestExactAlarmsPermission() ?? false;
    if (!hasPermission) return false;

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final body = notificationType == 'reviewVerse'
        ? 'Time to practice a memorized verse'
        : 'Time to review your verse of the week';

    await _plugin.zonedSchedule(
      id: _dailyNotifId,
      title: 'Bible Flashcards',
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _dailyChannelId,
          _dailyChannelName,
          importance: Importance.defaultImportance,
          visibility: showOnLockScreen
              ? NotificationVisibility.public
              : NotificationVisibility.private,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    return true;
  }

  /// Cancels the scheduled daily notification.
  Future<void> cancelDailyNotification() async {
    await _plugin.cancel(id: _dailyNotifId);
  }

  // ---------------------------------------------------------------------------
  // Audio notifications
  // ---------------------------------------------------------------------------

  /// Shows a persistent ongoing notification while a verse is playing.
  Future<void> showPlaybackNotification() async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      visibility: NotificationVisibility.private,
      playSound: false,
      enableVibration: false,
      actions: [
        AndroidNotificationAction('pause', 'Pause'),
        AndroidNotificationAction('stop', 'Stop'),
      ],
    );

    await _plugin.show(
      id: _playbackNotifId,
      title: 'Bible Flashcards',
      body: 'Playing verse',
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }

  /// Shows a non-ongoing interrupt notification prompting the user to play a verse.
  Future<void> showVerseInterruptNotification() async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: false,
      autoCancel: true,
      visibility: NotificationVisibility.private,
      playSound: false,
      enableVibration: false,
      actions: [
        AndroidNotificationAction('play', 'Play'),
        AndroidNotificationAction('dismiss', 'Dismiss'),
      ],
    );

    await _plugin.show(
      id: _interruptNotifId,
      title: 'Bible Flashcards',
      body: 'Tap to hear your verse',
      notificationDetails: const NotificationDetails(android: androidDetails),
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
    if (action != null && _validActions.contains(action)) onAction?.call(action);
  }
}

// Top-level function required by flutter_local_notifications for background
// notification action handling.
@pragma('vm:entry-point')
void _handleBackgroundResponse(NotificationResponse response) {
  // Background actions are handled at app resume; no-op here.
}
