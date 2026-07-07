# Bible Flashcards — Project Notes for Claude

## Emulator management

Always use `scripts/emulator.sh` to control the Android emulator. Never construct raw `emulator` or `adb emu kill` invocations manually.

```sh
bash scripts/emulator.sh start --detach    # boot AVD + flutter run
bash scripts/emulator.sh stop              # kill emulator
bash scripts/emulator.sh restart --detach  # stop then start
bash scripts/emulator.sh restart --wipe --detach   # use when app refuses to launch
bash scripts/emulator.sh start --no-app    # boot only, no flutter run
```

**Claude must always pass `--detach` when starting or restarting the app.** Without it, `flutter run` stays attached in the foreground for interactive hot-reload (r/R/q) and never exits — a `start`/`restart` invocation without `--detach` will hang forever and no "task complete" notification will ever arrive, because the underlying process doesn't terminate. `--detach` backgrounds `flutter run`, polls `/tmp/flutter_run.log` for the ready marker itself, and returns (or errors out on timeout) once the app is actually up — so the bash call completing *is* the notification. Do not run the script in the background and then wait for a separate "app is ready" signal; there isn't one beyond the script call returning. If you need live logs after that, `tail -f /tmp/flutter_run.log` or `adb logcat`.

The AVD name is `bible_flashcards_pixel9`. The emulator binary lives at `/opt/homebrew/share/android-commandlinetools/emulator/emulator` (installed by Homebrew, not Android Studio).

**Laptop keyboard** is enabled via `hw.keyboard=yes` in `~/.android/avd/bible_flashcards_pixel9.avd/config.ini`. This requires a cold boot (no snapshot load) — the script uses `-no-snapshot-load` by default.

**"Activity class not found" error** is caused by emulator state corruption, not a code bug. Fix: `bash scripts/emulator.sh restart --wipe`.

## Tech stack

Pure Flutter/Dart. No web, iOS, or desktop targets. Android only.

- Encrypted SQLite via `sqflite_sqlcipher` + Android Keystore key from `flutter_secure_storage`
- TTS via `flutter_tts` (no bundled audio files)
- Notifications via `flutter_local_notifications`
- State management via `provider`

## Docs

Read `docs/llms.md` before any planning or code change — it indexes all feature docs and points to key source files.

## Agent skills

### Issue tracker

Issues tracked in GitHub Issues (`msmeeks/bible-flashcards`); external PRs are not a triage surface. See `docs/agents/issue-tracker.md`.

### Triage labels

Default label vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout: one `CONTEXT.md` + `docs/adr/` at repo root. See `docs/agents/domain.md`.

### Issue workflow

These skills form a pipeline — pick the entry point that matches where the work starts:

1. `/qa` (conversational) — user reports bugs/issues in conversation → files GitHub issues
2. `/to-prd` → `/to-issues` — alternative entry point when starting from a design discussion instead of a live bug report
3. `/triage` — evaluates *one* issue/PR, categorizes it, writes an agent brief, marks `ready-for-agent`
4. `/triage-issues` — picks up `ready-for-agent` issues in bulk and groups them into `meta/plans/` workstreams
5. `/triage-pr-comments` — same as step 4, but for review comments on open PRs

Do not confuse `/triage` (single-issue evaluation) with `/triage-issues` (bulk grouping into plans) — they are sequential steps, not alternatives.
