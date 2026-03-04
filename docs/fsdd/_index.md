# Scribe — FSDD Project Index

**Version:** 0.1.0
**FSDD Version:** 1.2.0
**Status:** Planning (Updated — Most Critical Gaps Resolved)

## Project Summary

Scribe is a native cross-platform dictation and personal assistant application built with Crystal (via crystal-alpha compiler), Amber V2 patterns, Asset Pipeline cross-platform UI, and crystal-audio. It runs as a background service on macOS, iOS, and Android, triggered by keyboard shortcut to record audio, transcribe via whisper.cpp + Claude API (crystal-audio pipeline), and optionally post-process transcriptions through Claude Code CLI.

**Key Libraries:** crystal-alpha (compiler), crystal-audio (recording + transcription), Asset Pipeline (UI), Amber V2 (patterns)

## Document Map

### Foundation Documents
- [Personas](personas/personas.md) — Who uses Scribe and what they're authorized to do
- [Tech Stack](tech-stack/tech-stack.md) — Vendors, features, and feature-to-vendor mapping
- [Conventions](conventions/conventions.md) — Naming patterns, code structure, expression patterns
- [Jargon](jargon/jargon.md) — Domain-specific vocabulary with implementation meaning

### Feature Stories (by Epic)
- [Epic 1: Application Shell](feature-stories/epic-1-application-shell.md) — Native app lifecycle, menu bar, background service
- [Epic 2: Audio Recording](feature-stories/epic-2-audio-recording.md) — Microphone capture, keyboard trigger, recording state
- [Epic 3: Transcription](feature-stories/epic-3-transcription.md) — AI-powered speech-to-text conversion
- [Epic 4: Output Management](feature-stories/epic-4-output-management.md) — Clipboard, paste, file save, output routing
- [Epic 5: AI Post-Processing](feature-stories/epic-5-ai-post-processing.md) — Claude Code CLI integration, instruction templates, streaming
- [Epic 6: Configuration](feature-stories/epic-6-configuration.md) — Settings, output directory, shortcuts, templates

### Process Managers
- [Process Manager Index](process-managers/index.md) — All non-RESTful business logic processes

### Architecture & Knowledge Gaps
- [Knowledge Gaps](knowledge-gaps/knowledge-gaps.md) — Known unknowns, architectural risks, agent confusion points
- [Architectural Landmarks](knowledge-gaps/architectural-landmarks.md) — Key decisions and expectations for wiring

## Implementation Priority

1. **Epic 1** — Application Shell (must exist before anything else)
2. **Epic 2** — Audio Recording (core value proposition)
3. **Epic 3** — Transcription (transforms recording into useful output)
4. **Epic 4** — Output Management (delivers value to user)
5. **Epic 6** — Configuration (enables customization)
6. **Epic 5** — AI Post-Processing (advanced feature, highest complexity)

## Test Coverage Status

### macOS Desktop (Epics 1-4)

| Story | Layer 1 (Crystal) | Layer 2 (UI Test) | Layer 3 (E2E) | Coverage |
|---|---|---|---|---|
| 1.1 Menu Bar App | Pass (state + config) | osascript (4 tests) | E2E (build+launch) | Covered |
| 1.4 Menu Dropdown | Pass (state) | osascript (3 tests) | E2E (via L2) | Covered |
| 1.5 Keyboard Shortcut | Pass (state) | N/A | E2E (log check) | Partial |
| 2.2 Start Recording | Pass (8 tests) | N/A | Requires hardware | Partial |
| 2.3 Stop Recording | Pass (state) | N/A | Requires hardware | Partial |
| 3.1 Transcription | Pass (6 tests) | N/A | Model load check | Partial |
| 4.1 Clipboard Paste | Pass (2 tests) | N/A | Requires a11y | Partial |
| 4.2 Transcript Format | Pass (2 tests) | N/A | N/A | Partial |
| WAV Parsing | Pass (7 tests) | N/A | N/A | Covered |

### Mobile (Epic 7)

| Story | Layer 1 (Crystal) | Layer 2 (UI Test) | Layer 3 (E2E) | Coverage |
|---|---|---|---|---|
| 7.1 iOS Record | Partial (state) | Pass (3 tests) | Ready | Partial |
| 7.2 Android Record | Partial (state) | Pass (3 tests) | Ready | Partial |
| 7.3 iOS Recordings | Partial (state) | Pass (1 test) | Ready | Partial |
| 7.4 Android Recordings | Partial (state) | Pass (2 tests) | Ready | Partial |
| 7.5 iOS Settings | N/A | Pass (2 tests) | Ready | Partial |
| 7.6 Android Settings | N/A | Pass (2 tests) | Ready | Partial |
| 7.7 Audio Format | N/A | Pass (2 tests, Android only) | Ready | Partial |

**Note:** Cross-story navigation tests (`testAllThreeTabsAccessible` on iOS, `allThreeTabs_accessible` on Android) verify all three tabs are accessible but are not counted in individual story rows above. L3 "Ready" means E2E shell scripts exist and are executable (`mobile/ios/test_scribe_ios.sh`, `mobile/android/test_scribe_android.sh`, `test/macos/test_scribe_macos.sh`).

For detailed testability analysis, see [Partial Testability — Epic 7](testing/partial-testability-epic-7.md).

### Testing Documentation
- [Testing Architecture](testing/TESTING_ARCHITECTURE.md) — 3-layer test strategy, file inventory, how to add tests
- [Bridge Spec Replication Decision](testing/bridge-spec-replication-decision.md) — Option A vs B analysis, drift mitigation
- [Partial Testability — Epic 7](testing/partial-testability-epic-7.md) — Detailed testability analysis for mobile recording
