# Scribe — Architectural Landmarks

Key decisions and expectations for how the system should be wired together. These are the "stakes in the ground" that all agents must respect during implementation.

---

## Landmark 1: macOS-First Development (All Platforms Now Viable)

**Decision:** Build and validate on macOS first, then iOS, then Android. All platforms have proven toolchains.

**Rationale:** macOS has the fastest iteration cycle (no cross-compilation needed). iOS and Android now have proven build pipelines via crystal-alpha + asset_pipeline build scripts. crystal-audio has sample apps for all three platforms.

**What This Means:**
- Build macOS first for fastest iteration and validation
- iOS is the next target (crystal-alpha cross-compile → Xcode integration is documented)
- Android follows (crystal-alpha → Android Studio integration is documented)
- All platform abstractions should be designed from the start
- crystal-audio already provides platform implementations for audio on all three platforms
- The compile-time `flag?()` path is well-established across asset_pipeline and crystal-audio

**Build Commands (all proven):**
```bash
# macOS (direct)
crystal-alpha build src/scribe.cr -o bin/scribe

# iOS (via asset_pipeline build script)
./scripts/build_ios.sh src/scribe.cr device scribe

# Android (via asset_pipeline build script)
./scripts/build_android.sh src/scribe.cr scribe
```

---

## Landmark 2: Amber Patterns Without HTTP Server

**Decision:** Use Amber V2's patterns (controllers, process managers, configuration) but do NOT run the HTTP server for the production native app.

**Rationale:** Scribe is a native menu bar app, not a web server. Amber's value is in its conventions, not its HTTP layer. (See GAP-2)

