# Scribe — Knowledge Gaps & Agent Confusion Points

This document tracks known unknowns, areas where AI agents are likely to get confused, and gaps in the toolchain that need to be solved before implementation can proceed.

**Last Updated:** After discovery of crystal-alpha compiler, crystal-audio library, and asset_pipeline build scripts.

---

## RESOLVED GAPS

### ~~GAP-1: Cross-Platform UI System Maturity~~ — RESOLVED

**Resolution:** The Asset Pipeline (branch `feature/utility-first-css-asset-pipeline`) contains:
- 60+ view types with full implementations
- 4 platform renderers (Web, AppKit, UIKit, Android) totaling 7,800+ lines
- Complete native FFI infrastructure (NativeHandle, CallbackRegistry, ObjCHandle, JNIHandle)
- Build scripts for iOS (`scripts/build_ios.sh`) and Android (`scripts/build_android.sh`)
- Cross-compile dependency builder (`scripts/cross_compile_deps.sh`)
- Sample cross-platform app (`samples/cross_platform/macos_app.cr`)
- Skills documentation for agents (`.claude/skills/`)

**Agent Guidance:** Agents working on UI should reference the asset_pipeline's `.claude/skills/component-api/SKILL.md` and `.claude/skills/platform-renderers/SKILL.md` for complete API documentation.

---

### ~~GAP-3: Audio Recording FFI~~ — RESOLVED

**Resolution:** The `crystal-audio` library at `~/open_source_coding_projects/crystal-audio` provides:
- **Microphone recording:** CoreAudio AudioQueue API (macOS), AVAudioEngine (iOS), AAudio (Android)
- **System audio recording:** CATap/ScreenCaptureKit (macOS 13+)
- **Playback:** AVAudioEngine (macOS/iOS), AAudio (Android), up to 16 simultaneous tracks
- **Transcription pipeline:** whisper.cpp + Claude API integration
- **File formats:** WAV (lossless), M4A/AAC (compressed)
- **Sample apps:** macOS, iOS, and Android ready

**Agent Guidance:** Import `crystal-audio` as a shard dependency. Native extensions must be compiled first with `make ext`. See sample apps in `crystal-audio/samples/` for integration patterns.

---

### ~~GAP-5: Claude Code CLI Integration & JSON Streaming~~ — PARTIALLY RESOLVED

**Resolution:** crystal-audio already includes a Claude API transcription pipeline with:
- Model selection by mode (haiku for dictation, opus for meetings)
- System prompt templates (dictation, meeting, code)
- HTTP API integration

**Remaining:** The Claude Code CLI (command-line tool) JSON streaming format for post-processing still needs live testing. This is lower priority since the transcription pipeline itself is already built into crystal-audio.

**Agent Guidance:** For transcription, use crystal-audio's built-in pipeline. For post-processing (file management via Claude Code CLI), the CLI streaming format still needs to be documented by running a test session.

---

### ~~GAP-7: Crystal Cross-Compilation~~ — RESOLVED

**Resolution:** The `crystal-alpha` compiler (`/opt/homebrew/bin/crystal-alpha`, v1.20.0-dev-incremental-3) provides:
- Cross-compilation to iOS (arm64 device + simulator), Android (arm64 API 31), WASM, Linux
- Incremental compilation (3-5x faster warm rebuilds)
- `--cross-compile --target <triple> --shared` flags for mobile targets
- Full integration with asset_pipeline build scripts

**Build targets:**
- `aarch64-apple-ios17.0` (iOS device)
- `aarch64-apple-ios17.0-simulator` (iOS simulator)
- `aarch64-linux-android31` (Android arm64)

**Agent Guidance:** Use `crystal-alpha` instead of `crystal` for all builds. The asset_pipeline's `build_ios.sh` and `build_android.sh` scripts handle the full pipeline. One-time setup: `./scripts/cross_compile_deps.sh all` to build libgc + libpcre2 for all targets.

---

### ~~GAP-8: App Packaging & Distribution~~ — PARTIALLY RESOLVED

**Resolution:** The asset_pipeline documents the Xcode and Android Studio integration:
- **iOS:** Drag .dylib into Xcode, set Bridging Header to CrystalBridge.h, call `crystal_init()` in AppDelegate
- **Android:** Copy .so to `jniLibs/arm64-v8a/`, load via `System.loadLibrary()`, declare native methods

**Remaining:** App Store submission, code signing, and notarization workflows not yet documented.

---

## RESOLVED GAPS (POC Validated)

### ~~GAP-2: Amber V2 as a Native App Framework~~ — RESOLVED (POC 1)

**Resolution:** Validated that `require "amber"` works without starting the HTTP server. Tested:
- `Amber.settings.name = "Scribe POC"` — configuration works standalone
- `Amber.env` — environment detection works
- Controllers can be defined and used as event handlers
- **Important:** `Amber::Server.configure` triggers HTTP initialization. Use `Amber.settings.*=` directly instead.
- The Amber form parser example output appears on startup (minor nuisance, not blocking)

**Agent Guidance:** Use `Amber.settings` directly, NOT `Amber::Server.settings` or `Amber::Server.configure`. The latter creates a server instance.

---

### ~~GAP-4: Global Keyboard Shortcut Implementation~~ — RESOLVED (POC 2)

