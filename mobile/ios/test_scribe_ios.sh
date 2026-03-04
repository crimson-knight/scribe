#!/usr/bin/env bash
set -euo pipefail

# ── Configuration ──
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
SCRIBE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCHEME="Scribe"
SDK="iphonesimulator"
# Try iPhone 16 Pro first, fall back to any available
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17 Pro}"
BUNDLE_ID="com.crimsonknight.Scribe"
BUILD_DIR="$PROJECT_DIR/build/e2e"

echo "==================================================="
echo "  Scribe iOS E2E Test"
echo "==================================================="

# ── Step 1: Build Crystal bridge ──
echo ""
echo ">> Step 1: Building Crystal bridge library..."
cd "$SCRIBE_ROOT"
if [[ -x ./mobile/ios/build_crystal_lib.sh ]]; then
    ./mobile/ios/build_crystal_lib.sh simulator
else
    echo "   WARNING: build_crystal_lib.sh not found -- skipping Crystal build"
fi

# ── Step 2: Generate Xcode project ──
echo ""
echo ">> Step 2: Generating Xcode project..."
cd "$PROJECT_DIR"
xcodegen generate --quiet 2>/dev/null || xcodegen generate

# ── Step 3: Build app for simulator ──
echo ""
echo ">> Step 3: Building app..."
xcodebuild build-for-testing \
    -project Scribe.xcodeproj \
    -scheme "$SCHEME" \
    -sdk "$SDK" \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
    -derivedDataPath "$BUILD_DIR" \
    -quiet 2>/dev/null || \
xcodebuild build-for-testing \
    -project Scribe.xcodeproj \
    -scheme "$SCHEME" \
    -sdk "$SDK" \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
    -derivedDataPath "$BUILD_DIR" 2>&1 | tail -5

echo "   Build succeeded"

# ── Step 4: Boot simulator ──
echo ""
echo ">> Step 4: Ensuring simulator is booted..."

# Find a suitable simulator UDID using pure shell parsing
DEVICE_UDID=""
FOUND_NAME=""

# Try to find the preferred simulator, fall back to any available iPhone
while IFS= read -r line; do
    # Lines with device info look like:
    #   iPhone 16 Pro (UDID) (Booted|Shutdown)
    if echo "$line" | grep -qE '^\s+.+\([0-9A-F-]+\)'; then
        # Extract name, UDID, and state
        name=$(echo "$line" | sed -E 's/^\s+(.+) \([0-9A-F-]+\).*/\1/')
        udid=$(echo "$line" | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')
        # Skip unavailable devices
        if echo "$line" | grep -q "unavailable"; then
            continue
        fi
        # Prefer the configured simulator name
        if [[ "$name" == "$SIMULATOR_NAME" ]]; then
            DEVICE_UDID="$udid"
            FOUND_NAME="$name"
            break
        fi
        # Fall back to first available iPhone
        if [[ -z "$DEVICE_UDID" ]] && echo "$name" | grep -q "iPhone"; then
            DEVICE_UDID="$udid"
            FOUND_NAME="$name"
        fi
    fi
done < <(xcrun simctl list devices available 2>/dev/null)

if [[ -z "$DEVICE_UDID" ]]; then
    echo "   FAIL: No available iOS simulator found"
    exit 1
fi

# Update SIMULATOR_NAME if we fell back
if [[ "$FOUND_NAME" != "$SIMULATOR_NAME" ]]; then
    echo "   NOTE: $SIMULATOR_NAME not found, falling back to $FOUND_NAME"
    SIMULATOR_NAME="$FOUND_NAME"
fi

echo "   Using simulator: $SIMULATOR_NAME ($DEVICE_UDID)"

# Check boot state
BOOT_STATE=$(xcrun simctl list devices 2>/dev/null | grep "$DEVICE_UDID" | sed -E 's/.*\((Booted|Shutdown)\).*/\1/' | head -1)

if [[ "$BOOT_STATE" != "Booted" ]]; then
    xcrun simctl boot "$DEVICE_UDID" 2>/dev/null || true
    echo "   Waiting for simulator to boot..."
    sleep 5
fi
echo "   Simulator booted"

# ── Step 5: Grant microphone permission ──
echo ""
echo ">> Step 5: Granting microphone permission..."
xcrun simctl privacy "$DEVICE_UDID" grant microphone "$BUNDLE_ID" 2>/dev/null || true
echo "   Microphone permission granted"

# ── Step 6: Run XCUITests ──
echo ""
echo ">> Step 6: Running XCUITests..."
echo ""

TEST_RESULT=0
xcodebuild test-without-building \
    -project Scribe.xcodeproj \
    -scheme "$SCHEME" \
    -sdk "$SDK" \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
    -derivedDataPath "$BUILD_DIR" \
    -only-testing:ScribeUITests \
    2>&1 | tee /tmp/scribe_ios_test_output.txt | grep -E "(Test Case|Test Suite|Executed|PASS|FAIL)" || TEST_RESULT=$?

echo ""
echo "==================================================="
if grep -q "TEST SUCCEEDED" /tmp/scribe_ios_test_output.txt 2>/dev/null; then
    echo "  PASS: iOS E2E -- ALL TESTS PASSED"
    echo "==================================================="

    # ── FSDD Story References ──
    echo ""
    echo "FSDD Coverage:"
    echo "  7.1 Record Voice Memo (iOS) -- record button, timer, status"
    echo "  7.3 Browse Recordings (iOS) -- empty state, navigation"
    echo "  7.5 Settings (iOS) -- screen load, save location picker"
    echo "  Navigation -- all 3 tabs accessible"
    exit 0
else
    echo "  FAIL: iOS E2E -- TESTS FAILED"
    echo "==================================================="
    echo ""
    echo "Failures:"
    grep -A 2 "failed" /tmp/scribe_ios_test_output.txt 2>/dev/null || echo "  See /tmp/scribe_ios_test_output.txt for details"
    exit 1
fi
