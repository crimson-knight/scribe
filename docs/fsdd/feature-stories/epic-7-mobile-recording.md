# Epic 7: Mobile Recording

Mobile companion apps for iOS and Android — record voice memos, manage recordings, and configure save locations (iCloud Drive / Google Drive / local). No transcription, no paste, no AI processing on mobile (Phase 1).

---

## Story 7.1: Record Voice Memo on iOS

**As a User,** I want to record voice memos on my iPhone using the Scribe iOS app
→ **views:** a prominent record button in the center of the screen; when tapped, the button animates to a stop icon, a timer shows elapsed time, and a waveform visualization displays audio levels

**Initiator:** User (tap record button)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Mobile::StartMobileRecording`
**View Outcome:** RecordButton transitions to StopButton with pulse animation; DurationTimer starts counting; WaveformView shows live audio levels

**Process Manager:**
```
ProcessManager := Scribe::Mobile::StartMobileRecording
  INITIALIZE(
    output_directory : String,
    audio_format : String = "wav"
  )

  PERFORM:
    verify_microphone_permission_is_granted
    generate_unique_filename_for_recording
    create_crystal_audio_recorder_instance
    start_recording_via_crystal_audio
  END

  RESULTS:
    is_recording_active : Bool = false
    recorder : CrystalAudio::Recorder? = nil
    file_path : String? = nil
    error_message : String? = nil
  END
END
```

**Implementation Notes:**
- Crystal backend compiled as static library, called via Swift bridging header
- Reuses `CrystalAudio::Recorder` — same engine as macOS
- SwiftUI host handles UI, Crystal handles audio capture
- Uses GCD for Crystal↔Swift thread safety (same pattern as macOS GAP-19)

**Acceptance Criteria:**
- Microphone permission requested on first launch via native iOS dialog
- Recording starts within 200ms of button tap
- Audio captured at 44.1kHz, 16-bit WAV (or M4A per Story 7.7)
- Timer displays MM:SS, updating every second
- Stop button tap stops recording and saves file to Documents directory
- Works on iOS 16+ (iPhone and iPad)

**Test Coverage:**

| Acceptance Criteria | Layer 1 (Crystal Spec) | Layer 2 (UI Test) | Layer 3 (E2E Shell) |
|---|---|---|---|
| Mic permission requested on first launch | N/A | testRecordButtonExists (7.1-record-button) | xcrun simctl privacy grant |
| Recording starts within 200ms | scribe_start_recording returns 0 | N/A (hardware-dependent) | tap + verify status |
| Timer displays MM:SS | N/A | testTimerInitialState (7.1-timer-display) | N/A |
| Status text shows ready state | N/A | testStatusTextInitialState (7.1-status-text) | N/A |
| Stop saves file to Documents | scribe_stop_recording returns 0 | N/A (hardware-dependent) | verify .wav exists |
| Works on iOS 16+ | N/A | Build target iOS 16 | build on sim |

---

## Story 7.2: Record Voice Memo on Android

**As a User,** I want to record voice memos on my Android phone using the Scribe Android app
→ **views:** a prominent record FAB (floating action button); when tapped, it animates to a stop icon, a timer shows elapsed time, and a waveform visualization displays audio levels

**Initiator:** User (tap record FAB)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Mobile::StartMobileRecording` (same process manager as iOS)
**View Outcome:** RecordFAB transitions to StopFAB with pulse animation; DurationTimer starts counting; WaveformView shows live audio levels

**Implementation Notes:**
- Crystal backend compiled as shared library (.so), loaded via JNI
- Kotlin Compose host handles UI, Crystal handles audio capture via JNI bridge
- Uses Android Handler for Crystal↔Kotlin thread safety (same pattern as GAP-19/GAP-24)

**Acceptance Criteria:**
- RECORD_AUDIO runtime permission requested on first launch
- Recording starts within 200ms of button tap
- Audio captured at 44.1kHz, 16-bit WAV (or M4A per Story 7.7)
- Timer displays MM:SS, updating every second
- Stop button tap stops recording and saves file to app's external files directory
- Works on Android 10+ (API 29+)

**Test Coverage:**

