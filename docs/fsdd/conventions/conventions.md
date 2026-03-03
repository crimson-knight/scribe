# Scribe — Conventions

## Naming Conventions

### Data Models

| Model | Purpose | Key Attributes |
|-------|---------|---------------|
| `Recording` | A single audio capture session | `file_path_to_audio`, `duration_in_seconds`, `recorded_at`, `has_been_transcribed` |
| `Transcription` | Text output from a recording | `content_as_plain_text`, `source_recording_id`, `transcribed_at`, `transcription_provider_name` |
| `InstructionTemplate` | Reusable AI processing instructions | `template_name`, `prompt_content`, `is_default_template` |
| `OutputConfiguration` | Where and how to deliver results | `output_directory_path`, `output_format_type`, `is_clipboard_restore_enabled` |
| `ProcessingJob` | A Claude Code CLI execution | `transcription_id`, `instruction_template_id`, `current_status`, `started_at`, `completed_at` |
| `ApplicationSetting` | Key-value configuration store | `setting_key`, `setting_value`, `setting_category` |

### Attribute Naming Patterns

Following FSDD conventions:

- **Primitives as short statements:** `file_path`, `duration_in_seconds`, `recorded_at`
- **Collections with descriptive prefixes:** `list_of_recent_recordings`, `array_of_available_templates`
- **Booleans as yes/no questions:** `has_been_transcribed`, `is_currently_recording`, `is_clipboard_restore_enabled`, `is_default_template`
- **Non-primitives as descriptive statements:** `currently_active_recording`, `most_recent_transcription`

### Class Naming

All classes are namespaced by feature domain:

```
Scribe::Recording::StartAudioCapture
Scribe::Recording::StopAudioCaptureAndSave
Scribe::Transcription::TranscribeRecordingViaWhisperApi
Scribe::Output::PasteTranscriptionToClipboard
Scribe::Output::RestoreOriginalClipboardContent
Scribe::Output::SaveTranscriptionToOutputDirectory
Scribe::Processing::SpawnClaudeCodeCliWithInstructions
Scribe::Processing::StreamJsonProgressFromCliProcess
Scribe::Configuration::UpdateOutputDirectoryPath
Scribe::Configuration::SetDefaultInstructionTemplate
```

### Method Naming

Methods read as plain statements describing what they do:

```crystal
def start_recording_audio_from_microphone
def stop_recording_and_save_audio_file
def transcribe_audio_file_via_whisper_api
def paste_transcription_text_to_active_input
def save_clipboard_contents_before_paste
def restore_clipboard_to_previous_contents
def spawn_claude_code_cli_with_prompt_and_transcript
def read_json_stream_from_cli_process
```

### File Organization

```
src/
├── scribe.cr                                    # Application entry point (native event loop)
├── config/
│   └── application.cr                           # Amber configuration (no HTTP server)
├── controllers/
│   ├── application_controller.cr                # Base event handler
│   ├── recording_controller.cr                  # Recording lifecycle events
│   ├── transcription_controller.cr              # Transcription events
│   └── settings_controller.cr                   # Configuration events
├── models/
│   ├── recording.cr                             # Recording data model (Grant ORM)
│   ├── transcription.cr                         # Transcription data model
│   ├── instruction_template.cr                  # AI instruction templates
│   ├── output_configuration.cr                  # Output settings
│   ├── processing_job.cr                        # CLI job tracking
│   └── application_setting.cr                   # Key-value settings
├── process_managers/
│   ├── recording/
│   │   ├── start_audio_capture.cr               # Wraps CrystalAudio::Recorder
│   │   └── stop_audio_capture_and_save.cr       # Stops recording, saves file
│   ├── transcription/
│   │   └── transcribe_recording.cr              # Wraps CrystalAudio::Transcription::Pipeline
│   ├── output/
│   │   ├── paste_transcription_to_clipboard.cr
│   │   ├── restore_original_clipboard_content.cr
│   │   └── save_transcription_to_output_directory.cr
│   └── processing/
│       ├── spawn_claude_code_cli_with_instructions.cr
│       └── stream_json_progress_from_cli_process.cr
├── ui/
│   ├── app.cr                                   # Native app shell (NSStatusItem on macOS)
│   ├── views/
│   │   ├── menu_bar_view.cr                     # macOS menu bar dropdown
│   │   ├── main_view.cr                         # Main control interface (UI::VStack)
│   │   ├── recording_indicator_view.cr          # Recording state UI
│   │   ├── transcription_preview_view.cr        # Transcription display
│   │   ├── settings_view.cr                     # Configuration screen
│   │   └── processing_progress_view.cr          # CLI progress display
│   └── components/
│       ├── status_indicator_component.cr         # Recording/idle status circle
│       ├── waveform_component.cr                 # Audio waveform display
│       └── progress_stream_component.cr          # JSON stream progress
├── platform/
│   ├── clipboard/                               # NEW FFI (follows crystal-audio patterns)
│   │   ├── clipboard_manager.cr                 # Abstract clipboard interface
│   │   └── macos_clipboard_manager.cr           # NSPasteboard + CGEvent paste
│   ├── shortcuts/                               # NEW FFI (follows crystal-audio patterns)
│   │   ├── shortcut_listener.cr                 # Abstract shortcut interface
│   │   └── macos_shortcut_listener.cr           # Carbon RegisterEventHotKey
│   └── notifications/                           # NEW FFI (follows crystal-audio patterns)
│       ├── notification_sender.cr               # Abstract notification interface
│       └── macos_notification_sender.cr          # NSUserNotificationCenter
└── events/
    └── event_bus.cr                             # Internal event dispatch system
```

