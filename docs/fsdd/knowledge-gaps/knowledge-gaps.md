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

### GAP-9: Amber + Asset Pipeline Integration Pattern (MOSTLY RESOLVED)

**Status:** Full native app lifecycle proven — from `require` through window display.

**What's Proven:**
1. Amber can be loaded without HTTP server ✓
2. Asset Pipeline UI views can be created (VStack, Label, Button, Spacer) ✓
3. AppKit renderer produces native NativeView objects ✓
4. The view tree and renderer compile and execute correctly ✓
5. NSWindow creation and view mounting ✓ (Scribe app runs with window)
6. NSApplication event loop (CFRunLoopRun via `[NSApp run]`) ✓

**What's NOT Proven:**
- How controllers push updates to an already-rendered view tree (reactive updates)
- Button click callbacks propagating from native views back to Crystal
- View re-rendering after state changes

**Architecture Note:** Asset Pipeline is a pure view library — it renders UI trees to NSView hierarchies but does NOT provide NSApplication/NSWindow management. Consuming apps need their own platform bridge (e.g., `scribe_platform_bridge.m`) for app lifecycle, windows, menus, and status bar items.

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

### GAP-12: Amber Schema Examples Run at Require Time (NEW — LOW)

**Status:** Identified. Workaround: ignore output or patch Amber locally.

**The Gap:** `lib/amber/src/amber.cr` does `require "./amber/schema/**"` which includes `src/amber/schema/examples/simple_form_example.cr`. That file calls `SimpleFormExample.run` at module load time, printing ~50 lines of form parsing examples to stdout on every app startup.

**Impact:** Cosmetic only — does not affect functionality. The output is:
```
🚀 Enhanced Form Data Parser Examples for Amber Schema API
...
✨ Examples completed!
```

**Agent Confusion Risk:** LOW — the output is confusing but not blocking.

**Recommended Action:** Remove `SimpleFormExample.run` from the bottom of the example file, or move example files to `spec/` instead of `src/`. This is an Amber framework bug — example/demo code should not execute at require time.

---

### GAP-13: Asset Pipeline Has No App/Window Management (NEW — INFORMATIONAL)

**Status:** Documented design decision.

**The Gap:** The Asset Pipeline is a view rendering library. It provides:
- 60+ UI view types
- 4 platform renderers (AppKit, UIKit, Android, Web)
- Native FFI infrastructure (NativeHandle, CallbackRegistry)

It does NOT provide:
- NSApplication / UIApplication lifecycle management
- NSWindow / UIWindow creation
- Event loop integration
- Status bar items, menus, or app-level controls

**Impact:** Every native app using Asset Pipeline must create its own platform bridge for app lifecycle. Scribe solved this with `src/platform/macos/ext/scribe_platform_bridge.m` providing NSApplication, NSWindow, NSStatusItem, and NSMenu helpers.

**Agent Confusion Risk:** MEDIUM — Agents may expect the Asset Pipeline to handle window creation. The sample `macos_app.cr` in the Asset Pipeline only demonstrates HTML output, not native windowing.

**Recommended Action:** Consider adding optional app-lifecycle helpers to Asset Pipeline (e.g., `UI::AppKit::Window`, `UI::AppKit::Application`), or document clearly that apps must provide their own platform bridge for window management.

---

### GAP-14: crystal-audio Shard Name Requires Symlink (NEW — MEDIUM)

**Status:** Worked around with symlink.

**The Gap:** The crystal-audio shard has a hyphenated name (`crystal-audio`) in `shard.yml`, so shards-alpha installs it to `lib/crystal-audio/`. But the main source file is `src/crystal_audio.cr` (underscore). Crystal's require resolution looks for `lib/crystal_audio/` (underscore) when you do `require "crystal_audio"`, which doesn't exist.

**Workaround:** Create a symlink:
```bash
ln -sf crystal-audio lib/crystal_audio
```

Then use `require "crystal_audio"` in source code.

**Agent Confusion Risk:** HIGH — `require "crystal_audio"` and `require "crystal-audio"` both fail without the symlink. The error message says "Did you remember to run shards install?" which is misleading.

**Recommended Action:** Either:
1. Rename the shard to `crystal_audio` (breaking change), or
2. Add `crystal-audio/src/crystal-audio.cr` as a forwarding file that does `require "./crystal_audio"`, or
3. Add this symlink to the Scribe Makefile setup target

---

### GAP-15: shards-alpha Does Not Support shard.override.yml (NEW — MEDIUM)

**Status:** Documented. Standard shards supports override files, but shards-alpha does not.

**The Gap:** `shard.override.yml` is a standard shards feature for local development overrides. shards-alpha ignores it and fails to resolve dependencies that would be overridden.

**Workaround:** Either:
- Push changes to GitHub and install from remote
- Manually symlink `lib/<shard>` to local directories after install

**Agent Confusion Risk:** MEDIUM — An agent trying to use local library paths will hit "Unable to satisfy requirements" errors.

---

### GAP-16: Ameba Postinstall Fails on crystal-alpha (NEW — LOW)

**Status:** Non-blocking. Ameba is a dev-only linter.

**The Gap:** `shards-alpha install` fails on ameba's postinstall script (`make bin && make run_file`) due to a type error in ameba's Crystal code when compiled with crystal-alpha.

**Workaround:** Ignore — ameba is a development dependency and not needed for compilation.

