# Iteration Progress

Append-only log of plan work on `integration/2026-07-14-test-modes` (PR #167).

---

## 2026-07-14 22:35 — `feat-audio-verse-playback.md` (#164) — done

Turned the audio interrupt into periodic memory-verse playback that, by default,
only inserts a verse while another app is playing audio, ducking it and letting
it resume.

**Chosen over the other two pending plans** because it carried the only real
architectural unknowns (first platform channel in the project, audio-focus
lifecycle, a persisted-settings migration); `feat-test-modes.md` is mostly UI
polish and `fix-notifications.md` is a small, well-understood fix.

What shipped:

- **New platform channel** `bible_flashcards/system_audio` — the project's first.
  Kotlin handler in `MainActivity.configureFlutterEngine` exposes
  `isMusicActive`, `requestTransientFocus` (AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK,
  `AudioFocusRequest` on API 26+ / legacy overload down to minSdk 24) and
  `abandonFocus`. No new Android permission. No method takes arguments, so
  nothing crossing the channel needs validating.
- **`SystemAudioService`** Dart wrapper. Fails closed — a PlatformException or
  MissingPluginException reports "no other audio" / "focus denied" rather than
  throwing, so an unreachable platform skips the interval instead of crashing or
  talking over the user.
- **Settings**: new `AudioTriggerMode` enum (`whileOtherAudioPlaying` default |
  `always`); `audioInterruptAfterMinutes` renamed to
  `audioInterruptIntervalMinutes`. Migration reads the legacy
  `audio_interrupt_after_minutes` pref key so existing installs keep their
  configured minutes. `audioInterruptEnabled` / `audioInterruptProbability`
  unchanged (probability is the verse-of-week *selection weight*, not a
  play/skip roll).
- **`AudioInterruptService`**: gates each interval on trigger mode, debounces
  `isMusicActive` (3 samples / 300ms, both injectable) so a gap between tracks
  doesn't skip, holds focus for the whole verse (`playVerse` resolves only after
  reference→pause→text) and releases it in a `finally`. Re-entrancy guard stops
  the 10s poll starting a second playback mid-verse. Focus denial ⇒ stay silent.
- **Settings UI**: "Play verses periodically" switch, interval picker
  (15/30/45/60/90), and a "When to play" ChoiceChip pair. Changing interval or
  mode restarts tracking, since the running timer captured the old values.

Corrections to the plan (code was source of truth):

- The plan said the old behavior "fires once after a fixed threshold". It did
  not — the old timer already re-armed after each crossing. The genuinely new
  work is the other-app audio gate, the trigger mode, and audio focus. Docs say
  so explicitly rather than claiming a one-shot→recurring conversion.
- The plan said settings are stored via a DB map; they are actually
  SharedPreferences. Migration was written against the real storage.

