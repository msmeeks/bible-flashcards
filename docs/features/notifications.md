# Notifications

## Summary
The notifications feature lets users schedule a daily reminder to review their verses. Users pick a time, choose what type of verse to be reminded about, and optionally allow the notification to appear on the lock screen.

## Users / Use Cases
- **Solo user**: sets a daily reminder at a chosen time; picks verse-of-week or a memorized review verse as the content type; controls whether the reminder is visible on the lock screen.

## Technologies
- `flutter_local_notifications` — schedules and fires the daily notification via `zonedSchedule`
- `flutter_timezone` — resolves the device's IANA timezone so the exact-alarm fires at local wall time
- `timezone` (`timezone/data/latest_all.dart`) — converts local time to a `TZDateTime` for scheduling
- Provider — `NotificationService` is injected into the provider tree in `lib/app.dart`

## Technical Overview
`NotificationService` owns two notification channels: `bible_flashcards_audio` (low-importance, for audio playback) and `bible_flashcards_daily` (default-importance, for the daily reminder). Scheduling calls `FlutterLocalNotificationsPlugin.zonedSchedule` with `matchDateTimeComponents: DateTimeComponents.time` so the alarm repeats daily. If the chosen time has already passed today, the first fire is deferred to the same time tomorrow. The lock-screen visibility is a per-schedule parameter (`NotificationVisibility.public` vs `private`); it is re-applied whenever the user changes either the time or the lock-screen toggle.

## Key Files
| File | Purpose |
|---|---|
| `lib/services/notification_service.dart` | All notification logic: channels, daily schedule, audio playback notifications |
| `lib/models/settings.dart` | `dailyNotificationTime`, `notificationType`, `showOnLockScreen` fields on `AppSettings` |
| `lib/providers/settings_provider.dart` | Persists notification settings to SQLite via `toMap`/`fromMap` |
| `lib/screens/settings/settings_screen.dart` | Notifications section UI: time picker, SegmentedButton, lock-screen toggle |
| `lib/app.dart` | Registers `NotificationService` as a top-level Provider |
| `android/app/src/main/AndroidManifest.xml` | `SCHEDULE_EXACT_ALARM` permission declaration |

## Technical Detail

### Notification Channels
| Channel ID | Name | Importance | Used For |
|---|---|---|---|
| `bible_flashcards_audio` | Audio Playback | Low (no sound/vibration) | Playback and interrupt notifications |
| `bible_flashcards_daily` | Daily Reminder | Default | Scheduled daily reminder |

### Scheduling Flow
1. User taps "Daily reminder" → `showTimePicker` → `NotificationService.scheduleDailyNotification(time, showOnLockScreen:)`.
2. Service calls `androidImpl?.requestExactAlarmsPermission()`. If denied, scheduling is silently skipped — no crash, no reminder.
3. `TZDateTime` is computed for today at the picked hour/minute. If already past, add 1 day.
4. `zonedSchedule` with `AndroidScheduleMode.exactAllowWhileIdle` and `matchDateTimeComponents: DateTimeComponents.time` fires daily.
5. Cancellation: `cancelDailyNotification()` calls `_plugin.cancel(id: 42)`.

### Notification IDs
| ID | Notification |
|---|---|
| 1 | Audio playback (ongoing) |
| 2 | Audio interrupt |
| 42 | Daily reminder |

### Settings Model
Three fields on `AppSettings` (all persisted via `settings` SQLite table):
- `dailyNotificationTime` (`TimeOfDay?`) — null means disabled; serialised as two integer columns `daily_notification_hour` / `daily_notification_minute`.
- `notificationType` (`String`) — `'verseOfWeek'` or `'reviewVerse'`; default `'verseOfWeek'`. Used by the caller (not yet wired to notification body content — body is always generic: "Time to review your verse").
- `showOnLockScreen` (`bool`) — default `false` per privacy policy. When toggled, the existing scheduled notification is rescheduled immediately with the new visibility.

### Privacy
- Notification body never contains verse text or scripture references.
- Default visibility is `VISIBILITY_PRIVATE` (content hidden on lock screen).
- User must explicitly opt in to `showOnLockScreen`; UI copy warns about bystander visibility.
- `SCHEDULE_EXACT_ALARM` is the only new permission; no internet, camera, or contact access.
- See `meta/PRIVACY.md` for full data-handling policy.

### Permissions (Android)
- `POST_NOTIFICATIONS` — Android 13+ runtime permission for all notifications
- `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` — background TTS audio
- `SCHEDULE_EXACT_ALARM` — required for `zonedSchedule` with `exactAllowWhileIdle` on Android 12+ (API 31+)

### Audio Playback Notifications (also in NotificationService)
`showPlaybackNotification` and `showVerseInterruptNotification` no longer accept a `Verse` parameter — notification bodies are fixed strings, keeping verse content off the notification shade.

| Notification | Title | Body | Actions |
|---|---|---|---|
| Playback (ongoing) | "Bible Flashcards" | "Playing verse" | Pause, Stop |
| Interrupt | "Bible Flashcards — Time for a verse" | "Tap to hear your verse" | Play, Dismiss |

## Changelog
| Date | Change |
|---|---|
| 2026-06-12 | Initial documentation — daily reminder scheduling, timezone init, lock-screen toggle, notification channels, settings model fields |
