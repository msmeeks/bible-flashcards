#!/usr/bin/env bash
# Usage: scripts/smoke_test.sh
#
# Runs the full smoke suite:
#   1. `flutter test` — unit/widget test suite
#   2. Wipes and boots the project emulator (via scripts/emulator.sh)
#   3. Runs integration_test/app_smoke_test.dart on it: add a verse, mark it
#      memorized (verse of the week), confirm Home reflects that, complete a
#      test session end-to-end.
#
# The emulator is wiped before running so the integration test starts from a
# clean, reproducible app state — any existing data on the AVD is discarded.

set -euo pipefail

cd "$(dirname "$0")/.."

ADB="/opt/homebrew/share/android-commandlinetools/platform-tools/adb"

echo "==> Running unit/widget test suite (flutter test)"
flutter test

echo "==> Wiping and booting emulator for integration test"
bash scripts/emulator.sh restart --wipe --no-app

DEVICE_ID="$("$ADB" devices | awk '/emulator.*device$/ {print $1; exit}')"
if [ -z "$DEVICE_ID" ]; then
  echo "ERROR: no emulator device found after boot." >&2
  exit 1
fi
echo "==> Using device: $DEVICE_ID"

SECRETS_FLAG=""
if [ -f secrets.local ]; then
  SECRETS_FLAG="--dart-define-from-file=secrets.local"
fi

echo "==> Running integration_test/app_smoke_test.dart"
# shellcheck disable=SC2086
flutter test integration_test/app_smoke_test.dart -d "$DEVICE_ID" $SECRETS_FLAG

echo "==> Smoke test passed."