**Resolution:** Carbon `RegisterEventHotKey` works from Crystal via a thin C bridge (`hotkey_bridge.c`):
- Event handler installs cleanly
- Multiple hotkeys can be registered (tested Option+Shift+R and Option+Shift+S)
- Callback fires on the Crystal side when hotkey is pressed
- CFRunLoopRun() works as the event loop (deprecated RunApplicationEventLoop replaced)
- Non-blocking `hotkey_pump_events()` available for integration with other event loops

**Pattern:** C bridge file → Crystal `lib` bindings → Crystal wrapper module

**Agent Guidance:** The hotkey bridge is at `poc/keyboard-shortcuts/ext/hotkey_bridge.c`. This exact pattern can be moved to `src/platform/macos/` for production use.

---

### ~~GAP-6: Clipboard Management & Paste Simulation~~ — RESOLVED (POC 3)

**Resolution:** All clipboard operations work from Crystal via ObjC bridge (`clipboard_bridge.m`):
- Clipboard read: reads NSPasteboard general pasteboard as UTF-8
- Clipboard write: clears + writes string to pasteboard
- Change count tracking: NSPasteboard changeCount increments properly
- Clipboard cycle (save → write → restore): works perfectly, no data loss
- Paste simulation: CGEvent Cmd+V injection compiles — requires Accessibility permission at runtime

**iOS Limitation confirmed:** Paste simulation not possible on iOS. Clipboard copy only.

**Agent Guidance:** The clipboard bridge is at `poc/clipboard-api/ext/clipboard_bridge.m`. The clipboard cycle (save, write transcription, paste, restore original) pattern is proven and ready for production.

---

## REMAINING GAPS

### GAP-9: Amber + Asset Pipeline Integration Pattern (PARTIALLY RESOLVED)

**Status:** POC 1 validated the basic pipeline. Remaining: controller → view update flow.

**What's Proven:**
1. Amber can be loaded without HTTP server ✓
2. Asset Pipeline UI views can be created (VStack, Label, Button, Spacer) ✓
3. AppKit renderer produces native NativeView objects ✓
4. The view tree and renderer compile and execute correctly ✓

**What's NOT Proven:**
- How controllers push updates to an already-rendered view tree (reactive updates)
- Window creation and view mounting (NSWindow + NSApplication event loop)
- Button click callbacks propagating from native views back to Crystal

**Recommended Action:** Extend POC 1 to create an NSWindow, mount the rendered view, and run an NSApplication event loop. This would prove the full lifecycle.

---

### GAP-10: Asset Pipeline Platform Flag Configuration (NEW — LOW)

**Status:** Discovered and documented. Workaround known.

**The Gap:** crystal-alpha sets `flag?(:darwin)` and `flag?(:apple)` on macOS but does NOT set `flag?(:macos)`. The Asset Pipeline AppKit renderer gates on `flag?(:macos)`, so building without `-Dmacos` gives the Web renderer fallback instead.

**Workaround:** Pass `-Dmacos` to crystal-alpha when building for macOS:
```bash
crystal-alpha build src/scribe.cr -o bin/scribe -Dmacos --link-flags="..."
```

Similarly, for iOS use `-Dios` and for Android use `-Dandroid`.

**Agent Confusion Risk:** HIGH — An agent will not know to pass `-Dmacos` unless told. Without it, the build succeeds but uses the wrong renderer.

**Recommended Action:** Document in CLAUDE.md and build skill. Consider adding auto-detection to the Asset Pipeline (e.g., `flag?(:darwin) && !flag?(:ios)` → macOS).

---

### GAP-11: Asset Pipeline objc_bridge.m Not Shipped with Shard (NEW — MEDIUM)

**Status:** Created manually, needs to be committed to asset_pipeline repo.

**The Gap:** The Asset Pipeline's AppKit renderer (`appkit_renderer.cr`) declares `lib LibObjCBridge` with ~30 function signatures, but the C implementation file (`objc_bridge.m`) did not exist in the repository. Without it, any project using the AppKit renderer fails at link time with undefined symbols.

**What Was Done:** Created `src/ui/native/objc_bridge.m` implementing all required functions:
- 10 typed objc_msgSend wrappers (pointer/integer args)
- 4 floating-point register wrappers (ARM64 d-registers)
- 3 CGRect/HFA wrappers
- 11 convenience helpers (NSString, NSColor, NSFont, NSView utilities)
- Must compile with `-fno-objc-arc` (Crystal's NativeHandle manages lifetimes)

**Agent Confusion Risk:** HIGH — An agent attempting to build a native macOS app will hit linker errors for ~20 undefined symbols and have no way to resolve them without creating this file.

**Recommended Action:** Commit `objc_bridge.m` to the asset_pipeline repo on the feature branch. Add a Makefile or build instruction for compiling it. Update the shard to include pre-compilation instructions.

---

## Summary: Updated Implementation Viability by Platform

| Platform | Viability | Status | Key Dependencies |
|----------|-----------|--------|-----------------|
| **macOS** | **VERY HIGH** | Ready to build | crystal-alpha + asset_pipeline (AppKit) + crystal-audio |
| **iOS** | **HIGH** | Build pipeline proven | crystal-alpha + build_ios.sh + crystal-audio (iOS samples exist) |
| **Android** | **MEDIUM-HIGH** | Build pipeline proven | crystal-alpha + build_android.sh + crystal-audio (Android AAudio) |

**Previous assessment:** macOS HIGH, iOS LOW, Android LOW
**Updated assessment:** All platforms viable. macOS first, then iOS (proven toolchain), then Android.