**Note:** Audio recording and transcription use `crystal-audio` directly (no Scribe abstraction layer).
UI components use Asset Pipeline `UI::*` views directly with platform renderers.
Only clipboard, shortcuts, and notifications need new platform-specific code.

## Code Structure Conventions

### Library Usage Convention

**Use existing libraries directly — do not wrap them:**

```crystal
# CORRECT — Use crystal-audio directly in process managers
class Scribe::Recording::StartAudioCapture
  def initialize(@output_path : String)
    @recorder = CrystalAudio::Recorder.new(
      source: CrystalAudio::RecordingSource::Microphone,
      output_path: @output_path
    )
  end
end

# CORRECT — Use Asset Pipeline UI directly in views
def build_main_view : UI::VStack
  UI::VStack.new(spacing: 12.0).tap do |v|
    v.children << UI::Label.new("Scribe", font: UI::Font.new(size: 24.0, weight: :bold))
    v.children << UI::Button.new("Record") { handle_record_button }
  end
end

# WRONG — Do not create unnecessary abstraction layers
abstract class Scribe::Platform::AudioRecorder  # ← Don't do this
```

### New Platform Abstraction Pattern (Only for Clipboard, Shortcuts, Notifications)

For platform features that DON'T have existing Crystal libraries, follow crystal-audio's FFI patterns:

```crystal
# Abstract interface (only for NEW platform code)
abstract class Scribe::Platform::ClipboardManager
  abstract def read_clipboard_contents : String
  abstract def write_to_clipboard(text : String) : Void
  abstract def simulate_paste_keystroke : Void
end

# macOS implementation follows crystal-audio's ObjC FFI patterns
class Scribe::Platform::MacosClipboardManager < Scribe::Platform::ClipboardManager
  def read_clipboard_contents : String
    # NSPasteboard FFI calls (same pattern as crystal-audio ext/)
  end
end
```

### Process Manager Pattern

All non-RESTful business logic lives in process managers following FSDD grammar:

```crystal
class Scribe::Recording::StopAudioCaptureAndSave
  property saved_recording : Recording? = nil
  property was_save_successful : Bool = false

  def initialize(
    @currently_active_recorder : Platform::AudioRecorder,
    @output_directory_for_audio : String
  )
  end

  def perform
    stop_the_active_recording
    save_audio_file_to_output_directory
    create_recording_database_entry
  end

  # ... private methods
end
```

### Controller Convention

Controllers delegate to process managers for non-CRUD operations:

```crystal
class RecordingController < ApplicationController
  def start
    process = Scribe::Recording::StartAudioCapture.new(
      audio_recorder: Platform.create_audio_recorder,
      microphone_device_id: params[:device_id]?
    )
    process.perform

    if process.is_recording_active
      render_json({status: "recording", recording_id: process.active_recording_id})
    else
      render_json({status: "error", message: process.error_message}, status: 422)
    end
  end
end
```

## Expression Patterns

### State Transitions
- Recording: `idle` → `recording` → `saving` → `saved`
- Transcription: `pending` → `transcribing` → `completed` → `failed`
- Processing Job: `queued` → `running` → `streaming` → `completed` → `failed`

### Error Handling
- All process managers expose `was_process_successful` and `error_message_if_failed`
- Platform abstractions raise `Scribe::Platform::UnsupportedOperationError` for unavailable features
- Claude Code CLI errors captured via JSON stream error events