---

### GAP-17: Crystal `type` vs `alias` for C Function Pointer Callbacks (NEW — HIGH)

**Status:** Resolved. Documented for future reference.

**The Gap:** In Crystal's `lib` blocks, `type Foo = (UInt32) ->` creates an **opaque C typedef** that Crystal treats as a distinct type. Crystal's `Proc` values CANNOT be assigned to variables of this type, and they CANNOT be auto-converted when passed to `fun` calls that use this type.

Using `alias Foo = (UInt32) -> Void` instead creates a **transparent type alias** that Crystal recognizes as a function pointer type. Crystal Proc values CAN be auto-converted to this type at call sites.

**Symptoms:**
```
Error: class variable '@@callback' of MyModule must be LibFoo::Callback, not Proc(UInt32, Nil)
# or
Error: undefined method 'to_unsafe' for Proc(UInt32, Nil)
```

**Fix:** In `lib` blocks, always use `alias` (not `type`) for C function pointer callback types:
```crystal
lib LibFoo
  # WRONG — creates opaque type, no Proc conversion
  type Callback = (UInt32) ->

  # CORRECT — transparent alias, Proc auto-converts
  alias Callback = (UInt32) -> Void
end
```

**Agent Confusion Risk:** VERY HIGH — Both `type` and `alias` compile without error in the `lib` block. The error only surfaces when trying to pass a Crystal proc as the callback. The error message about `to_unsafe` is misleading and doesn't hint at the `type` vs `alias` fix.

---

### GAP-18: FSDD Feature Story Grammar Has No Platform Target Concept (NEW — METHODOLOGY)

**Status:** Documented in FSDD repo. Proposal written.

**The Gap:** FSDD's feature story grammar does not include a mechanism for specifying which target platform a story applies to. When building cross-platform native apps, the same logical feature manifests as fundamentally different UI experiences per platform. The **view outcome** is the part of the grammar most affected — a "menu bar dropdown" on macOS becomes a "notification action" on Android becomes "n/a" on Web.

**Key Insight:** Views represent the capabilities of what you're trying to do. The view outcome constrains and is constrained by the platform. This connects directly to personas — the persona's UI Context is effectively a per-platform view capability set.

**Proposal:** Two complementary extensions:
1. **Platform tag** on stories: `Platform: macOS` for platform-exclusive stories
2. **Conditional view outcomes**: `→ views (macOS):` / `→ views (iOS):` for cross-platform stories

**Full writeup:** `~/Documents/remote_sync_vault/Feature-Story-Driven-Development/.local/PLATFORM-TARGET-GAP.md`

**Impact on agents:** An agent scaffolding a new project needs to know target platforms. An implementor needs to know which renderer. A validator needs platform-specific acceptance criteria.

---

### GAP-19: NSApp Run Loop Blocks Crystal Fiber Scheduler (NEW — CRITICAL)

**Status:** Resolved. Documented for future reference.

**The Gap:** `[NSApp run]` (called via `LibScribePlatform.scribe_run_app`) blocks the main thread in Apple's CFRunLoop. Crystal's `spawn` creates fibers on the same thread, but Crystal's fiber scheduler only runs when the Crystal event loop gets control — which it never does because CFRunLoop never yields to it.

**Symptoms:** Code inside `spawn do ... end` blocks simply never executes. The app appears to hang at whatever state it was in before the `spawn` was called. No error messages, no crash — just silent non-execution.

**Why This Is Especially Confusing:** The `spawn` call itself succeeds. The fiber is created. But it will never be scheduled because `[NSApp run]` never returns and never calls Crystal's event loop.

**Fix:** Use GCD (Grand Central Dispatch) via the ObjC bridge for all background work:
```objc
// Background work
dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    // ... heavy work (runs on GCD thread pool, NOT Crystal fiber) ...
    dispatch_async(dispatch_get_main_queue(), ^{
        // ... callback on main thread (fires within CFRunLoop) ...
        g_callback(result);
    });
});
```

Crystal side installs a callback via C function pointer. The callback fires on the main thread through GCD's integration with CFRunLoop — no Crystal fiber scheduler needed.

**Agent Confusion Risk:** VERY HIGH — `spawn` is the idiomatic Crystal way to do async work. It works perfectly in command-line Crystal apps. But in any app using `[NSApp run]`, `UIApplicationMain()`, or `CFRunLoopRun()` as its event loop, Crystal fibers are dead code. This will silently break with no compiler warning.

**Rule:** In native macOS/iOS apps, NEVER use `spawn` for work that must actually execute. Use GCD via the ObjC bridge instead.

---

## Summary: Updated Implementation Viability by Platform

| Platform | Viability | Status | Key Dependencies |
|----------|-----------|--------|-----------------|
| **macOS** | **VERY HIGH** | Ready to build | crystal-alpha + asset_pipeline (AppKit) + crystal-audio |
| **iOS** | **HIGH** | Build pipeline proven | crystal-alpha + build_ios.sh + crystal-audio (iOS samples exist) |
| **Android** | **MEDIUM-HIGH** | Build pipeline proven | crystal-alpha + build_android.sh + crystal-audio (Android AAudio) |

**Previous assessment:** macOS HIGH, iOS LOW, Android LOW
**Updated assessment:** All platforms viable. macOS first, then iOS (proven toolchain), then Android.
