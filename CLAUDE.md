# Scribe — Native Dictation & AI Assistant App

## What This Is

Scribe is a native cross-platform dictation app built with Crystal (via crystal-alpha compiler), Amber V2 patterns, Asset Pipeline cross-platform UI, and crystal-audio. It is also a showcase/validation project for the Asset Pipeline's view component system.

## Architecture (READ THIS FIRST)

**This is NOT a web app.** Despite using Amber V2, Scribe is a native background application:

- **macOS:** Menu bar app (NSStatusItem), no Dock icon
- Uses Amber's patterns (MVC, process managers, configuration) but NOT its HTTP server
- All UI rendered via Asset Pipeline cross-platform components → AppKitRenderer (macOS)
- Audio recording and transcription via crystal-audio library (not custom FFI)
- All business logic lives in Process Managers (FSDD pattern)
- Event-driven architecture, not request/response

## Key Libraries (Use Directly, Don't Wrap)

| Library | Purpose | DO NOT abstract further |
|---------|---------|------------------------|
| **crystal-audio** | Recording, playback, transcription | Use `CrystalAudio::Recorder` directly in process managers |
| **Asset Pipeline UI** | Cross-platform views | Use `UI::VStack`, `UI::Label`, etc. directly |
| **Amber V2** | Patterns only (controllers, config, ORM) | No HTTP server in production |

## Compiler

Use `crystal-alpha` (NOT `crystal`) for all builds:
```bash
crystal-alpha build src/scribe.cr -o bin/scribe --link-flags="..."
```

## Development Methodology

This project uses **Feature Story Driven Development (FSDD) v1.2.0**.

- All feature stories: `docs/fsdd/feature-stories/`
- Conventions: `docs/fsdd/conventions/conventions.md`
- Knowledge gaps: `docs/fsdd/knowledge-gaps/`
- Process managers: `docs/fsdd/process-managers/index.md`
- Build skill: `.claude/skills/cross-platform-build/SKILL.md`

## Critical Constraints

1. **macOS first.** Build and validate on macOS, then iOS, then Android.
2. **No HTTP server in production.** Native app uses an event loop, not Amber::Server.
3. **All UI through Asset Pipeline.** No direct AppKit code outside platform renderers.
4. **Use crystal-audio directly.** No Scribe-specific audio abstraction layer.
5. **Process managers own business logic.** Controllers/handlers only validate and delegate.
6. **FSDD naming conventions.** Follow `docs/fsdd/conventions/conventions.md` strictly.
7. **crystal-alpha compiler.** Required for cross-compilation targets.

## Key Directories

```
src/
├── controllers/      — Event handlers (adapted from Amber controllers)
├── models/           — Data models (Grant ORM + SQLite)
├── process_managers/ — All business logic (FSDD process managers)
├── ui/               — Views using Asset Pipeline UI components
├── platform/         — New FFI only (clipboard, shortcuts, notifications)
└── events/           — Internal event bus
```

## Build (macOS Development)

```bash
shards install
cd lib/crystal-audio && make ext && cd ../..
crystal-alpha build src/scribe.cr -o bin/scribe \
  --link-flags="lib/crystal-audio/ext/*.o \
    -framework AVFoundation -framework AudioToolbox -framework CoreAudio \
    -framework CoreFoundation -framework CoreMedia -framework Foundation \
    -framework ScreenCaptureKit"
./bin/scribe
```

## Cross-Platform Builds

See `.claude/skills/cross-platform-build/SKILL.md` for iOS and Android build commands.
