# Bible Flashcards — Project Notes for Claude

## Emulator management

Always use `scripts/emulator.sh` to control the Android emulator. Never construct raw `emulator` or `adb emu kill` invocations manually.

```sh
bash scripts/emulator.sh start    # boot AVD + flutter run
bash scripts/emulator.sh stop     # kill emulator
bash scripts/emulator.sh restart  # stop then start
bash scripts/emulator.sh restart --wipe   # use when app refuses to launch
bash scripts/emulator.sh start --no-app  # boot only, no flutter run
```

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
