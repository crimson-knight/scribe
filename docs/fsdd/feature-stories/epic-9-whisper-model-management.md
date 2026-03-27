# Epic 9: Whisper Model Management

Automatic whisper model discovery, download, selection, and integrity verification. Ensures users have a working whisper model on first launch and can switch between model sizes.

---

## Story 9.1: Model Discovery

**As a System,** I want to discover the whisper model at startup by checking configured paths and common locations, and report model status via the event bus
  **views:** no visible UI change; model status reported internally via events

**Initiator:** System (application startup, after InitializeApplication)
**Action Verb:** perform
**Data Model / Process:** `Scribe::ProcessManagers::DiscoverWhisperModel`
**View Outcome:** Model path resolved and emitted via `MODEL_FOUND` event, or `MODEL_MISSING` event emitted if not found

**Process Manager:**
```
ProcessManager := Scribe::ProcessManagers::DiscoverWhisperModel
  INITIALIZE(
    model_name : String = "ggml-base.en.bin"
  )

  PERFORM:
    check_configured_path_from_settings
    check_app_bundle_resources
    check_app_support_models_directory
    check_homebrew_whisper_model_paths
    emit_model_status_event
  END

  RESULTS:
    model_path : String? = nil
    model_found : Bool = false
    search_locations : Array(String) = [] of String
  END
END
```

**Search Locations (in order):**
1. Configured path from `whisper_model_path` setting (if not "auto")
2. App bundle: `Contents/Resources/<model_name>`
3. App Support: `~/Library/Application Support/Scribe/models/<model_name>`
4. Homebrew whisper-cpp models: `/opt/homebrew/share/whisper-cpp/models/<model_name>`

**Events:**
- `MODEL_FOUND` — emitted with `path` and `model_name` in EventData
- `MODEL_MISSING` — emitted with `model_name` and `searched_locations` in EventData

**Acceptance Criteria:**
- `DiscoverWhisperModel` PM searches all four locations in order
- Returns the first valid path found (file exists and is non-empty)
- Emits `MODEL_FOUND` event with the resolved path when found
- Emits `MODEL_MISSING` event when no model file found at any location
- Integrates with existing `WhisperBridge.find_whisper_model` (replaces its logic)
- Setting `whisper_model_path` to an explicit path bypasses auto-discovery
- `make macos` compiles successfully

---

## Story 9.2: Model Download on First Run

**As a User,** I want the whisper model to be automatically downloaded from Hugging Face if it is not found locally, with download progress shown in the menu bar
  **views:** menu bar status shows download progress (percentage + downloaded/total size)

**Initiator:** System (triggered by `MODEL_MISSING` event)
**Action Verb:** perform
**Data Model / Process:** `Scribe::ProcessManagers::DownloadWhisperModel`
**View Outcome:** Model file downloaded to `~/Library/Application Support/Scribe/models/`, progress shown via indicator

**Process Manager:**
```
ProcessManager := Scribe::ProcessManagers::DownloadWhisperModel
  INITIALIZE(
    model_name : String = "ggml-base.en.bin",
    destination_dir : String = "~/Library/Application Support/Scribe/models/"
  )

  PERFORM:
    resolve_download_url_for_model
    ensure_destination_directory_exists
    initiate_nsurl_session_download_with_progress
    emit_progress_events_during_download
    emit_completion_event
  END

  RESULTS:
    downloaded_path : String? = nil
    success : Bool = false
    error_message : String? = nil
    bytes_downloaded : Int64 = 0
    total_bytes : Int64 = 0
  END
END
```

**Download URLs:**
- `ggml-base.en.bin`: `https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin`
- Other models follow the same pattern with different filenames

**ObjC Bridge Addition (Section 12 of scribe_platform_bridge.m):**
- `scribe_download_file(url, dest_path, progress_callback, completion_callback)` — uses `NSURLSession downloadTaskWithURL:` with delegate
- Progress callback: `(int64_t bytesWritten, int64_t totalBytes) -> void`
- Completion callback: `(int32_t success, const char* error_message) -> void`

**Events:**
- `MODEL_DOWNLOAD_STARTED` — emitted with `model_name` and `url`
- `MODEL_DOWNLOAD_PROGRESS` — emitted with `bytes_downloaded` and `total_bytes`
- `MODEL_DOWNLOAD_COMPLETE` — emitted with `path` and `model_name`
- `MODEL_DOWNLOAD_FAILED` — emitted with `error_message`