| Acceptance Criteria | Layer 1 (Crystal Spec) | Layer 2 (UI Test) | Layer 3 (E2E Shell) |
|---|---|---|---|
| RECORD_AUDIO permission requested | N/A | recordButton_exists (7.2-record-button) | adb shell pm grant |
| Recording starts within 200ms | scribe_start_recording returns 0 | N/A (hardware-dependent) | tap + verify status |
| Timer displays MM:SS | N/A | timerDisplay_showsInitialState (7.2-timer-display) | N/A |
| Status text shows ready state | N/A | statusText_showsReadyState (7.2-status-text) | N/A |
| Stop saves file | scribe_stop_recording returns 0 | N/A (hardware-dependent) | verify .wav exists |
| Works on Android 10+ (API 29+) | N/A | Build target API 29 | build APK |

---

## Story 7.3: Browse and Manage Saved Recordings (iOS)

**As a User,** I want to see a list of my saved recordings and play them back
→ **views:** a scrollable list of recordings showing filename, date, duration, and file size; tapping a recording plays it with a simple playback control bar

**Initiator:** User (navigate to recordings tab)
**Action Verb:** GET
**Data Model / Process:** `Scribe::Mobile::ListRecordings`
**View Outcome:** RecordingsList showing each recording with metadata; tapping plays audio via `CrystalAudio::Player`; swipe-to-delete removes the file

**Acceptance Criteria:**
- Recordings listed in reverse chronological order (newest first)
- Each row shows: filename, date recorded, duration (MM:SS), file size
- Tap to play with play/pause/scrub controls
- Swipe to delete with confirmation alert
- Pull to refresh scans for new files
- Empty state shows "No recordings yet" message

**Test Coverage:**

| Acceptance Criteria | Layer 1 (Crystal Spec) | Layer 2 (UI Test) | Layer 3 (E2E Shell) |
|---|---|---|---|
| Reverse chronological order | N/A | testRecordingsTabShowsEmptyState | N/A |
| Recordings list container | N/A | N/A (7.3-recordings-list set in UI) | N/A |
| Tap to play | scribe_start_playback returns 0 | N/A (7.3-play-button set in UI, needs recordings) | N/A |
| Individual recording row | N/A | N/A (7.3-recording-row-* dynamic ID, needs recordings) | N/A |
| Empty state message | N/A | testRecordingsTabShowsEmptyState (7.3-empty-state) | N/A |

---

## Story 7.4: Browse and Manage Saved Recordings (Android)

**As a User,** I want to see a list of my saved recordings and play them back on Android
→ **views:** a scrollable list of recordings with filename, date, duration, and file size; tapping a recording plays it with a simple playback control bar

**Initiator:** User (navigate to recordings tab)
**Action Verb:** GET
**Data Model / Process:** `Scribe::Mobile::ListRecordings` (same process manager as iOS)
**View Outcome:** RecordingsList (Compose LazyColumn) showing each recording with metadata; tapping plays audio; swipe-to-dismiss deletes

**Acceptance Criteria:**
- Same functional criteria as Story 7.3
- Material 3 design language
- Uses Compose LazyColumn for performance

**Test Coverage:**

| Acceptance Criteria | Layer 1 (Crystal Spec) | Layer 2 (UI Test) | Layer 3 (E2E Shell) |
|---|---|---|---|
| Same functional criteria as 7.3 | scribe_start_playback returns 0 | recordingsTab_showsEmptyState (7.4-empty-state) | N/A |
| Recordings list container | N/A | N/A (7.4-recordings-list set in UI) | N/A |
| Tap to play | N/A | N/A (7.4-play-button set in UI, needs recordings) | N/A |
| Individual recording row | N/A | N/A (7.4-recording-row-* dynamic ID, needs recordings) | N/A |
| Material 3 design language | N/A | visual (manual) | N/A |
| Compose LazyColumn for performance | N/A | recordingsTab_navigates (7.4-empty-state) | N/A |

---

## Story 7.5: Configure Save Location — iCloud Drive / Local (iOS)

**As a User,** I want to choose whether recordings are saved locally or synced to iCloud Drive
→ **views:** a settings screen with a toggle or picker to choose "Local Only" or "iCloud Drive"; when iCloud is selected, a folder path configuration option appears

**Initiator:** User (navigate to settings)
**Action Verb:** UPDATE
**Data Model / Process:** `Scribe::Mobile::UpdateSaveLocationPreference`
**View Outcome:** SettingsView with save location picker; confirmation message on change; existing recordings optionally migrated

**Implementation Notes:**
- Crystal writes recordings to local Documents directory always
- Swift moves file to iCloud ubiquity container: `FileManager.setUbiquitous(true, itemAt:, destinationURL:)`
- UserDefaults stores save location preference
- iCloud availability checked at runtime (fails gracefully if iCloud disabled)

