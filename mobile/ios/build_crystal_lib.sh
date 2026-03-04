#!/usr/bin/env bash
# build_crystal_lib.sh
#
# Build the Scribe Crystal bridge as a static library for iOS Simulator.
#
# Output: mobile/ios/build/libscribe.a
#
# Prerequisites
# -------------
#   - crystal-alpha installed:  brew install crimsonknight/crystal-alpha
#   - Xcode with iOS SDK:       xcode-select --install
#
# Usage
# -----
#   cd scribe && ./mobile/ios/build_crystal_lib.sh [simulator|device]
#
# What this script does
# ---------------------
#   1.  Compile C/ObjC native extensions from crystal-audio for iOS.
#   2.  Cross-compile shared/scribe_bridge.cr to an object file.
#   3.  Pack all .o files into libscribe.a with ar.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

CRYSTAL=${CRYSTAL:-crystal-alpha}
BUILD_TARGET="${1:-simulator}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIBE_ROOT="$(cd "$MOBILE_DIR/.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
OUTPUT_LIB="$BUILD_DIR/libscribe.a"
BRIDGE_SRC="$MOBILE_DIR/shared/scribe_bridge.cr"
BRIDGE_BASE="$BUILD_DIR/scribe_bridge"

# crystal-audio ext directory (shard or local checkout)
CRYSTAL_AUDIO_EXT=""
if [[ -d "$SCRIBE_ROOT/lib/crystal-audio/ext" ]]; then
    CRYSTAL_AUDIO_EXT="$SCRIBE_ROOT/lib/crystal-audio/ext"
elif [[ -d "$SCRIBE_ROOT/lib/crystal_audio/ext" ]]; then
    CRYSTAL_AUDIO_EXT="$SCRIBE_ROOT/lib/crystal_audio/ext"
elif [[ -d "$HOME/open_source_coding_projects/crystal-audio/ext" ]]; then
    CRYSTAL_AUDIO_EXT="$HOME/open_source_coding_projects/crystal-audio/ext"
fi

MIN_IOS_VER="16.0"

case "$BUILD_TARGET" in
    simulator)
        LLVM_TARGET="arm64-apple-ios-simulator"
        SDK_NAME="iphonesimulator"
        ;;
    device)
        LLVM_TARGET="arm64-apple-ios"
        SDK_NAME="iphoneos"
        ;;
    *)
        echo "Usage: $0 [simulator|device]"
        exit 1
        ;;
esac

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info()  { printf '\033[0;34m[build]\033[0m %s\n' "$*"; }
ok()    { printf '\033[0;32m[ok]\033[0m    %s\n' "$*"; }
fail()  { printf '\033[0;31m[fail]\033[0m  %s\n' "$*" >&2; exit 1; }

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------

require_cmd "$CRYSTAL"
require_cmd xcrun
require_cmd ar

[[ -z "$CRYSTAL_AUDIO_EXT" ]] && fail "Cannot find crystal-audio ext/ directory. Install crystal-audio shard or set path manually."

IOS_SDK=$(xcrun --sdk "$SDK_NAME" --show-sdk-path)
IOS_CLANG=$(xcrun --sdk "$SDK_NAME" --find clang)

CRYSTAL_VER=$("$CRYSTAL" --version 2>&1 | head -1)
info "Compiler       : $CRYSTAL_VER"
info "Target         : $LLVM_TARGET ($BUILD_TARGET)"
info "iOS SDK        : $IOS_SDK"
info "Scribe root    : $SCRIBE_ROOT"
info "Crystal audio  : $CRYSTAL_AUDIO_EXT"
info "Output         : $OUTPUT_LIB"
echo

mkdir -p "$BUILD_DIR"

# ---------------------------------------------------------------------------
# Step 1: Compile C/ObjC native extensions for iOS
#
# From crystal-audio ext/:
#   block_bridge.c       — ObjC block ABI shims (cross-platform)
#   objc_helpers.c       — typed objc_msgSend wrappers (cross-platform)
#   trace_helper.c       — os_log trace output for Crystal bridge
#   audio_write_helper.c — safe ExtAudioFileWrite wrapper (AudioBufferList on C stack)
#
# NOT compiled (macOS-only):
#   system_audio_tap.m  — ScreenCaptureKit
#   appkit_helpers.c    — AppKit
# ---------------------------------------------------------------------------

IOS_CFLAGS=(
    -arch arm64
    -isysroot "$IOS_SDK"
    -mios-simulator-version-min="$MIN_IOS_VER"
    -target "$LLVM_TARGET"
    -O2
    -fPIC
    -fobjc-arc
)

