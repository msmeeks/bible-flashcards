# Developer Guide

## Quick start (macOS)

If you are setting up from scratch on a Mac, run the one-command setup script:

```sh
cd /path/to/bible-flashcards
bash scripts/setup-mac.sh
```

This installs Homebrew, Java 17, Flutter, Android command-line tools (API 35),
and creates a Pixel 9 Pro emulator. Safe to re-run. Flags:

| Flag | Effect |
|---|---|
| `--skip-emulator` | Skip AVD creation (physical device only) |
| `--verify-only` | Check what is/isn't installed without making changes |
| `--help` | Print full usage and troubleshooting guide |

After the script finishes, follow its printed instructions to add `JAVA_HOME`,
`ANDROID_HOME`, and PATH entries to your `~/.zshrc`.

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Flutter SDK | ≥ 3.22.0 | https://docs.flutter.dev/get-started/install |
| Dart SDK | ≥ 3.4.0 | bundled with Flutter |
| Android SDK | API 33+ (Android 13) | Android Studio or `sdkmanager` |
| Java | 17 | via Android Studio or `brew install openjdk@17` |

Confirm your setup:

```sh
flutter doctor
```

All items in the output should show a green checkmark. The only required section is **Android toolchain**; iOS, Chrome, and Linux items can be ignored.

---

## Project setup

```sh
git clone <repo-url>
cd bible-flashcards
flutter pub get
```

No environment variables or secrets are needed. The database encryption key is generated per-install and stored in Android Keystore — there is nothing to configure before building.

---

## Running tests

```sh
flutter test
```

Unit and widget tests live in `test/`.

### Smoke test

```sh
bash scripts/smoke_test.sh
```

Runs `flutter test`, then wipes and boots the project emulator (via
`scripts/emulator.sh`) and runs `integration_test/app_smoke_test.dart` on it —
a real end-to-end pass through adding a verse, memorizing it, confirming Home
shows it as the verse of the week, and completing a test session. This is the
only way to exercise the database layer (`DatabaseHelper`), since
`sqflite_sqlcipher` does not run on the host JVM and requires a real device or
emulator. Run this before merging any change that touches the DB layer,
theming/fonts, or the add-verse/memorize/test flows — it wipes the emulator's
current data, so save any in-progress manual testing state first.

---

## Running on an emulator

Use the emulator helper script for all start/stop/restart operations:

```sh
bash scripts/emulator.sh start    # boot AVD + flutter run (default)
bash scripts/emulator.sh stop     # kill running emulator
bash scripts/emulator.sh restart  # stop then start
```

Flags:

| Flag | Effect |
|---|---|
| `--wipe` | Cold-boot with full data wipe — fixes "Activity class not found" corruption |
| `--no-app` | Boot the emulator only; skip `flutter run` |

The AVD (`bible_flashcards_pixel9`) is created by `scripts/setup-mac.sh`. The script uses the Homebrew-installed emulator at `/opt/homebrew/share/android-commandlinetools/emulator/emulator`.

The first build compiles native Gradle dependencies and takes several minutes. Subsequent hot-reloads (`r` in the terminal) are fast.

> **Laptop keyboard in the emulator:** `hw.keyboard=yes` is set in the AVD config (`~/.android/avd/bible_flashcards_pixel9.avd/config.ini`). Keyboard input works automatically after a cold boot (no snapshot load).

### Emulator notes

- **Notifications** require granting `POST_NOTIFICATIONS` permission in the emulator's app settings the first time audio review is enabled.
- **TTS** (`flutter_tts`) uses the system Text-to-Speech engine. The default Google TTS engine is present on Play-image emulators. If TTS is silent, go to **Settings → Accessibility → Text-to-speech** and confirm an engine is installed.
- **Keystore** works on emulators with a lock screen set up. If the app crashes on first launch with a Keystore error, set a PIN or pattern in the emulator's security settings.
- **On-device speech recognition** (recite-mode mic, `speech_to_text` with `onDevice: true`) is unreliable on the `bible_flashcards_pixel9` AVD even though it's a Google Play image: recognition reports "started" but `onResult`/`onStatus`/`onError` never fire, so the UI would hang on "Listening" without the bounded timeout in `test_session_screen.dart`. This is a testing-environment gap, not a code bug — if you need to verify real successful recognition rather than just the timeout fallback, try downloading the offline speech model first (Google app → Settings → Voice → Offline speech recognition) or test on a physical device.