**What This Means:**
- The main entry point (`src/scribe.cr`) creates a native app loop, not `Amber::Server.start`
- Controllers are adapted to handle native events (not HTTP requests)
- Process managers work unchanged (they don't depend on HTTP)
- Configuration system (settings, environment) works unchanged
- The Amber server CAN be started in development mode for debugging/admin web UI
- `shard.yml` keeps amber as a dependency for its patterns and helpers

**Expected Wiring:**
```
App Launch → Native Event Loop → Event Dispatchers → Process Managers → Platform APIs
                                                   ↓
                                            UI Component Updates (via Asset Pipeline)
```

---

## Landmark 3: Asset Pipeline Cross-Platform UI is the View Layer

**Decision:** All UI rendering goes through the Asset Pipeline's cross-platform component system, using the platform-specific renderers (AppKitRenderer for macOS).

**Rationale:** This is the primary purpose of building Scribe — to exercise and validate the Asset Pipeline's experimental cross-platform UI. The app IS the test case.

**What This Means:**
- All views are built using `AssetPipeline::UI` components (Label, Button, VStack, etc.)
- The `AppKitRenderer` (platform visitor) translates these to NSView hierarchy
- No direct AppKit UI code outside the renderer — all UI goes through the abstraction
- Bugs found in the Asset Pipeline's UI system should be fixed upstream in the shard
- This is as much a validation exercise as it is app development

**Expected Component Tree (Main View):**
```
VStack
├── HStack (status bar)
│   ├── StatusIndicatorComponent (circle with color)
│   └── Label ("Idle" / "Recording 00:45" / "Transcribing...")
├── Spacer
├── Button ("Record" / "Stop") [large, centered]
├── Spacer
└── ScrollView (recent sessions)
    └── VStack
        ├── SessionRow (date, duration, preview)
        ├── SessionRow
        └── SessionRow
```

---

## Landmark 4: Process Managers Own All Business Logic

**Decision:** Every non-trivial operation is implemented as a Process Manager following FSDD grammar. No business logic in controllers or UI components.

**Rationale:** Process managers are testable, composable, and readable. They're the foundation of FSDD. Controllers/event handlers only validate input and delegate.

**What This Means:**
- Audio recording lifecycle → `Scribe::Recording::*` process managers
- Transcription → `Scribe::Transcription::*` process managers
- Output routing → `Scribe::Output::*` process managers
- CLI integration → `Scribe::Processing::*` process managers
- Each process manager: INITIALIZE with all data, single PERFORM entry, RESULTS as public properties

**Anti-patterns to Avoid:**
- Business logic in event handlers / controllers
- Direct platform API calls outside of platform abstractions
- Process managers making network calls in `initialize` (all data upfront)
- Conditional logic in `perform` method (push to private methods)

---

## Landmark 5: Platform Abstraction — Wrap Existing Libraries, Don't Reinvent

**Decision:** Use crystal-audio directly for audio, Asset Pipeline directly for UI. Only create new platform abstractions for clipboard and shortcuts (which don't have existing libraries).

**Rationale:** crystal-audio and the Asset Pipeline already provide battle-tested, platform-specific implementations. Wrapping them in another abstraction layer adds complexity without value. Only clipboard and shortcut operations need new FFI work — and they should follow the proven patterns from these libraries.

**What This Means:**

**Audio (use crystal-audio directly):**
```crystal
# No abstraction layer needed — crystal-audio IS the platform abstraction
recorder = CrystalAudio::Recorder.new(
  source: CrystalAudio::RecordingSource::Microphone,
  output_path: output_file_path
)
recorder.start
# ... recording ...
recorder.stop
```

**UI (use Asset Pipeline directly):**
```crystal
# No abstraction layer needed — renderers are compile-time selected
view = UI::VStack.new(spacing: 12.0)
view.children << UI::Label.new("Recording...", font: UI::Font.new(size: 18.0))

{% if flag?(:macos) %}
  renderer = UI::AppKit::Renderer.new
{% elsif flag?(:ios) %}
  renderer = UI::UIKit::Renderer.new
{% end %}
native_view = renderer.render(view)
```

**New Platform Abstractions (only where needed):**
- `Scribe::Platform::ClipboardManager` — New FFI (NSPasteboard pattern from crystal-audio's ObjC bridge)
- `Scribe::Platform::ShortcutListener` — New FFI (Carbon RegisterEventHotKey)
- `Scribe::Platform::NotificationSender` — New FFI (NSUserNotificationCenter)

**Anti-pattern:** Do NOT wrap crystal-audio or Asset Pipeline UI in Scribe-specific abstractions. Use them directly in process managers.

---

## Landmark 6: crystal-audio Owns the Recording + Transcription Pipeline

**Decision:** Use crystal-audio's `Recorder` for all audio capture and its `Transcription::Pipeline` for AI transcription. Do not build custom audio or transcription code.

**Rationale:** crystal-audio already provides microphone recording (macOS/iOS/Android), system audio capture (macOS), WAV/M4A output, and a Claude API-powered transcription pipeline. It even has sample apps for all platforms.

**What This Means:**
- Recording process managers wrap `CrystalAudio::Recorder` calls
- Transcription process managers wrap `CrystalAudio::Transcription::Pipeline`
- Native extensions (`crystal-audio/ext/*.o`) must be compiled and linked
- Link flags include AVFoundation, AudioToolbox, CoreAudio, etc.
- crystal-audio's thread-safe design (mutex, no-alloc callbacks) is already production-ready

**Build Integration:**
```bash
# In shard.yml:
dependencies:
  crystal-audio:
    github: crimson-knight/crystal-audio

# Build step:
cd lib/crystal-audio && make ext && cd ../..
crystal-alpha build src/scribe.cr --link-flags="lib/crystal-audio/ext/*.o [frameworks]"
```

**Transcription Modes Available:**
- `PipelineMode::Dictation` — Clean prose (haiku model, fast)
- `PipelineMode::Meeting` — Structured notes (opus model, thorough)
- `PipelineMode::Code` — Syntax-corrected code dictation (haiku model)

---

## Landmark 7: Claude Code CLI as an External Process (Post-Processing Only)

**Decision:** Claude Code runs as a completely separate process spawned by Scribe, communicating via JSON streaming on stdout.

**Rationale:** Claude Code CLI is a standalone tool. Embedding it would be fragile and version-dependent. Spawning it as a process provides clean boundaries, easy upgrades, and crash isolation.

**What This Means:**
- Scribe spawns `claude` CLI as a child process using `Process.new`
- Communication: prompt in via `--prompt` flag, progress out via stdout JSON stream
- No shared memory, no embedding, no library linking
- Scribe reads stdout line-by-line, parses JSON, updates UI
- Process lifecycle managed by Scribe (spawn, monitor, terminate)
- If `claude` CLI is not installed, AI post-processing is simply unavailable (graceful degradation)

**Expected Process Flow:**
```
Scribe (parent)                         Claude Code (child)
    │                                        │
    ├─ Process.new("claude", args) ─────────►│
    │                                        ├─ Parse prompt
    │◄── {"type":"assistant",...} ───────────┤
    │◄── {"type":"tool_use",...} ────────────┤  (streaming)
    │◄── {"type":"tool_result",...} ─────────┤
    │◄── {"type":"result",...} ──────────────┤
    │                                        │ (exit 0)
    ├─ Process exited ──────────────────────►│
    └─ Update ProcessingJob status
```

---

## Landmark 8: SQLite for All Local Storage

**Decision:** All persistent data (recordings, transcriptions, templates, settings) stored in a single SQLite database.

**Rationale:** Scribe is a single-user local app. SQLite is the right choice — zero config, embedded, fast, reliable. No server database needed.

**What This Means:**
- Grant ORM connects to SQLite
- Database file stored in app support directory (platform-specific)
- Migrations managed via Amber's database tools
- All models (Recording, Transcription, InstructionTemplate, etc.) backed by SQLite tables
- Settings can use a simple key-value table instead of config files

---

## Landmark 9: Event-Driven Architecture (Not Request/Response)

**Decision:** The application uses an event-driven architecture internally, not HTTP request/response.

**Rationale:** Native apps are event-driven — button presses, shortcut triggers, timer fires, process output. The controller layer should dispatch events, not handle HTTP requests.

**What This Means:**
- Define an internal event bus or callback system
- Events: `recording_started`, `recording_stopped`, `transcription_completed`, `processing_progress`, `processing_completed`
- UI components observe events and update reactively
- Process managers emit events as they progress through steps
- This replaces Amber's HTTP pipeline with a native event pipeline

**Expected Event Flow (Happy Path):**
```
User presses shortcut
  → :shortcut_triggered event
  → RecordingController handles event
  → StartAudioCapture process manager runs
  → :recording_started event
  → UI updates (red indicator, timer starts)

User presses shortcut again
  → :shortcut_triggered event
  → RecordingController handles event
  → StopAudioCaptureAndSave process manager runs
  → :recording_saved event
  → TranscribeRecordingViaWhisperApi process manager runs
  → :transcription_started event
  → UI updates (blue indicator)
  → :transcription_completed event
  → RouteTranscriptionToConfiguredDestinations process manager runs
  → :output_completed event
  → UI updates (green indicator, preview shown)
```

---

## Delegation Structure for Agents

When delegating implementation work, follow this hierarchy:

```
Project Manager (you)
  └── Team Lead (team-fsdd-manager or team-ops-project-setup)
        ├── Implementor (team-fsdd-implementer)
        │   - Writes the actual code
        │   - Must receive: feature story, conventions, platform constraints
        │   - Must output: working code that compiles
        └── Validator (team-fsdd-gate)
            - Reviews implementation against feature story
            - Checks naming conventions compliance
            - Verifies process manager structure
            - Runs tests
```

**Critical Rules:**
- Audio work: Implementor must reference `crystal-audio/samples/` for proven patterns
- UI work: Implementor must reference `asset_pipeline/.claude/skills/` for API docs
- Cross-compilation: Implementor must reference `asset_pipeline/scripts/` and `CROSS_COMPILE.md`
- New FFI (clipboard, shortcuts): Team lead should assign research first — follow patterns from crystal-audio's `ext/` directory
- The Scribe project skill at `.claude/skills/cross-platform-build/SKILL.md` contains the complete build reference
