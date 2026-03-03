# Scribe — Personas

## User (Primary Persona)

**Description:** The person using Scribe on their device for dictation and AI-assisted note management.

**Authorization Level:** Full access to all application features on their own device.

**Scope Boundaries:**
- Can configure all settings (output directory, keyboard shortcuts, AI instructions)
- Can trigger and stop recordings
- Can view transcription history
- Can manage AI instruction templates
- Can configure clipboard behavior
- Owns all recorded audio and transcription data

**UI Context:**
- **macOS:** Menu bar icon with dropdown, global keyboard shortcut, notification center alerts
- **iOS:** Background audio session, Control Center integration, notification-based status
- **Android:** Foreground service notification, quick settings tile, keyboard shortcut (physical keyboard)

**Naming Convention:** Always referred to as "User" in feature stories. No authentication system needed — this is a personal, single-user application.

## System (Background Persona)

**Description:** The application itself acting autonomously — scheduled tasks, file watchers, and background processes.

**Authorization Level:** Operates within User-configured boundaries.

**Scope Boundaries:**
- Can write files only to User-configured output directory
- Can invoke Claude Code CLI with User-configured instructions
- Can access microphone only when User triggers recording
- Can read/write application configuration
- Cannot access network resources beyond transcription API and Claude Code CLI

**UI Context:**
- Status updates via native notifications
- Log output for debugging
- JSON streaming for real-time progress to the native UI

**Naming Convention:** Referenced as "System" in feature stories. Used with time-based and recurring initiator clauses.

## Claude Code CLI (API Consumer Persona)

**Description:** The Claude Code process spawned by Scribe to post-process transcriptions.

**Authorization Level:** Scoped to the configured output directory and tools provided.

**Scope Boundaries:**
- Can read/write/update files in the configured output directory
- Can read the transcription content provided via stdin/args
- Can use tools specified in the instruction template
- Cannot access other system resources beyond what's explicitly provided
- Reports progress via JSON streaming to stdout

**Naming Convention:** Referenced as "Claude Code CLI" or "AI Assistant" in feature stories. Represents the external process integration.
