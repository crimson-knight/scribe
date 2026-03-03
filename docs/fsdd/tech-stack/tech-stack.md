# Scribe — Tech Stack

## Tier 1: Vendors

| Vendor | Purpose | Location/Version | License |
|--------|---------|-----------------|---------|
| Crystal-Alpha | Cross-compiling Crystal compiler | `/opt/homebrew/bin/crystal-alpha` v1.20.0-dev-incremental-3 | Apache 2.0 |
| Amber V2 Framework | Application patterns (MVC, process managers, config) | shard dep (crimson-knight/amber) v2.0.0-dev | MIT |
| Asset Pipeline | Cross-platform UI components + renderers + build scripts | `~/open_source_coding_projects/asset_pipeline/` v0.36.0 (branch: `feature/utility-first-css-asset-pipeline`) | MIT |
| crystal-audio | Audio recording, playback, transcription | `~/open_source_coding_projects/crystal-audio` v0.1.0 | MIT |
| Apple (macOS/iOS) | Platform APIs — AppKit, UIKit, AVFoundation, CoreAudio | Xcode 15+ / iOS 17.0+ SDK | Proprietary |
| Google (Android) | Platform APIs — JNI, AAudio, NDK | NDK r28+ / API 31+ | Apache 2.0 |
| Anthropic | Claude API (via crystal-audio pipeline) + Claude Code CLI | Commercial API | Commercial |
| SQLite | Local database for settings, history, templates | shard dep (crystal-lang/crystal-sqlite3) | Public Domain |

## Tier 2: Vendor Features

### Crystal-Alpha Compiler
- Native compilation (macOS arm64)
- Cross-compilation (iOS arm64, Android arm64, WASM)
- Incremental compilation (3-5x faster warm rebuilds)
- `--cross-compile --target <triple> --shared` for mobile libraries
- Compile-time `flag?()` platform selection

### Amber V2 Framework
- Controller patterns (event handlers, NOT HTTP in native mode)
- Configuration management (environment-based)
- Process manager patterns (FSDD business logic)
- Grant ORM (ActiveRecord-style, SQLite adapter)

### Asset Pipeline
- **Cross-platform UI system:** 60+ view types with 4 platform renderers
- **AppKit Renderer:** NSView hierarchy for macOS native UI
- **UIKit Renderer:** UIView hierarchy for iOS native UI
- **Android Renderer:** Android Views via JNI
- **Web Renderer:** HTML Components::Elements
- **Native FFI infrastructure:** NativeHandle, CallbackRegistry, ObjCHandle, JNIHandle
- **Build scripts:** `build_ios.sh`, `build_android.sh`, `cross_compile_deps.sh`
- **Theme system:** Colors, typography, spacing tokens

### crystal-audio
- **Microphone recording:** CoreAudio AudioQueue (macOS), AVAudioEngine (iOS), AAudio (Android)
- **System audio capture:** CATap/ScreenCaptureKit (macOS 13+)
- **Multi-track playback:** AVAudioEngine (macOS/iOS), AAudio (Android), up to 16 tracks
- **File formats:** WAV (lossless 44.1/48kHz), M4A/AAC (compressed)
- **Transcription pipeline:** whisper.cpp → Claude API (dictation, meeting, code modes)
- **Now-playing integration:** Lock screen controls (macOS/iOS)
- **Native extensions:** Pre-compiled ObjC bridges, AudioQueue callbacks, block bridges

### Apple Platform APIs (accessed via crystal-audio + asset_pipeline)
- **AVFoundation:** Audio recording and playback (via crystal-audio)
- **CoreAudio:** Low-level audio capture (via crystal-audio AudioQueue)
- **AppKit:** Native UI rendering (via asset_pipeline AppKit Renderer)
- **UIKit:** Native iOS UI (via asset_pipeline UIKit Renderer)
- **NSPasteboard:** Clipboard operations (new FFI needed — follows proven patterns)
- **CGEvent:** Global keyboard shortcuts + paste simulation (new FFI needed)

### Google Android APIs (accessed via crystal-audio + asset_pipeline)
- **AAudio:** Audio recording and playback (via crystal-audio)
- **JNI:** Native bridge to Android Views (via asset_pipeline Android Renderer)
- **NotificationManager:** Foreground service notification
- **ClipboardManager:** Clipboard operations

### Claude Integration
- **Transcription cleanup:** crystal-audio's built-in Claude API pipeline
- **Post-processing:** Claude Code CLI spawned as external process (`--output-format stream-json`)
- **Models:** haiku for dictation/code, opus for meetings

## Tier 3: Feature-to-Vendor Mapping

| Feature | Vendors Used |
|---------|-------------|
| Application Shell (macOS) | Crystal-Alpha, Asset Pipeline (AppKit Renderer) |
| Application Shell (iOS) | Crystal-Alpha (cross-compile), Asset Pipeline (UIKit Renderer) |
| Application Shell (Android) | Crystal-Alpha (cross-compile), Asset Pipeline (Android Renderer) |
| Audio Recording | crystal-audio (mic: AudioQueue/AVAudioEngine/AAudio) |
| Audio File Management | crystal-audio (WAV/M4A output) |
| Transcription | crystal-audio (whisper.cpp + Claude API pipeline) |
| Clipboard Management | New FFI (NSPasteboard/UIPasteboard/ClipboardManager) — follows proven patterns |
| Global Shortcuts | New FFI (CGEvent/Carbon) — follows proven patterns |
| Output File Management | Crystal (File I/O), SQLite |
| AI Post-Processing | Anthropic Claude Code CLI (external process) |
| Configuration Storage | SQLite via Grant ORM, Amber configuration patterns |
| Native UI Rendering | Asset Pipeline cross-platform UI + platform renderers |

## Blast Radius Analysis

| If This Changes... | These Features Are Affected |
|--------------------|---------------------------|
| Asset Pipeline branch / cross-platform UI | All native UI on all platforms |
| crystal-alpha compiler | All cross-compilation targets (iOS, Android) |
| crystal-audio API | Recording, playback, transcription |
| Claude Code CLI output format | AI Post-Processing streaming only |
| Claude API | Transcription cleanup (crystal-audio pipeline) |
| SQLite schema | Configuration, history, templates |

## Build Pipeline Summary

### Development (macOS)
```bash
crystal-alpha build src/scribe.cr -o bin/scribe \
  --link-flags="lib/crystal-audio/ext/*.o [frameworks]"
```

### iOS
```bash
# One-time: ./scripts/cross_compile_deps.sh ios
./scripts/build_ios.sh src/scribe.cr device scribe
# → build/ios-device/libscribe.dylib → Add to Xcode project
```

### Android
```bash
# One-time: ./scripts/cross_compile_deps.sh android
./scripts/build_android.sh src/scribe.cr scribe
# → build/android-arm64/libscribe.so → Add to Android Studio
```
