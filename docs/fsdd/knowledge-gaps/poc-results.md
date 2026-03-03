# Scribe — POC Validation Results

**Date:** 2026-03-03
**Compiler:** crystal-alpha v1.20.0-dev-incremental-3 (arm64 macOS)

---

## POC 1: Amber + Asset Pipeline Native App

**Status: PASS**

**What was validated:**
1. `require "amber"` works without starting HTTP server
2. `require "asset_pipeline/ui"` provides all UI components
3. UI::VStack, UI::Label, UI::Button, UI::Spacer all construct correctly
4. AppKit::Renderer creates native NativeView objects from the view tree
5. Amber configuration (`Amber.settings.name`) works standalone

**Build command:**
```bash
crystal-alpha build poc/amber-native-app/native_app.cr -o bin/poc_native_app -Dmacos \
  --link-flags="lib/asset_pipeline/src/ui/native/objc_bridge.o -framework AppKit -framework Foundation -lobjc"
```

**Discoveries & Knowledge Gaps:**
- `require "ui"` → wrong. Must use `require "asset_pipeline/ui"`
- `-Dmacos` flag is REQUIRED — without it, Web renderer is used instead of AppKit
- `Amber::Server.configure` creates an HTTP server instance. Use `Amber.settings.*=` directly.
- `Amber::Server.settings` doesn't exist. Use `Amber.settings`.
- Asset Pipeline's `objc_bridge.m` didn't exist — had to create it (30 functions)
- The Amber form parser demo prints on startup (stdout pollution) — minor nuisance

**Output:**
```
Platform: macOS — Using AppKit::Renderer
Native view created successfully: UI::NativeView
POC PASSED: Asset Pipeline AppKit rendering works!
```

---

## POC 2: macOS Global Keyboard Shortcuts

**Status: PASS**

**What was validated:**
1. Carbon `RegisterEventHotKey` works from Crystal via C bridge
2. Event handler installs cleanly
3. Multiple hotkeys register (Option+Shift+R, Option+Shift+S)
4. Callback fires on Crystal side when key combo is pressed
5. CFRunLoopRun() serves as the event loop

**Build command:**
```bash
clang -c poc/keyboard-shortcuts/ext/hotkey_bridge.c -o poc/keyboard-shortcuts/ext/hotkey_bridge.o -framework Carbon
crystal-alpha build poc/keyboard-shortcuts/hotkey_poc.cr -o bin/poc_hotkey \
  --link-flags="poc/keyboard-shortcuts/ext/hotkey_bridge.o -framework Carbon -framework AppKit"
```

**Discoveries & Knowledge Gaps:**
- `RunApplicationEventLoop` is deprecated/unavailable in C99 — use `CFRunLoopRun()` instead
- `CFRunLoopRunInMode(kCFRunLoopDefaultMode, seconds, false)` for timed loop
- Non-blocking `hotkey_pump_events()` uses `ReceiveNextEvent` with 0 timeout — good for integration
- No Accessibility permission needed for Carbon hotkeys (unlike CGEvent taps)

**Output:**
```
Event handler installed: PASS
Hotkey 1 registered (Option+Shift+R): PASS
Hotkey 2 registered (Option+Shift+S): PASS
```

---

## POC 3: macOS Clipboard API

**Status: PASS**

**What was validated:**
1. NSPasteboard read (UTF-8 string from general pasteboard)
2. NSPasteboard write (clear + set string)
3. Change count tracking (NSPasteboard changeCount increments)
4. Clipboard cycle: save → write → restore (no data loss)
5. Paste simulation (CGEvent Cmd+V) compiles — needs Accessibility permission at runtime

**Build command:**
```bash
clang -c poc/clipboard-api/ext/clipboard_bridge.m -o poc/clipboard-api/ext/clipboard_bridge.o \
  -framework AppKit -framework ApplicationServices -fobjc-arc
crystal-alpha build poc/clipboard-api/clipboard_poc.cr -o bin/poc_clipboard \
  --link-flags="poc/clipboard-api/ext/clipboard_bridge.o -framework AppKit -framework ApplicationServices -framework Foundation"
```

**Discoveries & Knowledge Gaps:**
- ObjC files must use `.m` extension, not `.c` (even with `#import`)
- Clipboard bridge uses ARC (unlike objc_bridge which uses manual management)
- Paste simulation (CGEvent injection) requires binary added to Accessibility permissions
- Clipboard cycle pattern works: save original → write transcription → paste → restore original
- iOS cannot simulate paste — clipboard copy only

**Output:**
```
Test 1 — Read clipboard: PASS
Test 2 — Write to clipboard: Readback matches: PASS
Test 3 — Change count tracking: PASS
Test 4 — Clipboard cycle (save, write, restore): Restored original: PASS
Test 5 — Paste simulation: REQUIRES ACCESSIBILITY PERMISSION
```

---

## Summary of New Knowledge Gaps Discovered

| Gap | Severity | Description |
|-----|----------|-------------|
| GAP-10 | HIGH for agents | `-Dmacos` flag required but not auto-detected |
| GAP-11 | HIGH for agents | `objc_bridge.m` missing from Asset Pipeline shard |
| GAP-9 (updated) | MEDIUM | Window lifecycle + view mounting not yet proven |

## Build Prerequisites (Complete)

1. crystal-alpha compiler installed (`/opt/homebrew/bin/crystal-alpha`)
2. Xcode license accepted (`sudo xcodebuild -license accept`)
3. `shards install` (installs Amber, Asset Pipeline, crystal-audio, etc.)
4. Compile `objc_bridge.m` → `.o` (Asset Pipeline's ObjC bridge)
5. Compile any C bridge files for platform FFI (keyboard, clipboard)
6. Pass `-Dmacos` to crystal-alpha
7. Link with absolute paths to `.o` files + required frameworks