---

## Installing on a physical Android device

### One-time device setup

1. On the device, go to **Settings → About phone** and tap **Build number** seven times to enable Developer Options.
2. Go to **Settings → Developer Options** and enable **USB debugging**.
3. Connect the device via USB. Accept the "Allow USB debugging?" prompt on the device.
4. Confirm Flutter sees the device:
   ```sh
   flutter devices
   ```

### Install and run

```sh
flutter run
```

To build and install a release APK without staying attached to the terminal:

```sh
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Wireless debugging (Android 11+)

1. **Settings → Developer Options → Wireless debugging → Enable**.
2. Tap **Pair device with pairing code**, then:
   ```sh
   adb pair <ip>:<pairing-port>
   ```
3. After pairing:
   ```sh
   adb connect <ip>:<debugging-port>
   flutter devices   # should show the device
   flutter run
   ```

---

## Linting

```sh
flutter analyze
```

The project uses `flutter_lints` (see `analysis_options.yaml`). Fix all warnings before committing. There is no separate ESLint or ruff step — this is a pure Dart/Flutter project.

---

## Project structure

```
lib/
  main.dart                   # Entry point; initialises providers
  app.dart                    # MaterialApp, theme, routes
  database/
    database_helper.dart      # Encrypted SQLite singleton
  models/                     # Verse, VersionPack, TestResult, Settings
  providers/                  # VerseProvider, AudioProvider, SettingsProvider
  screens/
    home/                     # HomeScreen (verse-of-week, quick actions)
    verses/                   # VersesScreen, AddVerseScreen, VerseDetailScreen
    test/                     # TestScreen (setup), TestSessionScreen, TestResultScreen
    settings/                 # SettingsScreen, TestHistoryScreen
  services/
    audio_service.dart        # TTS state machine
    audio_review_service.dart # Continuous shuffle loop
    audio_interrupt_service.dart # Timer-based interruptions
    notification_service.dart # Lock-screen notification controls
  theme/                      # AppTheme, AppColors
  utils/
    scoring.dart              # computeScore (LCS), blankIndices
  widgets/                    # VerseCard, AudioPlayerBar
assets/
  packs/                      # Navigator TMS JSON definitions
test/
  models/
  utils/
```

---

## Key dependencies

| Package | Purpose |
|---|---|
| `sqflite_sqlcipher` | Encrypted SQLite; requires Android Keystore key on every open |
| `flutter_secure_storage` | Stores the DB encryption key in Android Keystore / hardware-backed secure element |
| `flutter_tts` | Text-to-speech for audio playback — no bundled audio files needed |
| `flutter_local_notifications` | Lock-screen and notification-tray controls for audio |
| `provider` | State management |
| `shared_preferences` | Lightweight settings persistence (non-sensitive) |

Full dependency list: `pubspec.yaml`.

---

## Android manifest highlights

- **No `INTERNET` permission** — the app is fully offline.
- **`android:allowBackup="false"`** — prevents the encrypted database from being extracted via ADB backup or cloud backup.
- **`FOREGROUND_SERVICE_MEDIA_PLAYBACK`** — required for background TTS on Android 14+.
- **Notification visibility `VISIBILITY_PRIVATE`** — no verse text appears on the lock screen.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| App crashes on first launch | Keystore unavailable (no device lock screen) | Set a PIN/pattern in device security settings |
| TTS produces no audio | No TTS engine installed | Install Google TTS from Play Store; check Settings → Accessibility → TTS |
| "Activity class does not exist" on launch | Emulator state corruption | Run `bash scripts/emulator.sh restart --wipe` |
| `flutter run` says "No devices" | ADB not detecting device | Confirm USB debugging is on; try `adb devices`; re-plug cable |
| Notification permission denied | Android 13+ requires explicit grant | Grant in Settings → Apps → Bible Flashcards → Notifications |
| Gradle build fails | Java version mismatch | Ensure `JAVA_HOME` points to Java 17; run `flutter doctor` |
