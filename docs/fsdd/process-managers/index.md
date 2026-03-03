# Scribe — Process Manager Index

All non-RESTful business logic processes defined in the feature stories.

**Key Principle:** Process managers use crystal-audio and Asset Pipeline UI directly — no intermediate abstraction layers.

## Recording Domain (wraps CrystalAudio::Recorder)

| Process Manager | Feature Story | Purpose |
|----------------|---------------|---------|
| `Scribe::Recording::StartAudioCapture` | Story 2.2 | Verify permissions, save clipboard, create CrystalAudio::Recorder, start recording, create DB entry |
| `Scribe::Recording::StopAudioCaptureAndSave` | Story 2.3 | Call recorder.stop, update DB, trigger transcription |
| `Scribe::Recording::CancelActiveRecording` | Story 2.4 | Discard recording, restore clipboard, clean up |
| `Scribe::Recording::RequestMicrophonePermission` | Story 2.1 | Request platform-specific microphone permission |

## Transcription Domain (wraps CrystalAudio::Transcription::Pipeline)

| Process Manager | Feature Story | Purpose |
|----------------|---------------|---------|
| `Scribe::Transcription::TranscribeRecording` | Story 3.1 | Run whisper.cpp → Claude API pipeline, save transcription |
| `Scribe::Transcription::TranscribeRecordingOffline` | Story 3.2 | Whisper-only (no Claude API formatting) |
| `Scribe::Transcription::RetryFailedTranscription` | Story 3.4 | Retry with same/different mode |

## Output Domain (new platform FFI for clipboard)

| Process Manager | Feature Story | Purpose |
|----------------|---------------|---------|
| `Scribe::Output::PasteTranscriptionViaClipboardCycle` | Story 4.1 | Clipboard write → paste → restore cycle |
| `Scribe::Output::SaveTranscriptionToOutputDirectory` | Story 4.2 | Write transcription file to configured directory |
| `Scribe::Output::RouteTranscriptionToConfiguredDestinations` | Story 4.5 | Orchestrate multiple output modes |

## Processing Domain (Claude Code CLI external process)

| Process Manager | Feature Story | Purpose |
|----------------|---------------|---------|
| `Scribe::Processing::SpawnClaudeCodeCliWithInstructions` | Story 5.1 | Build prompt, spawn CLI process, begin streaming |
| `Scribe::Processing::StreamJsonProgressFromCliProcess` | Story 5.2 | Read stdout JSON stream, parse events, update UI |
| `Scribe::Processing::CompletePostProcessingJob` | Story 5.3 | Finalize job status, summarize results |
| `Scribe::Processing::CancelActiveProcessingJob` | Story 5.6 | Terminate CLI process, preserve partial results |

## Application Domain

| Process Manager | Feature Story | Purpose |
|----------------|---------------|---------|
| `Scribe::Application::LaunchAsMenuBarApp` | Story 1.1 | macOS NSStatusItem setup, event loop |
| `Scribe::Application::LaunchAsIosApp` | Story 1.2 | iOS app lifecycle setup |
| `Scribe::Application::LaunchAsAndroidService` | Story 1.3 | Android foreground service setup |

## Dependency Summary

| Domain | External Library | Abstraction Layer |
|--------|-----------------|-------------------|
| Recording | `CrystalAudio::Recorder` | None (use directly) |
| Transcription | `CrystalAudio::Transcription::Pipeline` | None (use directly) |
| UI | `UI::*` views + platform renderers | None (use directly) |
| Clipboard | New `Scribe::Platform::ClipboardManager` | Abstract class + macOS impl |
| Shortcuts | New `Scribe::Platform::ShortcutListener` | Abstract class + macOS impl |
| Notifications | New `Scribe::Platform::NotificationSender` | Abstract class + macOS impl |
| Post-Processing | `Process.new("claude", ...)` | None (Crystal stdlib) |

## Total: 17 Process Managers across 4 domains + 3 app lifecycle
