# Scribe — Implementation Plan

**Date:** 2026-03-03
**Status:** DRAFT — Awaiting review before execution
**FSDD Version:** 1.2.0

---

## Current State

The Scribe macOS app compiles and runs as a 5.2MB arm64 binary. The following is already working:

| What | Status | File(s) |
|------|--------|---------|
| Menu bar icon (NSStatusItem) with mic SF Symbol | Working | `src/platform/macos/app.cr` |
| Dropdown menu (Start Recording, Output dir, Quit) | Working | `src/platform/macos/app.cr` |
| Global hotkey (Option+Shift+R) via Carbon | Working | `scribe_platform_bridge.m` + `app.cr` |
| Recording toggle (start/stop via hotkey) | Working | `src/process_managers/start_audio_capture.cr` |
| WAV file save to `~/Scribe/` | Working | `start_audio_capture.cr` (via crystal-audio) |
| Menu bar icon state change (mic ↔ record.circle.fill) | Working | `app.cr` update_status_recording |
| Amber V2 config (no HTTP server) | Working | `config/application.cr` |
| Asset Pipeline UI definition (MainView) | Compiles, not wired to window | `src/ui/main_view.cr` |
| ObjC bridges (Asset Pipeline + Scribe platform) | Compiled | `objc_bridge.o` + `scribe_platform_bridge.o` |
| crystal-audio native extensions | Compiled | `lib/crystal-audio/ext/*.o` |
| Makefile build pipeline | Working | `Makefile` |

**Not yet built:**
- Database (SQLite via Grant ORM) — no models, no migrations
- Transcription (crystal-audio pipeline integration)
- Clipboard cycle (save → paste → restore)
- Settings UI (output directory, shortcut config, API keys)
- Claude Code CLI spawning and JSON stream parsing
- Event bus (internal pub/sub for UI updates)
- iOS / Android targets

---

## Implementation Phases

The phases follow the Epic priority order from `_index.md`: Shell → Recording → Transcription → Output → Configuration → AI Post-Processing. Within each phase, stories are implemented in dependency order.

### Phase 1: Validate Core Recording Loop (Stories 1.1, 1.4, 1.5, 2.2, 2.3)

**Goal:** User can hit Option+Shift+R, record audio, hit it again, and find a playable WAV file.

**Current Progress:** ~80% complete. App runs, hotkey works, recording starts/stops, file saves.

**Remaining Work:**
1. **Manual test** the end-to-end flow: launch → hotkey → record → hotkey → check WAV file
2. Fix any audio quality issues (verify 44.1kHz 16-bit output)
3. Verify the menu item title toggle ("Start Recording" ↔ "Stop Recording") works

**Stories Covered:** 1.1 (menu bar launch), 1.4 (menu dropdown), 1.5 (global shortcut), 2.2 (start recording), 2.3 (stop and save)

**Process Managers Involved:**
- `Scribe::Recording::StartAudioCapture` — exists, basic impl
- `Scribe::Recording::StopAudioCaptureAndSave` — partially covered by `start_audio_capture.cr` stop method

**Delegation Plan:**
- No subagent needed — this is manual testing with the user
- Document results in knowledge gaps if issues found

---

### Phase 2: Database & Models (Foundation for all data-driven stories)

**Goal:** Set up SQLite database with Grant ORM, create core models, run migrations.

**Stories Covered:** Foundation for 2.2-2.5, 3.1-3.4, 4.1-4.5, 5.1-5.6, 6.1-6.9

**Work Items:**
1. Add `granite` (Grant ORM) to shard.yml if not already present
2. Create database migration for initial schema:
   - `recordings` table (file_path, duration, status, recorded_at, has_been_transcribed)
   - `transcriptions` table (content, recording_id, provider_name, transcribed_at)
   - `instruction_templates` table (name, prompt_content, is_default)
   - `output_configurations` table (directory_path, format_type, clipboard_restore_enabled)
   - `processing_jobs` table (transcription_id, template_id, status, started_at, completed_at)
   - `application_settings` table (key, value, category)
3. Create Crystal model files in `src/models/`
4. Database file location: `~/Library/Application Support/Scribe/scribe.db`
5. Auto-create DB on first launch

**Process Managers Involved:** None directly — this is infrastructure

**Delegation Plan:**
- Team lead → implementor: Create models following conventions.md naming
- Team lead → validator: Check naming compliance, verify migrations run

---

### Phase 3: Full Recording Lifecycle (Stories 2.1, 2.4, 2.5)

**Goal:** Permission request, cancel recording, duration timer display.

**Stories Covered:** 2.1, 2.4, 2.5

