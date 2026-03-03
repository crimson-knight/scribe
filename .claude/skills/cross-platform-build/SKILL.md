# Scribe Cross-Platform Build — Skill Reference

Use this skill when building, compiling, or working on platform-specific code for the Scribe dictation app.

## Toolchain Overview

| Tool | Purpose | Location |
|------|---------|----------|
| **crystal-alpha** | Cross-compiling Crystal compiler | `/opt/homebrew/bin/crystal-alpha` |
| **asset_pipeline** | Cross-platform UI components + renderers | `~/open_source_coding_projects/asset_pipeline/` (branch: `feature/utility-first-css-asset-pipeline`) |
| **crystal-audio** | Audio recording, playback, transcription | `~/open_source_coding_projects/crystal-audio` |
| **Amber V2** | Application patterns (MVC, process managers) | shard dependency |

## Compiler: crystal-alpha

**Version:** 1.20.0-dev-incremental-3
**Invocation:** `crystal-alpha` (drop-in replacement for `crystal`)

### Build Commands by Target

**macOS (development):**
```bash
# MUST: compile ObjC bridge first + pass -Dmacos
clang -c lib/asset_pipeline/src/ui/native/objc_bridge.m \
  -o lib/asset_pipeline/src/ui/native/objc_bridge.o -fno-objc-arc
crystal-alpha build src/scribe.cr -o bin/scribe -Dmacos \
  --link-flags="lib/asset_pipeline/src/ui/native/objc_bridge.o \
    -framework AppKit -framework Foundation -lobjc"
```

**macOS (release):**
```bash
crystal-alpha build src/scribe.cr -o bin/scribe -Dmacos --release \
  --link-flags="lib/asset_pipeline/src/ui/native/objc_bridge.o \
    -framework AppKit -framework Foundation -lobjc"
```

**iOS Device:**
```bash
crystal-alpha build src/scribe.cr \
  --cross-compile --target aarch64-apple-ios17.0 \
  --shared -Dwithout_openssl -Dwithout_xml \
  -o build/ios-device/scribe
```

**iOS Simulator:**
```bash
crystal-alpha build src/scribe.cr \
  --cross-compile --target aarch64-apple-ios17.0-simulator \
  --shared -Dwithout_openssl -Dwithout_xml \
  -o build/ios-simulator/scribe
```

**Android (arm64):**
```bash
export ANDROID_NDK_HOME=$HOME/Library/Android/sdk/ndk/28.2.13676358
crystal-alpha build src/scribe.cr \
  --cross-compile --target aarch64-linux-android31 \
  --shared -Dwithout_openssl -Dwithout_xml \
  -o build/android/scribe
```

### Compile-Time Platform Flags

**CRITICAL:** crystal-alpha does NOT auto-set `:macos`, `:ios`, or `:android`. You MUST pass them via `-D`:
- `-Dmacos` → enables AppKit renderer
- `-Dios` → enables UIKit renderer
- `-Dandroid` → enables Android renderer

Without the flag, the Asset Pipeline silently falls back to the Web renderer.

Flags available in Crystal source:
```crystal
{% if flag?(:macos) %}    # macOS — only if -Dmacos was passed
{% if flag?(:ios) %}      # iOS — only if -Dios was passed
{% if flag?(:android) %}  # Android — only if -Dandroid was passed
{% if flag?(:darwin) %}   # Always true on macOS (auto-detected)
{% if flag?(:apple) %}    # Always true on macOS (auto-detected)
```

## UI Components: asset_pipeline

**Branch:** `feature/utility-first-css-asset-pipeline` (MUST use this branch)

### View Types Available (60+)

**Core:** Label, Button, VStack, HStack, ZStack, Image, TextField, ScrollView, Spacer
**Controls:** Toggle, Checkbox, RadioGroup, Slider, Stepper, SegmentedControl, Picker
**Navigation:** NavigationStack, NavigationLink, TabView, NavigationSplitView, Toolbar
**Display:** ProgressView, ActivityIndicator, Card, Surface, Divider, Alert, Snackbar
**Input:** SecureField, SearchField, TextArea, TextEditor, DatePicker, TimePicker
**Layout:** Grid, Form, Sheet, Popover, ConfirmationDialog

### Platform Rendering

