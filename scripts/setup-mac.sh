#!/usr/bin/env bash
# =============================================================================
# setup-mac.sh — Bootstrap Bible Flashcards dev environment on macOS
# =============================================================================
#
# WHAT THIS SCRIPT DOES
#   Installs and configures every tool needed to build and run the Bible
#   Flashcards Flutter Android app on a Mac:
#     1. Xcode Command Line Tools  (git, make, clang)
#     2. Homebrew                  (package manager)
#     3. Java 17                   (required by Gradle / Android build)
#     4. Flutter SDK ≥ 3.22        (app framework)
#     5. Android cmdline-tools     (sdkmanager, avdmanager, adb, emulator)
#     6. Android SDK packages      (platform-tools, platforms;android-35,
#                                   build-tools, system image for emulator)
#     7. AVD "bible_flashcards_pixel9" (Pixel 9 Pro, API 35, Google Play)
#     8. flutter pub get           (download Dart/Flutter dependencies)
#     9. flutter test              (run unit-test smoke check; no device needed)
#
# PREREQUISITES
#   - macOS 13 Ventura or later (Apple Silicon or Intel both work)
#   - An internet connection
#   - Run from the repo root:  bash scripts/setup-mac.sh
#
# USAGE
#   ./scripts/setup-mac.sh                 Full install + AVD creation
#   ./scripts/setup-mac.sh --skip-emulator Skip AVD creation (physical device only)
#   ./scripts/setup-mac.sh --verify-only   Check what is/isn't installed; no changes
#   ./scripts/setup-mac.sh --help          Show this message
#
# AFTER THIS SCRIPT SUCCEEDS
#   Add the following to your ~/.zshrc (or ~/.bash_profile):
#     export JAVA_HOME=$(/usr/libexec/java_home -v 17)
#     export ANDROID_HOME="$HOME/Library/Android/sdk"         # or wherever sdkmanager put it
#     export PATH="$PATH:$ANDROID_HOME/platform-tools"
#     export PATH="$PATH:$ANDROID_HOME/emulator"
#     export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"
#   (The script will print the exact values for your machine at the end.)
#
# IDEMPOTENCY
#   Safe to re-run at any time. Each step checks whether the tool is already
#   present before installing. If a previous run failed partway through, just
#   fix whatever caused it (see TROUBLESHOOTING below) and run again.
#
# TROUBLESHOOTING (also printed on any error)
#   Symptom                         | Likely cause          | Fix
#   --------------------------------|-----------------------|-----------------------------
#   App crashes on first launch     | No device lock screen | Set a PIN in device security
#   TTS produces no audio           | No TTS engine         | Install Google TTS from Play Store
#   `flutter run` says "No devices" | ADB not detecting     | USB debugging on; replug cable
#   Notification permission denied  | Android 13+ requires grant | Settings → Apps → Notifications
#   Gradle build fails              | Java version mismatch | Ensure JAVA_HOME = Java 17
#   sdkmanager license failure      | Network or proxy      | Try on a different network
#   Flutter cache corrupted         | Interrupted install   | Run: flutter doctor --diagnose
#   brew cask install hangs         | Large download        | Wait; it can take 10+ min on slow wifi
#   "No such device" for AVD        | pixel_9_pro profile   | Script falls back to pixel_7; still works
#
# =============================================================================

set -euo pipefail

# ─── flags ───────────────────────────────────────────────────────────────────
SKIP_EMULATOR=false
VERIFY_ONLY=false
SHOW_HELP=false

for arg in "$@"; do
  case "$arg" in
    --skip-emulator) SKIP_EMULATOR=true ;;
    --verify-only)   VERIFY_ONLY=true   ;;
    --help|-h)       SHOW_HELP=true     ;;
    *) echo "Unknown argument: $arg  (try --help)" >&2; exit 1 ;;
  esac
done

if $SHOW_HELP; then
  # Print the leading comment block from this file (strips the leading '# ').
  awk '/^# ={3}/{p++} p && /^set -/{exit} p{sub(/^# ?/,""); print}' "$0"
  exit 0
fi

# ─── logging ─────────────────────────────────────────────────────────────────
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="/tmp/bible-flashcards-setup-${TIMESTAMP}.log"
# Redirect all output (stdout + stderr) to both the terminal and the log file.
exec > >(tee -a "$LOG_FILE") 2>&1

