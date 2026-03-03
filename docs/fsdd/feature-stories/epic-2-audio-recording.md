# Epic 2: Audio Recording

Core audio capture functionality — microphone access, recording lifecycle, and file management.

---

## Story 2.1: Request Microphone Permission

**As a User,** I want Scribe to request microphone access the first time I try to record
→ **views:** the native OS permission dialog asking for microphone access; after granting, a confirmation notification that Scribe is ready to record

**Initiator:** User (first recording attempt)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Recording::RequestMicrophonePermission`
**View Outcome:** Native OS permission dialog; on grant: status changes to "Ready"; on deny: settings prompt explaining microphone is required

**Acceptance Criteria:**
- Permission requested via platform-native dialog (not custom UI)
- macOS: NSMicrophoneUsageDescription in Info.plist
- iOS: NSMicrophoneUsageDescription in Info.plist
- Android: RECORD_AUDIO permission in manifest, runtime permission request
- If denied, show clear instructions for enabling in System Settings
- Permission state is checked before every recording attempt

---

## Story 2.2: Start Audio Recording

**As a User,** I want to start recording audio when I trigger the global shortcut or tap the record button
→ **views:** the status indicator changes to recording state (red/pulsing), a timer begins counting the recording duration, and a subtle waveform visualization appears

**Initiator:** User (shortcut or button press)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Recording::StartAudioCapture`
**View Outcome:** StatusIndicatorComponent turns red with pulse animation; duration timer starts; WaveformComponent shows live audio levels

**Process Manager:**
```
ProcessManager := Scribe::Recording::StartAudioCapture
  INITIALIZE(
    output_directory_for_audio : String,
    audio_format_preference : String = "wav",
    recording_source : CrystalAudio::RecordingSource = CrystalAudio::RecordingSource::Microphone
  )

  PERFORM:
    verify_microphone_permission_is_granted
    save_current_clipboard_contents
    generate_unique_filename_for_recording
    create_crystal_audio_recorder_instance
    start_recording_via_crystal_audio
    create_recording_database_entry
  END

  RESULTS:
    is_recording_active : Bool = false
    active_recording_id : Int64? = nil
    crystal_audio_recorder : CrystalAudio::Recorder? = nil
    error_message_if_failed : String? = nil
  END
END
```

**Implementation Note:** Uses `CrystalAudio::Recorder` directly — no custom audio abstraction layer.
Audio format determined by file extension: `.wav` (lossless) or `.m4a` (compressed).

**Acceptance Criteria:**
- Recording starts within 200ms of trigger
- Audio captured at 44.1kHz, 16-bit (configurable)
- Clipboard contents saved before recording begins (for later clipboard cycle)
- Recording model created in database with status "recording"
- Waveform shows real-time audio levels
- Duration timer updates every second

---

## Story 2.3: Stop Recording and Save Audio File

**As a User,** I want to stop the current recording by pressing the shortcut again or tapping the stop button
→ **views:** the status indicator changes to "saving" briefly, then "transcribing" as the audio file is processed; the duration timer freezes at final duration

**Initiator:** User (shortcut or button press while recording)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Recording::StopAudioCaptureAndSave`
**View Outcome:** StatusIndicator transitions: recording(red) → saving(yellow) → transcribing(blue); timer shows final duration; waveform freezes

**Process Manager:**
```
ProcessManager := Scribe::Recording::StopAudioCaptureAndSave
  INITIALIZE(
    crystal_audio_recorder : CrystalAudio::Recorder,
    active_recording_id : Int64
  )

  PERFORM:
    stop_crystal_audio_recorder
    update_recording_with_file_path_and_duration
    trigger_transcription_if_auto_transcribe_enabled
  END

  RESULTS:
    saved_recording : Recording? = nil
    was_save_successful : Bool = false
    file_path_to_saved_audio : String? = nil
    duration_in_seconds : Float64 = 0.0
  END
END
```

**Implementation Note:** Calls `crystal_audio_recorder.stop` which finalizes the audio file automatically.

**Acceptance Criteria:**
- Recording stops cleanly (no audio artifacts at end)
- Audio file saved to temporary directory (moved to output directory after transcription)
- Recording model updated with file_path, duration, status="saved"
- If auto-transcribe is enabled (default), transcription begins automatically
- If auto-transcribe is disabled, status changes to "saved" and waits

---

## Story 2.4: Cancel Active Recording

**As a User,** I want to cancel a recording in progress without saving it (e.g., via Escape key or long-press)
→ **views:** the status indicator returns to idle (green); the recording timer disappears; a brief "Recording cancelled" notification appears

**Initiator:** User (Escape key or cancel action)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Recording::CancelActiveRecording`
**View Outcome:** StatusIndicator returns to idle(green); notification toast "Recording cancelled"; no file saved

**Acceptance Criteria:**
- Cancel triggered by Escape key (macOS) or dedicated cancel gesture
- Audio data is discarded (temporary file deleted)
- Recording model deleted or marked as "cancelled"
- Saved clipboard contents restored (since no paste will occur)
- No transcription triggered

---

## Story 2.5: Display Recording Duration Timer

**As a User,** I want to see how long I've been recording in real-time
→ **views:** a timer display showing MM:SS format next to the recording indicator, updating every second

**Initiator:** System (while recording is active)
**Action Verb:** GET (view update)
**Data Model / Process:** UI timer component
**View Outcome:** Timer label showing "00:00" incrementing every second during active recording

**Acceptance Criteria:**
- Timer starts at 00:00 when recording begins
- Updates every second (not faster — avoid excessive UI updates)
- Displays in MM:SS format (HH:MM:SS if over 1 hour)
- Freezes at final value when recording stops
- Disappears when returning to idle state
