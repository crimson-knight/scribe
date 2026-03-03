# Scribe — Jargon

Domain-specific vocabulary that carries implementation meaning. When these terms are used in feature stories, they invoke the full implementation pattern described here.

## Recording Session

**Definition:** The complete lifecycle from the moment the User triggers recording until the audio file is saved to disk.

**Implementation:** Creates a `Recording` model instance, activates the platform-specific `AudioRecorder`, captures audio data, and writes to a file in the configured audio output directory.

**Usage:** "Start a recording session" means: save clipboard state, activate microphone, show recording indicator, begin capturing audio.

## Transcription

**Definition:** The AI-powered conversion of a saved audio file into plain text.

**Implementation:** Sends the audio file to the configured transcription provider (Whisper API or on-device Speech framework), receives text, creates a `Transcription` model linked to the source `Recording`.

**Usage:** "Transcribe the recording" means: upload audio to provider, wait for response, save text content, link to source recording.

## Clipboard Cycle

**Definition:** The three-step clipboard operation: save current → paste new content → restore original.

**Implementation:**
1. Read and store the current clipboard contents (via platform `ClipboardManager`)
2. Write the transcription text to the clipboard
3. Simulate a paste keystroke (Cmd+V / Ctrl+V)
4. After a brief delay, restore the original clipboard contents

**Usage:** "Perform a clipboard cycle" means: execute all four steps so the User's original clipboard is preserved after paste.

## Output Directory

**Definition:** The User-configured filesystem path where transcriptions, processed files, and AI outputs are saved.

**Implementation:** Stored in `OutputConfiguration.output_directory_path`. Validated on configuration change. Claude Code CLI is scoped to this directory for file operations.

**Usage:** "Save to the output directory" means: write the file to the path stored in `OutputConfiguration`, creating subdirectories as needed.

## Instruction Template

**Definition:** A reusable prompt/instruction set that tells Claude Code CLI how to process a transcription.

**Implementation:** Stored as `InstructionTemplate` model. Contains the prompt text with `{{transcription}}` placeholder. One template can be marked as `is_default_template`.

**Usage:** "Apply the instruction template" means: load the template, substitute the transcription content, pass to Claude Code CLI.

## Post-Processing

**Definition:** The act of running a transcription through Claude Code CLI with an instruction template to produce structured output.

**Implementation:** Creates a `ProcessingJob`, spawns a Claude Code CLI process with the instruction template and transcription, reads JSON streaming output, updates job status in real-time.

**Usage:** "Post-process the transcription" means: spawn CLI, stream progress, save outputs to output directory.

## JSON Stream

**Definition:** The real-time output from Claude Code CLI that reports progress, tool usage, and completion status.

**Implementation:** Claude Code CLI with `--output-format stream-json` writes newline-delimited JSON objects to stdout. Each object has a `type` field (e.g., `assistant`, `tool_use`, `tool_result`, `result`). Scribe reads these line-by-line to update the UI.

**Usage:** "Read the JSON stream" means: parse each line as JSON, dispatch based on type, update ProcessingJob status and UI components.

## Menu Bar App (macOS)

**Definition:** The application's presence as an NSStatusItem in the macOS menu bar (not in the Dock).

**Implementation:** Uses AppKit's NSStatusItem with NSMenu. Shows recording state via icon changes. Dropdown menu provides access to settings, history, and manual trigger.

**Usage:** "The menu bar app" refers to the macOS-specific application shell running as a status bar item.

## Foreground Service (Android)

**Definition:** The Android service that keeps the app alive for recording, with a persistent notification.

**Implementation:** Android Foreground Service with NotificationManager. Required by Android to keep audio recording active when the app is in the background.

**Usage:** "Start the foreground service" means: create a persistent notification and start the Android service for audio capture.

## Global Shortcut

**Definition:** A keyboard shortcut that works regardless of which application has focus.

**Implementation:**
- **macOS:** CGEvent tap or Carbon RegisterEventHotKey
- **iOS:** Limited — uses Siri Shortcuts integration or Control Center widget
- **Android:** Accessibility service or media button interception

**Usage:** "Register the global shortcut" means: set up the platform-specific keyboard listener for the User's configured key combination.

## Scribe Session

**Definition:** The complete end-to-end flow: trigger → record → transcribe → output/post-process.

**Implementation:** Orchestrated by a top-level process manager that coordinates the recording, transcription, output, and optional post-processing steps.

**Usage:** "Complete a Scribe session" means: execute the full pipeline from keyboard trigger to final output delivery.
