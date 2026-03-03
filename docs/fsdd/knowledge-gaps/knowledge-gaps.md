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

## REMAINING GAPS

### GAP-2: Amber V2 as a Native App Framework (MEDIUM — Design Decision Made)

**Status:** Architectural decision made (Landmark 2), but implementation pattern needs validation.

**The Gap:** We've decided to use Amber patterns without the HTTP server, but we need to validate:
1. Can we `require "amber"` without starting the server?
2. Which Amber modules work standalone (controllers, configuration, helpers)?
3. How to replace Amber's HTTP pipeline with an event-driven architecture?

**Agent Confusion Risk:** MEDIUM — An agent may try to use `Amber::Server.start` or HTTP routing.

**Recommended Action:** Create a minimal proof-of-concept that requires Amber but uses an event loop instead of HTTP. Document which Amber modules are used and which are skipped.

---

### GAP-4: Global Keyboard Shortcut Implementation (MEDIUM)

**Status:** FFI infrastructure proven (via asset_pipeline and crystal-audio), but specific shortcut API not yet bound.

**The Gap:** Global keyboard shortcuts require:
- **macOS:** CGEvent tap (Accessibility permission) or Carbon `RegisterEventHotKey`
- **iOS:** Siri Shortcuts integration (no true global shortcuts)
- **Android:** Accessibility Service or media button interception

**What's Changed:** The asset_pipeline's ObjC bridge and crystal-audio's FFI patterns prove that Crystal-to-ObjC calls work reliably. The same patterns can be applied to CGEvent or Carbon hotkey APIs.

**Agent Confusion Risk:** LOW (reduced from MEDIUM) — The FFI patterns are now well-established. An agent can follow the same `lib` binding + typed wrapper approach used in crystal-audio.

**Recommended Action:** Implement macOS global shortcut using Carbon `RegisterEventHotKey` (simplest, most reliable) following crystal-audio's FFI patterns. Create `Scribe::Platform::MacosShortcutListener` with the same abstract class pattern.

---

### GAP-6: Clipboard Management & Paste Simulation (MEDIUM)

**Status:** Clipboard read/write is straightforward FFI; paste simulation requires additional research.

**The Gap:**
- **Clipboard read/write:** NSPasteboard (macOS), UIPasteboard (iOS), ClipboardManager (Android) — all simple FFI following proven patterns
- **Paste simulation:** Requires CGEvent to inject Cmd+V keystroke (macOS), which needs Accessibility permission

**iOS Limitation:** Paste simulation is not possible on iOS without private APIs. iOS output must be clipboard-only (no auto-paste).

**Agent Confusion Risk:** LOW for clipboard operations (proven FFI patterns), MEDIUM for paste simulation.

**Recommended Action:**
1. Clipboard read/write: Follow crystal-audio's ObjC FFI patterns for NSPasteboard
2. Paste simulation (macOS): Research `CGEventCreateKeyboardEvent` for Cmd+V injection
3. Accept iOS limitation: clipboard copy only, user pastes manually

---

### GAP-9: Amber + Asset Pipeline Integration Pattern (NEW — MEDIUM)

**Status:** Needs validation

**The Gap:** How exactly do Amber controllers interact with Asset Pipeline UI views in a native (non-web) context?

- In web mode, Amber controllers render HTML through Asset Pipeline components
- In native mode, we need controllers to update native views through the platform renderer
- The event-driven architecture (Landmark 8) needs to bridge Amber's patterns with Asset Pipeline's view tree

**Recommended Action:** Define the native controller → view update pattern:
1. Controller handles event
2. Controller delegates to process manager
3. Process manager returns results
4. Controller passes results to view updater
5. View updater modifies the UI::View tree
6. Platform renderer applies diff to native views

---

## Summary: Updated Implementation Viability by Platform

| Platform | Viability | Status | Key Dependencies |
|----------|-----------|--------|-----------------|
| **macOS** | **VERY HIGH** | Ready to build | crystal-alpha + asset_pipeline (AppKit) + crystal-audio |
| **iOS** | **HIGH** | Build pipeline proven | crystal-alpha + build_ios.sh + crystal-audio (iOS samples exist) |
| **Android** | **MEDIUM-HIGH** | Build pipeline proven | crystal-alpha + build_android.sh + crystal-audio (Android AAudio) |

**Previous assessment:** macOS HIGH, iOS LOW, Android LOW
**Updated assessment:** All platforms viable. macOS first, then iOS (proven toolchain), then Android.
