#!/usr/bin/env bash
# Usage: scripts/emulator.sh [start|stop|restart] [--wipe] [--no-app]
#
# start    — boot the AVD and run the Flutter app (default)
# stop     — kill the running emulator
# restart  — stop then start
#
# --wipe   — cold-boot with full data wipe (fixes "Activity class not found" corruption)
# --no-app — boot the emulator only; skip `flutter run`

set -euo pipefail

AVD_NAME="bible_flashcards_pixel9"
EMULATOR_BIN="/opt/homebrew/share/android-commandlinetools/emulator/emulator"
ADB="/opt/homebrew/share/android-commandlinetools/platform-tools/adb"

CMD="${1:-start}"
WIPE=false
RUN_APP=true

for arg in "$@"; do
  case "$arg" in
    --wipe)   WIPE=true ;;
    --no-app) RUN_APP=false ;;
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
    echo "Launching app via flutter run..."
    cd "$(dirname "$0")/.."
    SECRETS_FLAG=""
    if [ -f secrets.local ]; then
      SECRETS_FLAG="--dart-define-from-file=secrets.local"
    fi
    # shellcheck disable=SC2086
    flutter run $SECRETS_FLAG || true
  fi
}

case "$CMD" in
  stop)    do_stop ;;
  start)   do_start ;;
  restart) do_stop; do_start ;;
  *) die "Unknown command '$CMD'. Use: start | stop | restart" ;;
esac
