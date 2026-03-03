# Epic 3: Transcription

AI-powered speech-to-text conversion of recorded audio files.

---

## Story 3.1: Transcribe Recording via Whisper API

**As a User,** I want my recording to be automatically transcribed using an AI transcription service
→ **views:** the status indicator shows "transcribing" (blue) with a progress indicator; when complete, the transcription text appears in the preview area

**Initiator:** System (after recording is saved, if auto-transcribe enabled)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Transcription::TranscribeRecordingViaWhisperApi`
**View Outcome:** StatusIndicator shows transcribing(blue) with spinner; on completion: TranscriptionPreviewView shows the text; status returns to idle

**Process Manager:**
```
ProcessManager := Scribe::Transcription::TranscribeRecording
  INITIALIZE(
    recording_to_transcribe : Recording,
    transcription_pipeline_mode : CrystalAudio::Transcription::Pipeline::PipelineMode = PipelineMode::Dictation,
    anthropic_api_key : String = ENV["ANTHROPIC_API_KEY"]
  )

  PERFORM:
    validate_audio_file_exists
    create_crystal_audio_transcription_pipeline
    run_whisper_transcription_on_audio_file
    format_transcript_via_claude_api_pipeline
    save_transcription_to_database
    update_recording_transcription_status
  END

  RESULTS:
    completed_transcription : Transcription? = nil
    was_transcription_successful : Bool = false
    error_message_if_failed : String? = nil
  END
END
```

**Implementation Note:** Uses `CrystalAudio::Transcription::Pipeline` directly.
- Stage 1: whisper.cpp converts audio to timestamped segments (local, no API call)
- Stage 2: Claude API formats/cleans the transcript based on mode
- Modes: `Dictation` (haiku, fast), `Meeting` (opus, thorough), `Code` (haiku, syntax-aware)

**Acceptance Criteria:**
- Whisper runs locally via crystal-audio (no external transcription API needed)
- Claude API used for transcript cleanup/formatting (requires ANTHROPIC_API_KEY)
- Transcription saved as `Transcription` model linked to source `Recording`
- Recording model updated: `has_been_transcribed = true`
- Error handling: whisper failure, API error, empty transcription
- API key stored securely in application settings (not in code)

---

## Story 3.2: Transcribe Recording via On-Device Speech (Fallback)

**As a User,** I want transcription to work offline using on-device speech recognition when the API is unavailable
→ **views:** the status indicator shows "transcribing (offline)" in a slightly different shade; transcription completes without network access

**Initiator:** System (when API is unreachable or User has selected offline mode)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Transcription::TranscribeRecordingViaOnDeviceSpeech`
**View Outcome:** StatusIndicator shows transcribing with "(offline)" label; completion same as online transcription

**Acceptance Criteria:**
- Uses Apple Speech framework on macOS/iOS
- Uses Android SpeechRecognizer on Android
- Automatically falls back when API request fails
- Transcription model records `transcription_provider_name = "on_device"`
- Quality may be lower than API — no special handling needed, just document the provider

---

## Story 3.3: View Transcription Preview After Completion

**As a User,** I want to see the transcription text immediately after it completes
→ **views:** a text preview area below the status indicator showing the full transcription text, with a "Copy" button and an "Edit" option

**Initiator:** System (transcription completes)
**Action Verb:** GET (view)
**Data Model / Process:** TranscriptionPreviewView rendering
**View Outcome:** Scrollable text view with full transcription; "Copy to Clipboard" button; "Edit" button to modify before output; "Post-Process" button if instruction templates are configured

**Acceptance Criteria:**
- Preview appears automatically after transcription completes
- Text is selectable and scrollable
- Copy button performs a simple clipboard write (not a clipboard cycle)
- Edit allows inline text modification before proceeding
- Post-Process button visible only if at least one InstructionTemplate exists
- Preview dismisses after configured timeout or manual dismiss

---

## Story 3.4: Retry Failed Transcription

**As a User,** I want to retry a transcription that failed due to network or API errors
→ **views:** an error state with the error message and a "Retry" button; optionally a "Try Offline" button to use on-device transcription

**Initiator:** User (clicks retry)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Transcription::RetryFailedTranscription`
**View Outcome:** Error view clears; status returns to transcribing(blue); same flow as initial transcription

**Acceptance Criteria:**
- Retry reuses the same audio file (not re-recorded)
- Retry attempts the same provider first, then offers fallback
- Maximum 3 automatic retries with exponential backoff
- After max retries, shows persistent error with manual retry button
- "Try Offline" skips API and goes directly to on-device
