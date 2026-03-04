#!/usr/bin/env bash
# build_crystal_lib.sh — Cross-compile Crystal + JNI bridge for Android (aarch64)
#
# Produces: app/src/main/jniLibs/arm64-v8a/libscribe.so
#
# Prerequisites:
#   - crystal-alpha compiler
#   - Android NDK (ANDROID_SDK_ROOT or NDK_ROOT env var)
#   - Pre-built libgc.a for aarch64-linux-android26 (optional, warned if missing)
#
# Usage:
#   cd scribe && ./mobile/android/build_crystal_lib.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

CRYSTAL="${CRYSTAL:-crystal-alpha}"
TARGET="aarch64-linux-android26"
API_LEVEL=26
HOST_TAG="darwin-x86_64"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIBE_ROOT="$(cd "$MOBILE_DIR/.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
JNILIBS_DIR="$SCRIPT_DIR/app/src/main/jniLibs/arm64-v8a"
BRIDGE_SRC="$MOBILE_DIR/shared/scribe_bridge.cr"
BRIDGE_BASE="$BUILD_DIR/scribe_bridge"

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

[[ ! -f "$BRIDGE_SRC" ]] && fail "Bridge source not found: $BRIDGE_SRC"

# Locate NDK
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-/opt/homebrew/share/android-commandlinetools}"
NDK_ROOT="${NDK_ROOT:-$(ls -d "$ANDROID_SDK_ROOT"/ndk/*/ 2>/dev/null | sort -V | tail -1)}"
NDK_ROOT="${NDK_ROOT%/}"  # strip trailing slash

if [[ -z "$NDK_ROOT" ]] || [[ ! -d "$NDK_ROOT" ]]; then
    fail "NDK not found. Set NDK_ROOT or install NDK under \$ANDROID_SDK_ROOT/ndk/"
fi

# Set NDK clang
NDK_CLANG="$NDK_ROOT/toolchains/llvm/prebuilt/$HOST_TAG/bin/${TARGET}-clang"
CLANG_FLAGS=""
if [[ ! -f "$NDK_CLANG" ]]; then
    # Fallback: bare clang with --target flag
    NDK_CLANG="$NDK_ROOT/toolchains/llvm/prebuilt/$HOST_TAG/bin/clang"
    CLANG_FLAGS="--target=$TARGET"
    [[ ! -f "$NDK_CLANG" ]] && fail "NDK clang not found at: $NDK_CLANG"
fi

SYSROOT="$NDK_ROOT/toolchains/llvm/prebuilt/$HOST_TAG/sysroot"
CRYSTAL_VER=$("$CRYSTAL" --version 2>&1 | head -1)

info "Compiler       : $CRYSTAL_VER"
info "Target         : $TARGET"
info "NDK root       : $NDK_ROOT"
info "NDK clang      : $NDK_CLANG"
info "Sysroot        : $SYSROOT"
info "Scribe root    : $SCRIBE_ROOT"
info "Output         : $JNILIBS_DIR/libscribe.so"
echo

mkdir -p "$BUILD_DIR" "$JNILIBS_DIR"

# ---------------------------------------------------------------------------
# Step 1: Cross-compile Crystal bridge -> object file
# ---------------------------------------------------------------------------

info "Cross-compiling shared/scribe_bridge.cr for $TARGET ..."
cd "$SCRIBE_ROOT"
"$CRYSTAL" build mobile/shared/scribe_bridge.cr \
    --cross-compile \
    --target "$TARGET" \
    --define android \
    --release \
    -o "$BRIDGE_BASE" 2>&1 | head -5
ok "scribe_bridge.o"

# ---------------------------------------------------------------------------
# Step 2: Compile JNI bridge with NDK clang
# ---------------------------------------------------------------------------

info "Compiling jni_bridge.c ..."
$NDK_CLANG $CLANG_FLAGS \
    -c "$SCRIPT_DIR/jni_bridge.c" \
    -o "$BUILD_DIR/jni_bridge.o" \
    -O2 -fPIC
ok "jni_bridge.o"

# ---------------------------------------------------------------------------
# Step 3: Check for pre-built libgc.a
# ---------------------------------------------------------------------------

LIBGC="$BUILD_DIR/libgc.a"
LIBGC_FLAG=""
if [[ -f "$LIBGC" ]]; then
    ok "Found libgc.a at $LIBGC"
    LIBGC_FLAG="$LIBGC"
else
    info "WARNING: $LIBGC not found — linking without GC (may fail at runtime)"
    info "To cross-compile BoehmGC for Android:"
    info "  cd /tmp && git clone https://github.com/ivmai/bdwgc.git && cd bdwgc"
    info "  cmake -DCMAKE_SYSTEM_NAME=Android -DCMAKE_ANDROID_NDK=$NDK_ROOT \\"
    info "    -DCMAKE_ANDROID_ARCH_ABI=arm64-v8a -DANDROID_NATIVE_API_LEVEL=$API_LEVEL \\"
    info "    -DCMAKE_BUILD_TYPE=Release -Denable_threads=ON -Denable_cplusplus=OFF \\"
    info "    -DBUILD_SHARED_LIBS=OFF -B build && cmake --build build"
    info "  cp build/libgc.a $BUILD_DIR/"
    echo
fi

# ---------------------------------------------------------------------------
# Step 4: Link shared library
# ---------------------------------------------------------------------------

info "Linking libscribe.so ..."
$NDK_CLANG $CLANG_FLAGS \
    -shared \
    -o "$JNILIBS_DIR/libscribe.so" \
    "$BUILD_DIR/scribe_bridge.o" \
    "$BUILD_DIR/jni_bridge.o" \
    $LIBGC_FLAG \
    -llog -landroid -lm -ldl -laaudio \
    -Wl,-z,max-page-size=16384 \
    -Wl,--gc-sections \
    --sysroot="$SYSROOT"
ok "libscribe.so linked"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo
LIB_SIZE=$(du -sh "$JNILIBS_DIR/libscribe.so" | cut -f1)
info "Output: $JNILIBS_DIR/libscribe.so  ($LIB_SIZE)"
echo
echo "Exported symbols:"
nm -D "$JNILIBS_DIR/libscribe.so" 2>/dev/null \
    | grep -E "T (scribe_|Java_|JNI_OnLoad)" \
    | awk '{print "  " $3}' \
    || echo "  (nm not available or no symbols found)"
echo
echo "Next steps:"
echo "  1. cd mobile/android"
echo "  2. ./gradlew assembleDebug"