**Work Items:**
1. **Story 2.1 — Microphone Permission:**
   - Add `NSMicrophoneUsageDescription` to Info.plist (for app bundling)
   - Implement `Scribe::Recording::RequestMicrophonePermission` process manager
   - Add permission check before each recording attempt
   - New C bridge function: `scribe_request_microphone_permission()` using AVCaptureDevice

2. **Story 2.4 — Cancel Recording:**
   - Register Escape key as cancel hotkey (or add Cancel to menu)
   - Implement `Scribe::Recording::CancelActiveRecording` process manager
   - Delete temporary audio file, restore clipboard

3. **Story 2.5 — Duration Timer:**
   - This requires the event bus (or simple timer callback)
   - Update menu bar title to show "REC 00:45" during recording
   - Use `Crystal::Timer` or NSTimer via bridge

**Process Managers to Implement:**
- `Scribe::Recording::RequestMicrophonePermission` — new
- `Scribe::Recording::CancelActiveRecording` — new

**Delegation Plan:**
- Team lead → implementor: Each process manager + bridge extensions
- Team lead → validator: Test each scenario

---

### Phase 4: Transcription Pipeline (Stories 3.1, 3.2, 3.3, 3.4)

**Goal:** After recording stops, audio is transcribed via whisper.cpp + Claude API.

**Stories Covered:** 3.1, 3.2, 3.3, 3.4

**Work Items:**
1. **Story 3.1 — Transcribe via Whisper API:**
   - Integrate `CrystalAudio::Transcription::Pipeline` in a new process manager
   - Requires ANTHROPIC_API_KEY in settings
   - Run whisper locally, then Claude API for formatting
   - Save Transcription model to database

2. **Story 3.2 — Offline Fallback:**
   - Whisper-only mode (no Claude formatting)
   - Auto-detect when API unreachable

3. **Story 3.3 — Preview:**
   - Display transcription text in the menu bar dropdown or a popover
   - Add "Copy" and "Post-Process" actions

4. **Story 3.4 — Retry:**
   - On failure, store error and allow manual retry

**Dependencies:**
- Phase 2 (database models for Transcription)
- whisper.cpp must be available (crystal-audio dependency)
- ANTHROPIC_API_KEY must be configured

**Process Managers to Implement:**
- `Scribe::Transcription::TranscribeRecording` — new
- `Scribe::Transcription::TranscribeRecordingOffline` — new
- `Scribe::Transcription::RetryFailedTranscription` — new

**Knowledge Gap Check:**
- Need to verify whisper.cpp integration status in crystal-audio
- Need to verify CrystalAudio::Transcription::Pipeline API exists and is functional

---

### Phase 5: Output Management (Stories 4.1, 4.2, 4.3, 4.5)

**Goal:** Transcriptions delivered to user via clipboard paste, file save, or both.

**Stories Covered:** 4.1, 4.2, 4.3, 4.5

**Work Items:**
1. **Story 4.1 — Clipboard Cycle:**
   - Port clipboard bridge from POC 3 (`clipboard_bridge.m`) to production
   - Add `scribe_clipboard_read`, `scribe_clipboard_write`, `scribe_paste_keystroke` to bridge
   - Implement save → write → paste → restore cycle
   - Requires Accessibility permission for paste simulation (CGEvent)

2. **Story 4.2 — File Save:**
   - Save transcription as .md file with YAML frontmatter
   - File naming pattern: `YYYY-MM-DD_HH-MM_transcription.md`
   - Write to configured output directory

3. **Story 4.3 — Clipboard Only:**
   - Simple clipboard write, no paste simulation

4. **Story 4.5 — Route to Multiple:**
   - Orchestrate clipboard + file save based on configuration

**Dependencies:**
- Phase 2 (OutputConfiguration model)
- Phase 4 (transcription must complete first)
- POC 3 clipboard bridge code (already validated)

**Process Managers to Implement:**
- `Scribe::Output::PasteTranscriptionViaClipboardCycle` — new
- `Scribe::Output::SaveTranscriptionToOutputDirectory` — new
- `Scribe::Output::RouteTranscriptionToConfiguredDestinations` — new

---

### Phase 6: Configuration UI (Stories 6.1, 6.2, 6.3, 6.5, 6.7, 6.8, 6.9)

**Goal:** Settings window with output directory picker, shortcut config, audio quality, auto-transcribe toggle.

**Stories Covered:** 6.1, 6.2, 6.3, 6.5, 6.7, 6.8, 6.9

**Work Items:**
1. **Story 6.1 — Settings Window:**
   - Create settings window using Asset Pipeline UI components
   - Open via menu bar dropdown "Settings..." item
   - Wire NSWindow creation + content view from Asset Pipeline