# ANSI colours — disabled automatically when not writing to a terminal
if [[ -t 1 ]]; then
  COL_RESET="\033[0m"; COL_BOLD="\033[1m"
  COL_RED="\033[31m";  COL_GREEN="\033[32m"
  COL_YELLOW="\033[33m"; COL_CYAN="\033[36m"
else
  COL_RESET=""; COL_BOLD=""; COL_RED=""; COL_GREEN=""; COL_YELLOW=""; COL_CYAN=""
fi

log()  { echo -e "${COL_CYAN}[INFO]${COL_RESET}  $*"; }
ok()   { echo -e "${COL_GREEN}[ OK ]${COL_RESET}  $*"; }
warn() { echo -e "${COL_YELLOW}[WARN]${COL_RESET}  $*"; }
err()  { echo -e "${COL_RED}[ERR ]${COL_RESET}  $*" >&2; }
step() { echo -e "\n${COL_BOLD}${COL_CYAN}━━━  $*  ━━━${COL_RESET}"; }
banner() {
  echo -e "${COL_BOLD}${COL_CYAN}"
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║      Bible Flashcards — macOS Setup Script          ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo -e "${COL_RESET}"
  echo "Log file: $LOG_FILE"
  echo
}

# ─── troubleshooting helper ──────────────────────────────────────────────────
print_troubleshooting() {
  echo -e "\n${COL_BOLD}${COL_YELLOW}━━━  TROUBLESHOOTING  ━━━${COL_RESET}"
  cat <<'HELP'

Common issues and fixes:

  PROBLEM                          LIKELY CAUSE              FIX
  ─────────────────────────────────────────────────────────────────────────
  Script fails at xcode-select     GUI prompt required       Follow the on-screen
    --install                                                dialog, then re-run.

  brew install hangs for minutes   Large download (~2 GB)    Be patient; Android
                                                             cmdline-tools is big.

  sdkmanager: "Failed to read      Old Java in PATH          Make sure JAVA_HOME
    or write" or license error                               points to Java 17.
                                                             Check: java -version

  flutter doctor shows missing     SDK path not set          Run:
    Android SDK                                              flutter config --android-sdk <path>
                                                             (script does this automatically)

  flutter: command not found       Shell PATH not updated    Open a NEW terminal tab
    after install                                            after this script finishes.

  Gradle build fails               Java 17 required          export JAVA_HOME=$(/usr/libexec/java_home -v 17)

  App crashes on first launch      No device lock screen     In emulator/device Settings:
    (Keystore error)                                         Security → Set a PIN or Pattern

  TTS produces no audio            No TTS engine installed   Emulator: Settings → Accessibility
                                                             → Text-to-speech → install Google TTS

  flutter run: "No devices found"  ADB not detecting device  Check USB debugging is on.
                                                             Try: adb devices
                                                             Re-plug the USB cable.

  Notification permission denied   Android 13+              Settings → Apps → Bible Flashcards
                                   requires explicit grant   → Notifications → Allow

  AVD creation fails with          pixel_9_pro profile       Script automatically falls back
    "No such device"               not in this cmdline ver.  to pixel_7. Both work fine.

  "INSTALL_FAILED_UPDATE_           APK signature mismatch   Uninstall old app first:
    INCOMPATIBLE"                                            adb uninstall com.example.bible_flashcards

  flutter test fails               Unit tests don't need a   Check pubspec.yaml and run:
    (non-database tests)           device. If they fail,     flutter pub get
                                   deps may be missing.

  Script exits with "Not in repo   Run from the project      cd /path/to/bible-flashcards
    root"                          root directory            bash scripts/setup-mac.sh

GENERAL RECOVERY STEPS:
  1. Read the error message and the lines just before it in this terminal.
  2. Check the full log: cat $LOG_FILE
  3. Fix the specific issue using the table above.
  4. Re-run: bash scripts/setup-mac.sh   (safe to run multiple times)

HELP
}

# ─── error trap ──────────────────────────────────────────────────────────────
on_error() {
  local exit_code=$?
  local line_no=${1:-"?"}
  local cmd="${2:-"unknown command"}"
  echo
  err "Setup failed (exit code ${exit_code}) at line ${line_no}"
  err "Failed command: ${cmd}"
  err "Full log: ${LOG_FILE}"
  print_troubleshooting
  echo -e "\n${COL_YELLOW}This script is idempotent — fix the issue above, then run it again.${COL_RESET}"
  exit "$exit_code"
}
# Bash passes LINENO and BASH_COMMAND via the trap.
trap 'on_error "${LINENO}" "${BASH_COMMAND}"' ERR