Incidental fix (pre-existing, unrelated to #164): the "Notification type"
`SegmentedButton` sat in a `ListTile` trailing slot and threw "Trailing widget
consumes the entire tile width" at a 375px viewport — a real defect on ~360dp
Android phones. Now full-width under the title. Found because the new 375px
layout test rendered the whole screen; confirmed pre-existing by reproducing it
on a clean tree.

Verification:

- 553 unit/widget tests pass; `flutter analyze` reports 0 errors/warnings
  (10 pre-existing deprecation infos).
- New `integration_test/system_audio_channel_test.dart` drives the **real**
  channel against the **real** AudioManager on-device
  (`flutter test integration_test/system_audio_channel_test.dart -d <device>`) —
  unit tests mock the channel, so this is the only thing proving the Kotlin side
  is registered and agrees on method names. `requestTransientFocus` returning
  true is the load-bearing assertion: the error path can only return false.
- Visual smoke on the Pixel 9 emulator: Settings renders correctly, new controls
  disabled while the feature is off.

Known issue, **not** caused by this work: `integration_test/app_smoke_test.dart`
fails at `home-choose-verse-button` ("Found 0 widgets"). Reproduced identically
on a clean tree at this commit's base. It taps `format-chip-recite`, so it likely
belongs with `feat-test-modes.md` (#165 removes Recite). Left for that plan.

---

## 2026-07-15 10:10 — `fix-notifications.md` (#163) — done

Made the daily reminder actually fire: the app now requests the Android 13+
notification permission before scheduling, names whichever permission is
missing, and re-registers its alarm after reboot.

**Chosen over `feat-test-modes.md`** because that plan is auto-marked `stalled`
(6 attempts against the driver's `MAX_ATTEMPTS = 5`), and it is the UI-polish
plan this prompt says to rank last; notifications is the platform/permissions
work. The driver had independently bumped this plan's attempt counter, so both
readings agreed.

What shipped:

- **Runtime `POST_NOTIFICATIONS` request** in `scheduleDailyNotification`,
  before scheduling — the actual bug. Without it the OS drops every
  notification even though the alarm fires, which is exactly what #163
  reported.
- **`DailyReminderResult`** (`scheduled` / `notificationsDenied` /
  `exactAlarmsDenied`) replaces the bare `bool`. The two permissions live in
  different system screens, so a single "denied" could not tell the user where
  to go. Fails closed: a `PlatformException` (e.g. a request already in flight)
  counts as denied rather than crashing Settings.
- **Inline denial banner** reusing the existing `InlineStatusBanner` (error
  severity, live region) instead of the `SnackBar` the old code used —
  `DESIGN_BRIEF.md:221` forbids `SnackBar` for errors. A successful schedule
  clears it.
- **Reboot survival**: `RECEIVE_BOOT_COMPLETED` + the plugin's
  `ScheduledNotificationBootReceiver` (`exported="false"`), plus the QUICKBOOT /
  `MY_PACKAGE_REPLACED` actions for OEMs that skip `BOOT_COMPLETED`.

Corrections to the plan (code was source of truth):

- Plan step 3 (use allow-while-idle) was **already done** — `zonedSchedule`
  already passed `exactAllowWhileIdle`. No change needed; added a test to pin it.
- Plan implied Dart-side API-version branching. None is needed and none was
  added: the plugin branches natively (`Build.VERSION.SDK_INT >= TIRAMISU`),
  reporting `areNotificationsEnabled()` below 33 without prompting. So no
  `device_info_plus` dependency.
- The notifications doc claimed settings persist to SQLite; they use
  SharedPreferences. Corrected (same error the #164 entry above hit).

Testing — the old test file asserted this service "cannot be satisfied in a
headless unit test environment". That was **wrong**: the plugin facade resolves
through `FlutterLocalNotificationsPlatform.instance`, which is settable, so a
subclass of `AndroidFlutterLocalNotificationsPlugin` fakes the whole surface
with zero production refactor. That unlocked the permission tests the plan's
acceptance criteria demanded. 15 new tests (553 → 568):

- 7 in `notification_service_test.dart` — denial per permission, request
  ordering, `PlatformException` fail-closed, schedules-once, allow-while-idle,
  generic body. Mutation-checked: deleting the permission gate kills 3.
- 3 in `settings_screen_test.dart` — each denial renders an inline message (and
  no `SnackBar`); success shows none.
- 5 in new `test/android_manifest_test.dart` — guards the manifest
  declarations, whose absence is silent and only observable after a reboot.

Verification: 568 unit/widget tests pass; `flutter analyze` clean (10
pre-existing deprecation infos). Debug APK builds and the merged manifest
contains the receiver + permissions. On the Pixel 9 emulator (API 35,
`granted=false` reproduced first): the permission prompt now appears; denying
shows the inline banner and schedules nothing; granting proceeds to the
exact-alarm system screen; then alarm 42 registers `RTC_WAKEUP`. **Rebooted
twice** — the alarm re-registers with the same `origWhen`, app never reopened
and no manual broadcast (the first attempt was inconclusive because a manual
`am broadcast` overlapped it).

Incidental fix (pre-existing, unrelated to #163): the "Theme" `SegmentedButton`
had the same "Trailing widget consumes the entire tile width" defect the #164
entry above fixed for "Notification type" — it only escaped notice because the
default 800px test surface and the lazy `ListView` meant no test ever built that
tile at phone width. Now full-width under the title. This shifted the Data
section down and exposed a brittle test that tapped without settling its scroll;
that test now calls `ensureVisible` + `pumpAndSettle`.

Note for a human: `feat-test-modes.md` is `stalled` at 6 attempts and the driver
will not retry it, so this iteration cannot reach all-plans-complete without a
decision on that plan.