**Acceptance Criteria:**
- Default: Local Only (no iCloud access required to use app)
- iCloud option only shown if user is signed into iCloud
- When switching to iCloud, ask if existing recordings should be migrated
- When switching to Local, recordings remain in iCloud (not deleted)
- iCloud sync errors shown as non-blocking notifications
- Folder in iCloud Drive: `Scribe/Recordings/`

**Test Coverage:**

| Acceptance Criteria | Layer 1 (Crystal Spec) | Layer 2 (UI Test) | Layer 3 (E2E Shell) |
|---|---|---|---|
| Default: Local Only | N/A | testSettingsScreenLoads | N/A |
| Save location picker exists | N/A | testSaveLocationPickerExists (7.5-save-location-picker) | N/A |

---

## Story 7.6: Configure Save Location — Google Drive / Local (Android)

**As a User,** I want to choose whether recordings are saved locally or uploaded to Google Drive
→ **views:** a settings screen with a toggle or picker to choose "Local Only" or "Google Drive"; when Google Drive is selected, a Google account sign-in flow appears if not already authenticated

**Initiator:** User (navigate to settings)
**Action Verb:** UPDATE
**Data Model / Process:** `Scribe::Mobile::UpdateSaveLocationPreference` (same process manager as iOS)
**View Outcome:** SettingsView with save location picker; Google account OAuth flow if needed; confirmation on change

**Implementation Notes:**
- Crystal writes recordings to `getExternalFilesDir` always
- Kotlin uploads to Google Drive via Drive API v3 SDK
- SharedPreferences stores save location preference
- OAuth 2.0 via Google Sign-In SDK for Drive access

**Acceptance Criteria:**
- Default: Local Only (no Google account required to use app)
- Google Drive option triggers Google Sign-In if not authenticated
- When switching to Google Drive, ask if existing recordings should be uploaded
- When switching to Local, recordings remain in Drive (not deleted)
- Upload errors shown as non-blocking notifications with retry
- Folder in Google Drive: `Scribe/Recordings/`

**Test Coverage:**

| Acceptance Criteria | Layer 1 (Crystal Spec) | Layer 2 (UI Test) | Layer 3 (E2E Shell) |
|---|---|---|---|
| Default: Local Only | N/A | settingsScreen_showsSaveLocationOptions (7.6-option-local) | N/A |
| Google Drive option | N/A | settingsScreen_showsSaveLocationOptions (7.6-option-google-drive) | N/A |

---

## Story 7.7: Audio Format Selection (Both Platforms)

**As a User,** I want to choose between WAV (lossless) and M4A (compressed) for my recordings
→ **views:** a format picker in settings showing "WAV (Lossless, larger files)" and "M4A (Compressed, smaller files)" with estimated file sizes

**Initiator:** User (navigate to settings)
**Action Verb:** UPDATE
**Data Model / Process:** `Scribe::Mobile::UpdateAudioFormatPreference`
**View Outcome:** SettingsView with format picker; size estimate per minute shown for each format

**Acceptance Criteria:**
- Default: WAV (matches macOS Scribe default)
- M4A uses AAC codec at 128kbps
- Format change applies to next recording (does not re-encode existing)
- Size estimates: WAV ~10MB/min, M4A ~1MB/min shown in picker
- Both formats supported on both iOS and Android

**Test Coverage:**

| Acceptance Criteria | Platform | Layer 1 (Crystal Spec) | Layer 2 (UI Test) | Layer 3 (E2E Shell) |
|---|---|---|---|---|
| WAV option | Android | N/A | settingsScreen_showsAudioFormatOptions (7.7-option-wav) | N/A |
| M4A option | Android | N/A | settingsScreen_showsAudioFormatOptions (7.7-option-m4a) | N/A |
| WAV option | iOS | N/A | Not implemented (7.7-format-picker set in UI) | N/A |
| M4A option | iOS | N/A | Not implemented (7.7-format-picker set in UI) | N/A |
| Size estimates shown | Both | N/A | visual (manual) | N/A |

**Note:** iOS and Android use different test ID structures for audio format selection. Android uses individual option IDs (`7.7-option-wav`, `7.7-option-m4a`), while iOS uses a single picker ID (`7.7-format-picker`). No iOS L2 tests exist for this story yet. The iOS implementation should be aligned to use individual option IDs to match Android and enable per-option assertions.
