# Plan: Notifications — request runtime notification permission; survive reboot & Doze

**Issues:** #163

---

## Goal

Daily reminders actually appear: the app requests the Android 13+ notification permission, surfaces denial, re-schedules after reboot, and fires under Doze.

---

## Context

Verified on a physical Pixel 9 Pro (Android 16): the daily reminder never appears because `POST_NOTIFICATIONS` is denied (`granted=false`, appops `ignore`, `importance=NONE`). The scheduling code requests only the exact-alarm permission (`requestExactAlarmsPermission()`) and never the runtime notification permission, so on Android 13+ it stays off and the OS drops every notification even though the alarm fires (confirmed: the app's `ScheduledNotificationReceiver` fired ~4d18h before diagnosis). Secondary gaps: no `RECEIVE_BOOT_COMPLETED` receiver (alarms lost on reboot) and the app is not Doze-exempt.

---

## Implementation Notes

### Files to Modify

| File | Change |
|------|--------|
| `lib/services/notification_service.dart` | Add runtime notification-permission request (Android 13+) before scheduling; propagate a denied result like the exact-alarm denial. Use allow-while-idle exact scheduling. |
| `lib/screens/settings/settings_screen.dart` (settings flow calling the schedule routine) | Show a clear message when notification or exact-alarm permission is denied, reusing the existing exact-alarm-denied messaging pattern. |
| `android/app/src/main/AndroidManifest.xml` | Add `RECEIVE_BOOT_COMPLETED` + the flutter_local_notifications boot receiver. |
| `docs/features/notifications.md` | Document the runtime permission flow and boot rescheduling. |

### Steps

1. In the schedule routine, before scheduling, request the runtime notification permission on API 33+ via the Android flutter_local_notifications impl's `requestNotificationsPermission()`. On API < 33 skip the prompt (unchanged behavior). If denied, return/propagate the denied result the same way `requestExactAlarmsPermission()` denial is handled today (returns `false`) so the settings UI can inform the user.
2. In the settings flow, surface a message when either permission is denied (reuse the existing exact-alarm-denied pattern — inline message/error card, not a `SnackBar` per design brief §13).
3. Ensure scheduling uses allow-while-idle exact semantics so Doze does not defer the reminder.
4. Add `RECEIVE_BOOT_COMPLETED` and the flutter_local_notifications `ScheduledNotificationBootReceiver` to the manifest so scheduled notifications are re-registered after reboot (or re-schedule from app startup as a fallback).
5. Keep notification content generic — verse text must never appear in the body (existing privacy decision).

---

## Acceptance Criteria

- [ ] On Android 13+, enabling the daily reminder triggers the system notification-permission prompt if not already granted.
- [ ] If notification permission is denied, the settings UI shows a clear message and the reminder is not reported as successfully scheduled.
- [ ] On API < 33 the flow works without a notification-permission prompt (unchanged).
- [ ] After a device reboot, a previously scheduled daily notification still fires without reopening the app.
- [ ] The daily notification fires under Doze (allow-while-idle).
- [ ] Notification body remains generic (no verse content).
- [ ] Tests cover permission-granted schedules, permission-denied surfaces a message and returns denied, and API-version branching.

---

## Pre-Implementation Review

**Privacy (`meta/PRIVACY.md`):** notification body must stay generic — no verse content in the payload; lock-screen visibility default unchanged. Requesting `POST_NOTIFICATIONS` is the minimum necessary and user-consented via the system prompt.

**Security:** runtime permission request and a `BOOT_COMPLETED` receiver add no sensitive surface; the boot receiver only re-schedules existing local notifications (no network, no user data). Confirm the receiver is not `exported` beyond what the plugin requires.

**Design:** denial messaging uses an inline message/error card, not a `SnackBar` (brief §13). No new visual components.

**Accessibility:** any new denial message must be a live-region/inline error linked to the control, readable by screen readers.