if [[ "$BUILD_TARGET" == "device" ]]; then
    IOS_CFLAGS=("${IOS_CFLAGS[@]//-mios-simulator-version-min=/-miphoneos-version-min=}")
fi

info "Compiling ext/block_bridge.c ..."
"$IOS_CLANG" "${IOS_CFLAGS[@]}" -c "$CRYSTAL_AUDIO_EXT/block_bridge.c" -o "$BUILD_DIR/block_bridge.o"
ok "block_bridge.o"

info "Compiling ext/objc_helpers.c ..."
"$IOS_CLANG" "${IOS_CFLAGS[@]}" -c "$CRYSTAL_AUDIO_EXT/objc_helpers.c" -o "$BUILD_DIR/objc_helpers.o"
ok "objc_helpers.o"

info "Compiling ext/trace_helper.c ..."
"$IOS_CLANG" "${IOS_CFLAGS[@]}" -c "$CRYSTAL_AUDIO_EXT/trace_helper.c" -o "$BUILD_DIR/trace_helper.o"
ok "trace_helper.o"

info "Compiling ext/audio_write_helper.c ..."
"$IOS_CLANG" "${IOS_CFLAGS[@]}" -c "$CRYSTAL_AUDIO_EXT/audio_write_helper.c" -o "$BUILD_DIR/audio_write_helper.o"
ok "audio_write_helper.o"

# Compile system_audio_tap_stub.c if it exists (provides no-op stubs for macOS-only APIs)
STUB_O=""
if [[ -f "$CRYSTAL_AUDIO_EXT/../samples/ios_app/system_audio_tap_stub.c" ]]; then
    info "Compiling system_audio_tap_stub.c ..."
    "$IOS_CLANG" "${IOS_CFLAGS[@]}" -c \
        "$CRYSTAL_AUDIO_EXT/../samples/ios_app/system_audio_tap_stub.c" \
        -o "$BUILD_DIR/system_audio_tap_stub.o"
    ok "system_audio_tap_stub.o"
    STUB_O="$BUILD_DIR/system_audio_tap_stub.o"
fi

# ---------------------------------------------------------------------------
# Step 2: Cross-compile the Crystal bridge
# ---------------------------------------------------------------------------

info "Cross-compiling shared/scribe_bridge.cr ..."
LINKER_FLAGS=$("$CRYSTAL" build \
    "$BRIDGE_SRC" \
    --cross-compile \
    --target "$LLVM_TARGET" \
    --define ios \
    --define shared \
    --release \
    -o "$BRIDGE_BASE")
ok "scribe_bridge.o"

# Localize _main to avoid conflict with Swift's @main entry point.
# Crystal unconditionally emits a main() even when overridden; we make it
# a local symbol so the linker ignores it.
info "Localizing _main symbol ..."
xcrun ld -r -arch arm64 "${BRIDGE_BASE}.o" -o "${BRIDGE_BASE}_patched.o" \
    -unexported_symbol _main
mv "${BRIDGE_BASE}_patched.o" "${BRIDGE_BASE}.o"
ok "_main localized"

echo
echo "Linker flags (for reference):"
echo "  $LINKER_FLAGS"
echo

# ---------------------------------------------------------------------------
# Step 3: Pack into a static library
# ---------------------------------------------------------------------------

info "Creating static library ..."
rm -f "$OUTPUT_LIB"

OBJ_FILES=(
    "${BRIDGE_BASE}.o"
    "$BUILD_DIR/block_bridge.o"
    "$BUILD_DIR/objc_helpers.o"
    "$BUILD_DIR/trace_helper.o"
    "$BUILD_DIR/audio_write_helper.o"
)
[[ -n "$STUB_O" ]] && OBJ_FILES+=("$STUB_O")

ar rcs "$OUTPUT_LIB" "${OBJ_FILES[@]}"

LIB_SIZE=$(du -sh "$OUTPUT_LIB" | cut -f1)
ok "libscribe.a  ($LIB_SIZE)  →  $OUTPUT_LIB"
echo
echo "Exported symbols:"
xcrun nm "$OUTPUT_LIB" 2>/dev/null \
    | grep -E "T _scribe_" \
    | awk '{print "  " $3}'
echo
echo "Next steps:"
echo "  1. Run: xcodegen generate  (from mobile/ios/)"
echo "  2. Open Scribe.xcodeproj in Xcode"
echo "  3. Build and run on iPhone Simulator (arm64)"
