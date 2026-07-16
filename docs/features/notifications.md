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

Scheduling is gated on two independent permissions, and `scheduleDailyNotification` returns a `DailyReminderResult` (`scheduled` / `notificationsDenied` / `exactAlarmsDenied`) rather than a bare bool so Settings can name the one that is missing — they live in different system screens. Because a scheduled alarm is dropped by the OS on reboot, the manifest registers the plugin's `ScheduledNotificationBootReceiver` to re-register it.

## Key Files
| File | Purpose |
|---|---|
| `lib/services/notification_service.dart` | All notification logic: channels, daily schedule, audio playback notifications |
| `lib/models/settings.dart` | `dailyNotificationTime`, `notificationType`, `showOnLockScreen` fields on `AppSettings` |
| `lib/providers/settings_provider.dart` | Persists notification settings to SharedPreferences |
| `lib/screens/settings/settings_screen.dart` | Notifications section UI: time picker, SegmentedButton, lock-screen toggle |
| `lib/app.dart` | Registers `NotificationService` as a top-level Provider |
| `android/app/src/main/AndroidManifest.xml` | `SCHEDULE_EXACT_ALARM` / `POST_NOTIFICATIONS` / `RECEIVE_BOOT_COMPLETED` declarations + `ScheduledNotificationBootReceiver` |
| `lib/widgets/inline_status_banner.dart` | Reused to render the permission-denied message inline |
| `test/android_manifest_test.dart` | Guards the manifest declarations the reminder depends on |

## Technical Detail

### Notification Channels
| Channel ID | Name | Importance | Used For |
|---|---|---|---|
| `bible_flashcards_audio` | Audio Playback | Low (no sound/vibration) | Playback and interrupt notifications |
| `bible_flashcards_daily` | Daily Reminder | Default | Scheduled daily reminder |

### Scheduling Flow
1. User taps "Daily reminder" → `showTimePicker` → `_applyNotificationSettings` → `NotificationService.scheduleDailyNotification(time, showOnLockScreen:, notificationType:)`.
2. Service calls `androidImpl?.requestNotificationsPermission()` **first**. Without `POST_NOTIFICATIONS` the OS silently drops the notification even though the alarm fires, so this gates everything else. Returns `notificationsDenied` and schedules nothing if refused. A `PlatformException` (e.g. a permission request already in flight) is treated as denied — the flow fails closed rather than crashing Settings.
3. Service calls `androidImpl?.requestExactAlarmsPermission()`. Returns `exactAlarmsDenied` and schedules nothing if refused.
4. `TZDateTime` is computed for today at the picked hour/minute. If already past, adds 1 day so first fire is tomorrow at that time.
5. `zonedSchedule` with `AndroidScheduleMode.exactAllowWhileIdle` (so Doze does not defer it) and `matchDateTimeComponents: DateTimeComponents.time` fires daily. Returns `scheduled`.
6. `_applyNotificationSettings` maps a denied result to an inline `InlineStatusBanner` under the "Daily reminder" tile naming the permission to grant (a live region, so screen readers announce it). Per design brief §13 errors are never a `SnackBar`.
7. Cancellation: `cancelDailyNotification()` calls `_plugin.cancel(id: 42)`. Also called when lock-screen toggle changes and `dailyNotificationTime` is null.

### Reminder Error Lifecycle
`_reminderError` (screen state in `settings_screen.dart`) holds the denial message. It is cleared on **every** path that leaves no reminder to describe, not just on success:

| Path | Effect on `_reminderError` |
|---|---|
| Schedule succeeds (`scheduled`) | cleared |
| Schedule denied | set to the message naming the missing permission |
| User clears the reminder (`_clearDailyNotification`) | cleared **before** the platform call, so a failing cancel cannot strand it |
| `_applyNotificationSettings` with a null `dailyNotificationTime` | cleared before the early return |

The clear-on-off paths are the fix for #168: previously a denial left Settings indefinitely instructing the user to grant a permission for a reminder they had already turned off.

The banner is **always mounted** and passed the nullable message rather than being wrapped in an `if (_reminderError != null)`. `InlineStatusBanner` collapses to `SizedBox.shrink()` on null and documents always-mounted as its intended contract — the live region must already be in the tree for the change to announce. Its horizontal padding sits outside the banner so a null message adds no vertical space.

The message is also folded into the "Daily reminder" tile's own semantic label (`Semantics(label: _reminderError, ...)`, key `daily-reminder`) so the reason is discoverable from the control later in the session, not only via the banner's one-shot announcement. The tile is deliberately **not** a live region — only the banner is — otherwise the initial transition double-announces.

### Test Seams
Two seams exist purely so correctness-critical branches can be asserted deterministically. Both are production-safe defaults; no call site passes them outside tests.

