#!/usr/bin/env bash
# Usage: scripts/emulator.sh [start|stop|restart] [--wipe] [--no-app] [--detach]
#
# start    — boot the AVD and run the Flutter app (default)
# stop     — kill the running emulator
# restart  — stop then start
#
# --wipe   — cold-boot with full data wipe (fixes "Activity class not found" corruption)
# --no-app — boot the emulator only; skip `flutter run`
# --detach — run `flutter run` in the background and return once the app is
#            ready, instead of attaching to it as an interactive session.
#            Use this for automation/background invocations; the default
#            (no --detach) keeps flutter run in the foreground with live
#            hot-reload keys (r/R/q) for normal terminal use.

set -euo pipefail

AVD_NAME="bible_flashcards_pixel9"
EMULATOR_BIN="/opt/homebrew/share/android-commandlinetools/emulator/emulator"
ADB="/opt/homebrew/share/android-commandlinetools/platform-tools/adb"
FLUTTER_RUN_LOG="/tmp/flutter_run.log"
FLUTTER_RUN_READY_MARKER="Flutter run key commands"
FLUTTER_RUN_READY_TIMEOUT=180

CMD="${1:-start}"
WIPE=false
RUN_APP=true
DETACH=false

for arg in "$@"; do
  case "$arg" in
    --wipe)   WIPE=true ;;
    --no-app) RUN_APP=false ;;
    --detach) DETACH=true ;;
  esac
done

die() { echo "ERROR: $*" >&2; exit 1; }

emulator_running() {
  "$ADB" devices 2>/dev/null | grep -q "emulator.*device"
}

do_stop() {
  if emulator_running; then
    echo "Stopping emulator..."
    "$ADB" emu kill 2>/dev/null || true
    # Wait for it to disappear
    until ! emulator_running; do sleep 2; done
    echo "Emulator stopped."
  else
    echo "No emulator running."
  fi
}

do_start() {
  if emulator_running; then
    echo "Emulator already running."
  else
    echo "Starting AVD: $AVD_NAME..."
    FLAGS="-no-snapshot-load"
    if $WIPE; then
      FLAGS="$FLAGS -wipe-data"
      echo "  (data wipe enabled)"
    fi
    # shellcheck disable=SC2086
    "$EMULATOR_BIN" -avd "$AVD_NAME" $FLAGS > /tmp/emulator.log 2>&1 &

    echo -n "Waiting for emulator to boot"
    until emulator_running; do printf '.'; sleep 3; done
    until [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null)" = "1" ]; do
      printf '.'; sleep 3
    done
    echo " ready."
  fi

  if $RUN_APP; then
    cd "$(dirname "$0")/.."
    SECRETS_FLAG=""
    if [ -f secrets.local ]; then
      SECRETS_FLAG="--dart-define-from-file=secrets.local"
    fi

    if $DETACH; then
      echo "Launching app via flutter run (detached)..."
      rm -f "$FLUTTER_RUN_LOG"
      # shellcheck disable=SC2086
      nohup flutter run $SECRETS_FLAG > "$FLUTTER_RUN_LOG" 2>&1 &
      FLUTTER_PID=$!

      echo -n "Waiting for app ready"
      SECONDS_WAITED=0
      until grep -q "$FLUTTER_RUN_READY_MARKER" "$FLUTTER_RUN_LOG" 2>/dev/null; do
        if ! kill -0 "$FLUTTER_PID" 2>/dev/null; then
          echo " failed."
          die "flutter run exited before becoming ready; see $FLUTTER_RUN_LOG"
        fi
        if [ "$SECONDS_WAITED" -ge "$FLUTTER_RUN_READY_TIMEOUT" ]; then
          echo " timed out."
          die "flutter run did not become ready within ${FLUTTER_RUN_READY_TIMEOUT}s; see $FLUTTER_RUN_LOG"
        fi
        printf '.'; sleep 3
        SECONDS_WAITED=$((SECONDS_WAITED + 3))
      done
      echo " ready."
      echo "App running (pid $FLUTTER_PID). Logs: $FLUTTER_RUN_LOG"
    else
      echo "Launching app via flutter run..."
      # shellcheck disable=SC2086
      flutter run $SECRETS_FLAG || true
    fi
  fi
}

case "$CMD" in
  stop)    do_stop ;;
  start)   do_start ;;
  restart) do_stop; do_start ;;
  *) die "Unknown command '$CMD'. Use: start | stop | restart" ;;
esac