2. **Story 6.2 — Output Directory:**
   - Add NSOpenPanel bridge for directory picker
   - Save selected path to OutputConfiguration

3. **Story 6.3 — Keyboard Shortcut Config:**
   - Shortcut recorder UI (capture next key combination)
   - Re-register Carbon hotkey with new combination

4. Other settings: audio quality, launch at login, auto-transcribe, auto-post-process toggles

**Dependencies:**
- Phase 2 (ApplicationSetting model)
- Asset Pipeline view rendering working in an NSWindow (GAP-9 partially resolved)

**Knowledge Gap Risk:** GAP-9 — reactive UI updates and button callbacks from Asset Pipeline views back to Crystal are NOT YET PROVEN. This phase will likely expose gaps.

---

### Phase 7: AI Post-Processing (Stories 5.1, 5.2, 5.3, 5.4, 5.5, 5.6)

**Goal:** Spawn Claude Code CLI with transcription + instruction template, stream progress.

**Stories Covered:** 5.1-5.6

**Work Items:**
1. **Story 5.1 — Spawn Claude CLI:**
   - `Process.new("claude", ...)` with `--output-format stream-json`
   - Build prompt from InstructionTemplate + transcription text
   - Scope allowed tools to file operations in output directory

2. **Story 5.2 — Stream JSON Progress:**
   - Read stdout line-by-line
   - Parse JSON events (assistant, tool_use, tool_result, result, error)
   - Update UI with human-readable status

3. **Story 5.4 — Instruction Templates:**
   - CRUD UI for templates
   - Default templates: "Meeting Notes", "Quick Note", "Todo Update"

4. **Story 5.6 — Cancel Processing:**
   - SIGTERM → wait 5s → SIGKILL

**Dependencies:**
- Phase 2 (ProcessingJob, InstructionTemplate models)
- Phase 4 (transcription text available)
- Phase 6 (template management UI)
- `claude` CLI installed on user's system

---

### Phase 8: Polish & Platform Expansion

**Goal:** iOS/Android targets, app bundling, notifications, production readiness.

**Work Items:**
1. macOS app bundle (.app) with Info.plist, code signing
2. iOS target via crystal-alpha cross-compilation + Xcode project
3. Android target via crystal-alpha cross-compilation + Android Studio
4. macOS native notifications (NSUserNotificationCenter) for status changes
5. Launch at login (SMAppService)
6. Error handling and edge cases across all process managers

---

## Delegation Structure

```
Project Manager (Claude — this session)
  └── Team Lead (subagent)
        ├── Implementor (subagent)
        │   - Receives: feature story, conventions, platform constraints
        │   - Outputs: working code that compiles
        │   - References: crystal-audio samples, asset_pipeline skills
        └── Validator (subagent)
            - Reviews against feature story acceptance criteria
            - Checks naming conventions
            - Verifies process manager structure
            - Confirms compilation
```

Each Phase is a delegatable unit. The Team Lead receives the Phase description and all relevant feature stories, then breaks it into implementor + validator tasks.

---

## Known Blockers & Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| GAP-9: Asset Pipeline reactive updates not proven | Phase 6 may stall | Test early with a simple settings window |
| GAP-12: Amber schema spam on startup | Cosmetic annoyance | Patch Amber locally or ignore |
| GAP-14: crystal-audio shard name | Build confusion | Symlink in Makefile setup target (done) |
| GAP-17: `type` vs `alias` for C callbacks | Build confusion | Documented, use `alias` always |
| whisper.cpp availability in crystal-audio | Phase 4 may need work | Verify crystal-audio transcription pipeline status |
| Accessibility permission for paste simulation | Phase 5 clipboard cycle | Graceful fallback to clipboard-only mode |
| SQLite/Grant ORM with crystal-alpha | Phase 2 — untested combo | Test early |

---

## Immediate Next Steps (Before Execution)

1. **Review this plan** — User approves/modifies phase order and scope
2. **Manual test Phase 1** — Launch app, hit Option+Shift+R, verify WAV file
3. **File GitHub issues** — crystal-audio shard naming, Amber schema spam (Task #24)
4. **Begin Phase 2** — Database setup (smallest blast radius, enables all later phases)

---

## Completion Promise Criteria

The Ralph Loop completion promise `RECORDING_READY` requires:
- App launches as menu bar icon
- Option+Shift+R starts recording
- Same shortcut stops recording
- WAV file saved to configured directory
- WAV file is playable and contains the recorded audio

**Current assessment:** All code is in place. Needs manual verification that the recording actually captures audio (crystal-audio Recorder integration). The promise can be TRUE once the user confirms the WAV file plays back correctly.