| Seam | Why it exists |
|---|---|
| `NotificationService({tz.TZDateTime Function()? now})` | Defaults to `tz.TZDateTime.now(tz.local)`. The step-4 rollover branch reads the clock, so without this its coverage depended on the wall-clock time the suite ran at — the suite passed either way while silently exercising a different branch each run. **The seam must stay zone-aware**: the scheduling math builds the target in `now().location`, so a naive `DateTime` seam would lose the zone and compute wrong times at DST boundaries. |
| `debugHandleResponse` (`@visibleForTesting`) | Runs the same dispatch the plugin callback runs, without a platform round trip. It **delegates** to `_handleResponse` rather than reproducing the valid-action filter — a hook that re-implemented the filter would pass while testing a copy. `_validActions` stays private. |

### API-Version Branching
No Dart-side version check exists, and none is needed: the plugin branches natively. On API 33+ `requestNotificationsPermission` prompts for `POST_NOTIFICATIONS`; below 33 it reports `areNotificationsEnabled()` without prompting. `requestExactAlarmsPermission` likewise returns true automatically below API 31.

### Surviving Reboot
Android clears scheduled alarms on reboot. `flutter_local_notifications` persists scheduled notifications and re-registers them from `ScheduledNotificationBootReceiver`, but the plugin's own manifest does **not** declare that receiver — the app must. The receiver is declared `android:exported="false"` (it only re-registers this app's local alarms) and additionally listens for `MY_PACKAGE_REPLACED` plus the QUICKBOOT actions used by OEMs that never broadcast `BOOT_COMPLETED`.

`test/android_manifest_test.dart` asserts these declarations: their absence is silent and only observable after a physical reboot.

### Notification Bodies
| `notificationType` | Body text |
|---|---|
| `verseOfWeek` | "Time to review your verse of the week" |
| `reviewVerse` | "Time to practice a memorized verse" |

### Notification IDs
| ID | Notification |
|---|---|
| 1 | Audio playback (ongoing) |
| 2 | Audio interrupt |
| 42 | Daily reminder |

### Settings Model
Three fields on `AppSettings` (all persisted via SharedPreferences, not the SQLite database):
- `dailyNotificationTime` (`TimeOfDay?`) — null means disabled; stored as two integer prefs `daily_notification_hour` / `daily_notification_minute`.
- `notificationType` (`String`) — `'verseOfWeek'` or `'reviewVerse'`; default `'verseOfWeek'`. Controls the notification body text (see Notification Bodies below).
- `showOnLockScreen` (`bool`) — default `false` per privacy policy. When toggled, the existing scheduled notification is rescheduled immediately with the new visibility.

### Privacy
- Notification body never contains verse text or scripture references.
- Default visibility is `VISIBILITY_PRIVATE` (content hidden on lock screen).
- User must explicitly opt in to `showOnLockScreen`; UI copy warns about bystander visibility.
- `POST_NOTIFICATIONS` is requested via the system prompt (explicit user consent) and is the minimum necessary to deliver the reminder.
- Notification scheduling needs no internet, camera, or contact access.
- See `meta/PRIVACY.md` for full data-handling policy.

### Permissions (Android)
- `POST_NOTIFICATIONS` — Android 13+ runtime permission for all notifications; requested by `scheduleDailyNotification` before scheduling
- `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` — background TTS audio
- `SCHEDULE_EXACT_ALARM` — required for `zonedSchedule` with `exactAllowWhileIdle` on Android 12+ (API 31+)
- `RECEIVE_BOOT_COMPLETED` — lets the boot receiver re-register scheduled alarms after reboot

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
| 2026-06-12 | Corrected notification body text per-type, snackbar-on-false behavior, interrupt notification title, notificationType wiring |
| 2026-07-14 | Fixed "Notification type" `SegmentedButton` overflowing its `ListTile` trailing slot at 375px width; now renders full-width under the title (found incidentally during #164) |
| 2026-07-15 | #163: request `POST_NOTIFICATIONS` at runtime before scheduling (the reminder never appeared without it); `DailyReminderResult` replaces the bool return so Settings names the denied permission; denial now renders as an inline banner instead of a `SnackBar` (brief §13); added `RECEIVE_BOOT_COMPLETED` + `ScheduledNotificationBootReceiver` so alarms survive reboot. Corrected this doc's claim that notification settings persist to SQLite — they use SharedPreferences |
| 2026-07-15 | #168/#178/#181: reminder error now clears on every reminder-off path (was stranding a permission request for a reminder the user had already turned off); banner always mounted with a nullable message per `InlineStatusBanner`'s contract; error folded into the reminder tile's semantic label, with the live region left on the banner alone to avoid a double announcement |
| 2026-07-15 | #171/#170/#188: added a zone-aware `now` clock seam (midnight rollover was previously covered nondeterministically — which branch ran depended on CI's wall-clock time) and a `debugHandleResponse` dispatch hook that delegates to the production filter. Tests now pin both rollover sides, all four action ids plus unknown/null, the unknown-timezone→UTC fallback, both channel creations, and both notification bodies. No scheduling or dispatch behavior changed |