**Acceptance Criteria:**
- Downloads model file from Hugging Face URL using NSURLSession (ObjC bridge)
- Shows download progress in the recording indicator panel (percentage + MB downloaded/total)
- Saves to `~/Library/Application Support/Scribe/models/<model_name>`
- Emits progress events during download for UI updates
- Handles network errors gracefully (emits `MODEL_DOWNLOAD_FAILED`)
- ObjC bridge section added to `scribe_platform_bridge.m` with proper NSURLSession delegate
- FFI bindings added to `LibScribePlatform` lib block in `app.cr`
- Download PM is standalone (usable from model management, not just first-launch)
- `make macos` compiles successfully after ObjC bridge recompilation

---

## Story 9.3: Model Selection UI

**As a User,** I want to see the current whisper model name and size in the menu bar dropdown, and have a setting for switching models
  **views:** menu item "Whisper Model: base.en (142 MB)" shown in status bar menu

**Initiator:** User (views menu) / System (setting changes)
**Action Verb:** perform
**Data Model / Process:** Settings integration + menu update
**View Outcome:** Menu shows current model info; `whisper_model_name` setting persisted

**Model Info:**
```crystal
MODEL_INFO = {
  "ggml-base.en.bin"   => {display: "base.en",   size_mb: 142},
  "ggml-small.en.bin"  => {display: "small.en",  size_mb: 466},
  "ggml-medium.en.bin" => {display: "medium.en", size_mb: 1500},
  "ggml-large.bin"     => {display: "large",     size_mb: 2900},
}
```

**Settings Addition:**
- `whisper_model_name` — default: `"ggml-base.en.bin"` (added to DEFAULTS in settings_manager.cr)

**Menu Integration:**
- Add menu item below "Output: ..." showing model info
- Format: `"Whisper Model: base.en (142 MB)"`
- Store menu item pointer for dynamic updates when model changes

**Acceptance Criteria:**
- `whisper_model_name` setting added to `DEFAULTS` in settings_manager.cr
- `MODEL_INFO` hash defined with display names and sizes for all four model variants
- Menu item shows current model name and size in the status bar dropdown
- Menu item updates when `SETTINGS_CHANGED` event fires for `whisper_model_name`
- Convenience method `Manager.whisper_model_name` added to settings_manager.cr
- `make macos` compiles successfully

---

## Story 9.4: Model Integrity Check

**As a System,** I want to verify the integrity of downloaded whisper models using SHA256 checksums, and trigger re-download if a model is corrupted
  **views:** no visible UI change unless re-download is triggered (shows download progress)

**Initiator:** System (after model discovery or download)
**Action Verb:** perform
**Data Model / Process:** `Scribe::ProcessManagers::VerifyModelIntegrity`
**View Outcome:** Model verified as intact, or `MODEL_CORRUPTED` event triggers re-download

**Process Manager:**
```
ProcessManager := Scribe::ProcessManagers::VerifyModelIntegrity
  INITIALIZE(
    model_path : String,
    model_name : String = "ggml-base.en.bin"
  )

  PERFORM:
    compute_sha256_of_model_file
    lookup_expected_hash_for_model
    compare_hashes
    emit_verification_result_event
  END

  RESULTS:
    verified : Bool = false
    computed_hash : String = ""
    expected_hash : String = ""
    error_message : String? = nil
  END
END
```

**Known SHA256 Hashes:**
```crystal
MODEL_HASHES = {
  "ggml-base.en.bin"   => "a03779c86df3323075f5e796cb2ce1100c4b2e3b",
  "ggml-small.en.bin"  => "20e06c25eb3f85a2d82b43919f4afb115dce58fe",
  "ggml-medium.en.bin" => "43448e6793a2af5c9b0e57b049d5c8e7bde4d70a",
  "ggml-large.bin"     => "64d182b440b98d1cfaca1c19d59ace36becf02d1",
}
```

Note: These are the official whisper.cpp model hashes from the Hugging Face repository. They are SHA1 hashes used by git-lfs. For our purposes, we compute SHA256 at runtime and store the first verified hash as the known-good hash in the database. On subsequent runs, we compare against the stored hash.

**Events:**
- `MODEL_VERIFIED` — emitted with `path`, `hash`, and `model_name`
- `MODEL_CORRUPTED` — emitted with `path`, `expected_hash`, `computed_hash`

**Acceptance Criteria:**
- Computes SHA256 hash of the model file using Crystal's `Digest::SHA256`
- Reads file in chunks (not all at once) to handle large model files (up to 2.9 GB)
- On first verification, stores the computed hash in the `application_settings` table
- On subsequent verifications, compares against stored hash
- Emits `MODEL_VERIFIED` event on success
- Emits `MODEL_CORRUPTED` event on hash mismatch (triggers re-download via event bus)
- Handles missing files gracefully (emits `MODEL_CORRUPTED`)
- `make macos` compiles successfully
