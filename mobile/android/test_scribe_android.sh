#!/usr/bin/env bash
set -euo pipefail

# ── Configuration ──
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIBE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACKAGE="com.crimsonknight.scribe"
JAVA_HOME="${JAVA_HOME:-/opt/homebrew/Cellar/openjdk@17/17.0.18/libexec/openjdk.jdk/Contents/Home}"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-/opt/homebrew/share/android-commandlinetools}"
export JAVA_HOME ANDROID_SDK_ROOT

echo "==================================================="
echo "  Scribe Android E2E Test"
echo "==================================================="

# ── Step 1: Build Crystal library ──
echo ""
echo ">> Step 1: Building Crystal library for Android..."
cd "$SCRIBE_ROOT"
if [[ -x ./mobile/android/build_crystal_lib.sh ]]; then
    ./mobile/android/build_crystal_lib.sh
else
    echo "   WARNING: build_crystal_lib.sh not found -- skipping Crystal build"
fi

# ── Step 2: Build APKs ──
echo ""
echo ">> Step 2: Building debug + test APKs..."
cd "$SCRIPT_DIR"
./gradlew assembleDebug assembleDebugAndroidTest --quiet 2>/dev/null || \
    ./gradlew assembleDebug assembleDebugAndroidTest 2>&1 | tail -5
echo "   APKs built"

# ── Step 3: Check for emulator ──
echo ""
echo ">> Step 3: Checking for running emulator..."
ADB="${ANDROID_SDK_ROOT}/platform-tools/adb"
if [[ ! -x "$ADB" ]]; then
    ADB="adb"  # Fall back to PATH
fi

DEVICE=$("$ADB" devices 2>/dev/null | grep -E "emulator-|device$" | head -1 | awk '{print $1}') || true
if [[ -z "$DEVICE" ]]; then
    echo "   FAIL: No running Android emulator or device found."
    echo "   Start one with: emulator -avd <name>"
    echo "   Available AVDs:"
    "${ANDROID_SDK_ROOT}/emulator/emulator" -list-avds 2>/dev/null || echo "   (emulator not found in SDK)"
    exit 1
fi
echo "   Using device: $DEVICE"

# ── Step 4: Install APKs ──
echo ""
echo ">> Step 4: Installing APKs..."

DEBUG_APK="app/build/outputs/apk/debug/app-debug.apk"
TEST_APK="app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk"

if [[ ! -f "$DEBUG_APK" ]]; then
    echo "   FAIL: Debug APK not found at $DEBUG_APK"
    exit 1
fi
if [[ ! -f "$TEST_APK" ]]; then
    echo "   FAIL: Test APK not found at $TEST_APK"
    exit 1
fi

"$ADB" -s "$DEVICE" install -r "$DEBUG_APK" 2>&1 | tail -1
"$ADB" -s "$DEVICE" install -r "$TEST_APK" 2>&1 | tail -1
echo "   APKs installed"

# ── Step 5: Grant permissions ──
echo ""
echo ">> Step 5: Granting RECORD_AUDIO permission..."
"$ADB" -s "$DEVICE" shell pm grant "$PACKAGE" android.permission.RECORD_AUDIO 2>/dev/null || true
echo "   Permission granted"

# ── Step 6: Run Compose UI tests ──
echo ""
echo ">> Step 6: Running Compose UI tests..."
echo ""

TEST_OUTPUT=$("$ADB" -s "$DEVICE" shell am instrument -w \
    -e class "${PACKAGE}.ScribeUITests" \
    "${PACKAGE}.test/androidx.test.runner.AndroidJUnitRunner" 2>&1) || true

echo "$TEST_OUTPUT"

echo ""
echo "==================================================="
if echo "$TEST_OUTPUT" | grep -q "OK ("; then
    # Extract test count: "OK (9 tests)" -> "9"
    TESTS_RUN=$(echo "$TEST_OUTPUT" | grep -oE 'OK \([0-9]+' | grep -oE '[0-9]+')
    echo "  PASS: Android E2E -- ALL ${TESTS_RUN:-?} TESTS PASSED"
    echo "==================================================="

    echo ""
    echo "FSDD Coverage:"
    echo "  7.2 Record Voice Memo (Android) -- record button, timer, status"
    echo "  7.4 Browse Recordings (Android) -- empty state, navigation"
    echo "  7.6 Settings (Android) -- save location options"
    echo "  7.7 Audio Format (Android) -- WAV/M4A options"
    echo "  Navigation -- all 3 tabs accessible"
    exit 0
else
    echo "  FAIL: Android E2E -- TESTS FAILED"
    echo "==================================================="
    echo ""
    echo "See output above for failure details."
    exit 1
fi