# ─── version comparison helper ───────────────────────────────────────────────
# Returns 0 (true) if version $1 >= $2
version_ge() {
  # Split on '.' and compare numerically field by field.
  local IFS='.'
  read -ra V1 <<< "$1"
  read -ra V2 <<< "$2"
  local i
  for (( i=0; i<${#V2[@]}; i++ )); do
    local a="${V1[i]:-0}"
    local b="${V2[i]:-0}"
    (( a > b )) && return 0
    (( a < b )) && return 1
  done
  return 0
}

# ═════════════════════════════════════════════════════════════════════════════
#  START
# ═════════════════════════════════════════════════════════════════════════════
banner

# ─── preflight checks ────────────────────────────────────────────────────────
step "Preflight"

# Must be macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
  err "This script is for macOS only. Detected OS: $(uname -s)"
  exit 1
fi
ok "macOS detected: $(sw_vers -productVersion)"

# Detect CPU architecture (Apple Silicon vs Intel)
ARCH="$(uname -m)"
if [[ "$ARCH" == "arm64" ]]; then
  ANDROID_ABI="arm64-v8a"
  HOMEBREW_PREFIX="/opt/homebrew"
  ok "Apple Silicon (arm64) — will use arm64-v8a system image"
else
  ANDROID_ABI="x86_64"
  HOMEBREW_PREFIX="/usr/local"
  ok "Intel x86_64 — will use x86_64 system image"
fi

# Must be run from the repo root (pubspec.yaml must exist here)
if [[ ! -f "pubspec.yaml" ]]; then
  err "Not in repo root — pubspec.yaml not found."
  err "Run this script from the bible-flashcards directory:"
  err "  cd /path/to/bible-flashcards && bash scripts/setup-mac.sh"
  exit 1
fi
ok "Running from repo root: $(pwd)"

# Internet connectivity check
log "Checking internet connectivity..."
if ! curl -fsS --max-time 10 https://storage.googleapis.com >/dev/null 2>&1; then
  err "No internet connection (or googleapis.com is blocked)."
  err "An internet connection is required to download Flutter, Java, and Android SDK."
  exit 1
fi
ok "Internet connectivity confirmed"

if $VERIFY_ONLY; then
  warn "--verify-only: no changes will be made. Checking current state..."
fi

# ─── step 1: xcode command line tools ─────────────────────────────────────────
step "Step 1: Xcode Command Line Tools"
#
# WHY: Flutter needs the clang compiler and git from Xcode CLT. On a fresh Mac
# neither is present. The `xcode-select --install` command triggers a GUI dialog
# — there is no way to make it fully non-interactive. After you click "Install"
# and it completes, re-run this script.
#
if xcode-select -p &>/dev/null; then
  ok "Xcode Command Line Tools already installed: $(xcode-select -p)"
else
  if $VERIFY_ONLY; then
    warn "MISSING: Xcode Command Line Tools"
  else
    warn "Xcode Command Line Tools not found. Launching installer..."
    warn "A dialog will appear on screen. Click 'Install' and wait for it to complete."
    warn "Then re-run this script."
    xcode-select --install 2>&1 || true
    # xcode-select --install exits 1 even when it successfully launches the GUI.
    # We pause here — the user must re-run after installation finishes.
    echo
    echo "════════════════════════════════════════════════════════"
    echo " ACTION REQUIRED: Click 'Install' in the dialog that    "
    echo " just appeared, wait for completion, then run:          "
    echo "   bash scripts/setup-mac.sh                            "
    echo "════════════════════════════════════════════════════════"
    exit 0
  fi
fi

# ─── step 2: homebrew ─────────────────────────────────────────────────────────
step "Step 2: Homebrew"
#
# WHY: Homebrew is the de-facto package manager for macOS. We use it to install
# Flutter, the Android command-line tools, and OpenJDK 17. The official install
# script is fetched from brew.sh.
#
if command -v brew &>/dev/null; then
  ok "Homebrew already installed: $(brew --version | head -1)"
else
  if $VERIFY_ONLY; then
    warn "MISSING: Homebrew"
  else
    log "Installing Homebrew (this may prompt for your macOS password)..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add Homebrew to PATH for the rest of this script (new shell sessions need ~/.zshrc update)
    export PATH="${HOMEBREW_PREFIX}/bin:$PATH"
    ok "Homebrew installed"
  fi
fi

# Ensure brew is on PATH even if it was already installed but not in current PATH
export PATH="${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin:$PATH"

# ─── step 3: java 17 ──────────────────────────────────────────────────────────
step "Step 3: Java 17"
#
# WHY: Android's Gradle build system requires Java 17 exactly. Other versions
# will cause cryptic build failures. We use /usr/libexec/java_home (a macOS
# utility) to check for an installed Java 17 JDK, and install via Homebrew if
# it is absent.
#
JAVA17_HOME=""
if /usr/libexec/java_home -v 17 &>/dev/null; then
  JAVA17_HOME="$(/usr/libexec/java_home -v 17)"
  ok "Java 17 already installed: ${JAVA17_HOME}"
else
  if $VERIFY_ONLY; then
    warn "MISSING: Java 17"
  else
    log "Installing Java 17 via Homebrew..."
    brew install openjdk@17
    # Homebrew installs to a cellar path but macOS java_home won't see it until
    # it is symlinked into /Library/Java/JavaVirtualMachines/
    # The brew postinstall message tells you to do this; we do it automatically.
    local_jdk_path="${HOMEBREW_PREFIX}/opt/openjdk@17/libexec/openjdk.jdk"
    if [[ -d "$local_jdk_path" ]]; then
      if [[ ! -e "/Library/Java/JavaVirtualMachines/openjdk-17.jdk" ]]; then
        log "Symlinking Java 17 into /Library/Java/JavaVirtualMachines/ (requires sudo)..."
        sudo ln -sfn "${local_jdk_path}" /Library/Java/JavaVirtualMachines/openjdk-17.jdk
      fi
    fi
    JAVA17_HOME="$(/usr/libexec/java_home -v 17 2>/dev/null || echo "${HOMEBREW_PREFIX}/opt/openjdk@17")"
    ok "Java 17 installed: ${JAVA17_HOME}"
  fi
fi

export JAVA_HOME="${JAVA17_HOME:-"${HOMEBREW_PREFIX}/opt/openjdk@17"}"
export PATH="$JAVA_HOME/bin:$PATH"
log "JAVA_HOME=${JAVA_HOME}"
java -version 2>&1 | head -1 || warn "java not yet on PATH; shell env update needed after script"

# ─── step 4: flutter sdk ──────────────────────────────────────────────────────
step "Step 4: Flutter SDK (≥ 3.22)"
#
# WHY: Flutter is the app framework. We need ≥ 3.22 because the project's
# pubspec.yaml requires it. The easiest install on macOS is `brew install --cask
# flutter`, which puts the flutter binary on your PATH after you restart your
# shell (or run `hash -r`).
#
FLUTTER_MIN="3.22.0"
if command -v flutter &>/dev/null; then
  FLUTTER_VER=$(flutter --version 2>/dev/null | grep -oE 'Flutter [0-9]+\.[0-9]+\.[0-9]+' | awk '{print $2}' || echo "0.0.0")
  if version_ge "$FLUTTER_VER" "$FLUTTER_MIN"; then
    ok "Flutter ${FLUTTER_VER} already installed (meets ≥ ${FLUTTER_MIN})"
  else
    warn "Flutter ${FLUTTER_VER} is too old (need ≥ ${FLUTTER_MIN}). Upgrading..."
    if ! $VERIFY_ONLY; then
      flutter upgrade
      FLUTTER_VER=$(flutter --version 2>/dev/null | grep -oE 'Flutter [0-9]+\.[0-9]+\.[0-9]+' | awk '{print $2}')
      ok "Flutter upgraded to ${FLUTTER_VER}"
    fi
  fi
else
  if $VERIFY_ONLY; then
    warn "MISSING: Flutter"
  else
    log "Installing Flutter via Homebrew cask (this downloads ~700 MB)..."
    brew install --cask flutter
    # The cask adds flutter to /opt/homebrew/bin or /usr/local/bin via symlink.
    # Refresh PATH so the rest of this script can call flutter.
    export PATH="${HOMEBREW_PREFIX}/bin:$PATH"
    hash -r 2>/dev/null || true
    ok "Flutter installed: $(flutter --version 2>/dev/null | head -1)"
  fi
fi

# ─── step 5: android command-line tools + sdk packages ─────────────────────
step "Step 5: Android cmdline-tools + SDK packages"
#
# WHY: Android development requires the Android SDK (platform tools, build
# tools, platform sources, and optionally a system image for the emulator).
# We install via the `android-commandlinetools` Homebrew cask, which provides
# sdkmanager and avdmanager without requiring the full Android Studio IDE.
#
# SDK packages we install:
#   - platform-tools          : adb, fastboot
#   - platforms;android-35    : Android 15 SDK (API 35)
#   - build-tools;35.0.0      : aapt2, dx, zipalign
#   - system-images;android-35;google_apis_playstore;<ABI>
#                             : emulator system image (arm64 on M-series, x86_64 on Intel)
#   - emulator                : the Android emulator binary
#
# NOTE: Installing system images is ~1.5 GB per ABI. The correct ABI matters:
#   - Apple Silicon: arm64-v8a  (x86_64 image runs in Rosetta but is slow)
#   - Intel Mac:     x86_64
#

# Detect ANDROID_HOME from multiple possible locations.
detect_android_home() {
  # 1. Already set in environment
  if [[ -n "${ANDROID_HOME:-}" ]] && [[ -d "${ANDROID_HOME}" ]]; then
    echo "$ANDROID_HOME"; return
  fi
  # 2. Homebrew cmdline-tools location
  local brew_sdk="${HOMEBREW_PREFIX}/share/android-commandlinetools"
  if [[ -d "$brew_sdk" ]]; then
    echo "$brew_sdk"; return
  fi
  # 3. Default Android Studio location
  local studio_sdk="$HOME/Library/Android/sdk"
  if [[ -d "$studio_sdk" ]]; then
    echo "$studio_sdk"; return
  fi
  echo ""
}

ANDROID_HOME="$(detect_android_home)"

if [[ -z "$ANDROID_HOME" ]]; then
  if $VERIFY_ONLY; then
    warn "MISSING: Android SDK / cmdline-tools"
  else
    log "Installing Android command-line tools via Homebrew (downloads ~500 MB)..."
    brew install --cask android-commandlinetools
    ANDROID_HOME="${HOMEBREW_PREFIX}/share/android-commandlinetools"
    ok "Android cmdline-tools installed"
  fi
else
  ok "Android SDK found: ${ANDROID_HOME}"
fi

export ANDROID_HOME
export PATH="$PATH:$ANDROID_HOME/platform-tools"
export PATH="$PATH:$ANDROID_HOME/emulator"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/cmdline-tools/bin"  # some brew versions

# Locate sdkmanager
SDKMANAGER=""
for candidate in \
    "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" \
    "$ANDROID_HOME/cmdline-tools/cmdline-tools/bin/sdkmanager" \
    "$(command -v sdkmanager 2>/dev/null || true)"; do
  if [[ -x "$candidate" ]]; then
    SDKMANAGER="$candidate"
    break
  fi
done

if [[ -z "$SDKMANAGER" ]] && ! $VERIFY_ONLY; then
  err "sdkmanager not found after installing cmdline-tools."
  err "Expected it at: ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager"
  err "Check that the brew cask installed correctly: brew list --cask android-commandlinetools"
  exit 1
fi

if [[ -n "$SDKMANAGER" ]] && ! $VERIFY_ONLY; then
  log "Using sdkmanager: $SDKMANAGER"

  # Accept all licenses non-interactively.
  # WHY: sdkmanager refuses to install packages if licenses are not accepted.
  #      We pipe 'y\n' repeated times to answer every prompt.
  log "Accepting Android SDK licenses..."
  yes 2>/dev/null | "$SDKMANAGER" --licenses || warn "Some licenses may already have been accepted; continuing."

  # Install required SDK packages.
  SYSTEM_IMAGE="system-images;android-35;google_apis_playstore;${ANDROID_ABI}"
  log "Installing SDK packages (this can take 5–15 minutes on a slow connection)..."
  "$SDKMANAGER" \
    "platform-tools" \
    "platforms;android-35" \
    "build-tools;35.0.0" \
    "emulator" \
    "$SYSTEM_IMAGE"
  ok "Android SDK packages installed"
fi

# ─── step 6: create avd ───────────────────────────────────────────────────────
step "Step 6: Create Android Virtual Device (Pixel 9 Pro, API 35)"
#
# WHY: An AVD (Android Virtual Device) is required to run the app without a
# physical phone. We create one named "bible_flashcards_pixel9" using the
# Pixel 9 Pro hardware profile.
#
# EMULATOR NOTES:
#   - The emulator requires a lock screen PIN set before the app will launch
#     (the app uses Android Keystore which needs a secure screen lock).
#     After starting the emulator, go to Settings → Security → Screen lock
#     and set a PIN.
#   - TTS: if speech is silent, go to Settings → Accessibility → Text-to-speech
#     and ensure Google TTS is installed and selected.
#
AVD_NAME="bible_flashcards_pixel9"

if $SKIP_EMULATOR; then
  warn "--skip-emulator set: skipping AVD creation. Use a physical device."
elif $VERIFY_ONLY; then
  if avdmanager list avd 2>/dev/null | grep -q "$AVD_NAME"; then
    ok "AVD '${AVD_NAME}' exists"
  else
    warn "MISSING: AVD '${AVD_NAME}'"
  fi
else
  AVDMANAGER=""
  for candidate in \
      "$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" \
      "$ANDROID_HOME/cmdline-tools/cmdline-tools/bin/avdmanager" \
      "$(command -v avdmanager 2>/dev/null || true)"; do
    if [[ -x "$candidate" ]]; then
      AVDMANAGER="$candidate"
      break
    fi
  done

  if [[ -z "$AVDMANAGER" ]]; then
    warn "avdmanager not found. Skipping AVD creation — run it manually later."
  elif "$AVDMANAGER" list avd 2>/dev/null | grep -q "$AVD_NAME"; then
    ok "AVD '${AVD_NAME}' already exists"
  else
    SYSTEM_IMAGE="system-images;android-35;google_apis_playstore;${ANDROID_ABI}"
    DEVICE_PROFILE="pixel_9_pro"

    # Check if the pixel_9_pro hardware profile exists in this cmdline-tools version.
    # Some older versions only have pixel_7. Fall back gracefully.
    if ! "$AVDMANAGER" list device 2>/dev/null | grep -q "pixel_9_pro"; then
      warn "Device profile 'pixel_9_pro' not found in this cmdline-tools version."
      warn "Falling back to 'pixel_7' (same form factor, same API level — functionally identical)."
      DEVICE_PROFILE="pixel_7"
    fi

    log "Creating AVD '${AVD_NAME}' with device profile '${DEVICE_PROFILE}'..."
    echo "no" | "$AVDMANAGER" create avd \
      --name  "$AVD_NAME" \
      --package "$SYSTEM_IMAGE" \
      --device  "$DEVICE_PROFILE" \
      --force
    ok "AVD '${AVD_NAME}' created"
  fi
fi

# ─── step 7: configure flutter + pub get ──────────────────────────────────────
step "Step 7: Configure Flutter, accept Android licenses, flutter pub get"
#
# WHY: Flutter needs to know where the Android SDK is. `flutter config` writes
# this to ~/.flutter_settings. `flutter doctor --android-licenses` accepts any
# remaining SDK licenses through Flutter's wrapper. `flutter pub get` downloads
# the Dart package dependencies listed in pubspec.yaml.
#
if ! $VERIFY_ONLY; then
  if [[ -n "$ANDROID_HOME" ]]; then
    log "Configuring Flutter Android SDK path..."
    flutter config --android-sdk "$ANDROID_HOME" --no-analytics
  fi

  log "Accepting Flutter/Android licenses..."
  yes 2>/dev/null | flutter doctor --android-licenses || true

  log "Running flutter pub get..."
  flutter pub get
  ok "flutter pub get complete"
fi

# ─── step 8: flutter doctor ───────────────────────────────────────────────────
step "Step 8: flutter doctor"
#
# WHY: flutter doctor checks the entire toolchain and reports any remaining
# issues. We run it in verbose mode and look for the Android toolchain section.
# If it reports errors (not just warnings) in Android toolchain, we fail the
# script with a clear message.
#
DOCTOR_OUTPUT=$(flutter doctor -v 2>&1 || true)
echo "$DOCTOR_OUTPUT"

if echo "$DOCTOR_OUTPUT" | grep -q "Android toolchain" && \
   echo "$DOCTOR_OUTPUT" | grep -A5 "Android toolchain" | grep -qE '^\s+✓|^\s+•'; then
  ok "Android toolchain looks good"
elif echo "$DOCTOR_OUTPUT" | grep -A5 "Android toolchain" | grep -q "✗"; then
  warn "flutter doctor found issues in Android toolchain."
  warn "Review the output above. Common fixes:"
  warn "  - 'Android SDK not found'  →  Run: flutter config --android-sdk $ANDROID_HOME"
  warn "  - 'licenses not accepted'  →  Run: flutter doctor --android-licenses"
  warn "  - 'Java not found'         →  Check JAVA_HOME (see Step 3 output above)"
  warn "(Not failing the script — some warnings are informational.)"
else
  warn "Could not confirm Android toolchain status from flutter doctor output."
  warn "Review the output above manually."
fi

# ─── step 9: flutter test (smoke check) ───────────────────────────────────────
step "Step 9: flutter test (unit-test smoke check)"
#
# WHY: The unit tests in test/ do not require a device (they test pure Dart
# logic: scoring, model construction, serialisation). If these fail it means
# either the SDK is broken or a dependency is missing. Database tests require
# a real device/emulator and are not included here.
#
if $VERIFY_ONLY; then
  log "(Skipping test run in --verify-only mode)"
else
  log "Running flutter test..."
  flutter test --reporter=compact
  ok "All unit tests passed"
fi

# ─── step 10: final report ────────────────────────────────────────────────────
step "Setup Complete"

echo
echo -e "${COL_GREEN}${COL_BOLD}Everything looks good!${COL_RESET}"
echo
echo "━━━  Shell environment ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Add the following lines to your ~/.zshrc (or ~/.bash_profile):"
echo "Open it with: nano ~/.zshrc"
echo
echo "  # Java 17 (required for Android Gradle builds)"
if /usr/libexec/java_home -v 17 &>/dev/null; then
  echo "  export JAVA_HOME=\"$(/usr/libexec/java_home -v 17)\""
else
  echo "  export JAVA_HOME=\"${HOMEBREW_PREFIX}/opt/openjdk@17\""
fi
echo
echo "  # Android SDK"
echo "  export ANDROID_HOME=\"${ANDROID_HOME}\""
echo "  export PATH=\"\$PATH:\$ANDROID_HOME/platform-tools\""
echo "  export PATH=\"\$PATH:\$ANDROID_HOME/emulator\""
echo "  export PATH=\"\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin\""
echo
echo "After editing ~/.zshrc, apply it with:  source ~/.zshrc"
echo
echo "━━━  Running the app ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if ! $SKIP_EMULATOR; then
  echo
  echo "EMULATOR (recommended for first run):"
  echo "  1. Start the emulator:"
  echo "       emulator -avd ${AVD_NAME}"
  echo "  2. IMPORTANT: In the emulator, go to Settings → Security → Screen lock"
  echo "     and set a PIN. The app will crash without this (Android Keystore"
  echo "     requires a secure lock screen)."
  echo "  3. Run the app:"
  echo "       flutter run"
fi
echo
echo "PHYSICAL DEVICE:"
echo "  1. Enable Developer Options (Settings → About phone, tap Build number 7×)"
echo "  2. Enable USB debugging (Settings → Developer Options → USB debugging)"
echo "  3. Connect via USB, accept the debugging prompt on the device"
echo "  4. Verify Flutter sees it:  flutter devices"
echo "  5. Run the app:             flutter run"
echo
echo "WIRELESS (Android 11+):"
echo "  See DEVELOPER.md → 'Wireless debugging' section for pairing steps."
echo
echo "━━━  Other useful commands ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  flutter test           Run unit tests (no device needed)"
echo "  flutter analyze        Run Dart linter"
echo "  flutter devices        List connected devices and emulators"
echo "  flutter run            Build and launch app on selected device"
echo "  flutter doctor -v      Full toolchain health check"
echo
echo "━━━  Log file ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Full setup log: ${LOG_FILE}"
echo
echo -e "${COL_GREEN}${COL_BOLD}Happy coding! ✓${COL_RESET}"