The same UI code renders natively on each platform:
```crystal
require "asset_pipeline/ui"

# This single view definition works on ALL platforms:
view = UI::VStack.new(spacing: 12.0).tap do |v|
  v.children << UI::Label.new("Scribe", font: UI::Font.new(size: 24.0, weight: :bold))
  v.children << UI::Button.new("Record") { start_recording }
end

# Platform-specific rendering selected at compile time:
{% if flag?(:macos) %}
  renderer = UI::AppKit::Renderer.new
{% elsif flag?(:ios) %}
  renderer = UI::UIKit::Renderer.new
{% elsif flag?(:android) %}
  renderer = UI::Android::Renderer.new
{% else %}
  renderer = UI::Web::Renderer.new
{% end %}

native_view = renderer.render(view)
```

### View-to-Native Mapping

| UI::View | macOS | iOS | Android |
|----------|-------|-----|---------|
| Label | NSTextField | UILabel | TextView |
| Button | NSButton | UIButton | MaterialButton |
| VStack | NSStackView(V) | UIStackView(V) | LinearLayout(V) |
| HStack | NSStackView(H) | UIStackView(H) | LinearLayout(H) |
| TextField | NSTextField | UITextField | EditText |
| Toggle | NSButton(switch) | UISwitch | Switch |
| ScrollView | NSScrollView | UIScrollView | ScrollView |
| ProgressView | NSProgressIndicator | UIProgressView | ProgressBar |

### Native FFI Infrastructure

- **NativeHandle** — Wraps Void* with ownership (ObjCRelease, JNIGlobalRef, etc.)
- **CallbackRegistry** — Prevents Proc GC while native code holds function pointers
- **ObjCHandle** — Factory for ObjC objects (`ObjC.owned(ptr)`, `ObjC.borrowed(ptr)`)
- **JNIHandle** — Factory for JNI objects (`JNI.global(env, ref)`)

## Audio: crystal-audio

### Recording
```crystal
require "crystal_audio"

recorder = CrystalAudio::Recorder.new(
  source: CrystalAudio::RecordingSource::Microphone,
  output_path: "/tmp/recording.wav"  # .wav (lossless) or .m4a (compressed)
)
recorder.start
# ... recording ...
recorder.stop
# File saved at output_path
```

### Playback
```crystal
player = CrystalAudio::Player.new
track_idx = player.add_track("/path/to/audio.wav")
player.volume(track: track_idx, level: 0.8)
player.play
```

### Transcription Pipeline
```crystal
pipeline = CrystalAudio::Transcription::Pipeline.new(
  mode: CrystalAudio::Transcription::Pipeline::PipelineMode::Dictation
)
formatted_text = pipeline.format(segments)
```

### Build Requirements
Native extensions must be compiled first:
```bash
cd lib/crystal-audio && make ext && cd ../..
```

Link flags:
```
--link-flags="lib/crystal-audio/ext/*.o \
  -framework AVFoundation -framework AudioToolbox -framework CoreAudio \
  -framework CoreFoundation -framework CoreMedia -framework Foundation \
  -framework ScreenCaptureKit"
```

## Cross-Compile Dependencies (One-Time Setup)

```bash
cd ~/open_source_coding_projects/asset_pipeline
./scripts/cross_compile_deps.sh all  # Builds libgc + libpcre2 for iOS + Android
```

## Scribe-Specific Build Pipeline

### Development (macOS)
```bash
cd ~/personal_coding_projects/scribe
shards install
cd lib/crystal-audio && make ext && cd ../..
crystal-alpha build src/scribe.cr -o bin/scribe \
  --link-flags="lib/crystal-audio/ext/*.o \
    -framework AVFoundation -framework AudioToolbox -framework CoreAudio \
    -framework CoreFoundation -framework CoreMedia -framework Foundation \
    -framework ScreenCaptureKit"
./bin/scribe
```

### iOS (requires one-time dep setup)
```bash
cd ~/open_source_coding_projects/asset_pipeline
./scripts/build_ios.sh ~/personal_coding_projects/scribe/src/scribe.cr device scribe
# Output: build/ios-device/libscribe.dylib
# Then add to Xcode project
```

### Key Reference Files
- **Asset Pipeline Samples:** `~/open_source_coding_projects/asset_pipeline/samples/cross_platform/`
- **Crystal-Alpha Samples:** `~/open_source_coding_projects/crystal/samples/cross_platform/`
- **crystal-audio Samples:** `~/open_source_coding_projects/crystal-audio/samples/`
- **Build Scripts:** `~/open_source_coding_projects/asset_pipeline/scripts/`
- **Cross-Compile Docs:** `~/open_source_coding_projects/asset_pipeline/CROSS_COMPILE.md`
