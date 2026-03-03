# Epic 4: Output Management

How transcriptions are delivered to the User — clipboard paste, file save, and output routing.

---

## Story 4.1: Paste Transcription via Clipboard Cycle

**As a User,** I want the transcription to be automatically pasted into whatever text input I had focused before recording, with my original clipboard contents restored afterward
→ **views:** the transcription text appears in the previously focused text input; clipboard is silently restored to its previous contents; a brief notification confirms "Transcription pasted"

**Initiator:** System (after transcription completes, if clipboard paste mode is enabled)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Output::PasteTranscriptionViaClipboardCycle`
**View Outcome:** Text appears in the User's active text input; brief toast notification "Transcription pasted"; clipboard restored to pre-recording state

**Process Manager:**
```
ProcessManager := Scribe::Output::PasteTranscriptionViaClipboardCycle
  INITIALIZE(
    transcription_text_to_paste : String,
    previously_saved_clipboard_contents : String,
    clipboard_manager : Platform::ClipboardManager,
    delay_before_paste_in_milliseconds : Int32 = 50,
    delay_before_restore_in_milliseconds : Int32 = 200
  )

  PERFORM:
    write_transcription_to_clipboard
    simulate_paste_keystroke
    wait_for_paste_to_complete
    restore_original_clipboard_contents
  END

  RESULTS:
    was_paste_successful : Bool = false
    was_clipboard_restored : Bool = false
  END
END
```

**Acceptance Criteria:**
- Clipboard cycle completes without User noticing the swap
- Paste keystroke simulated via platform API (CGEvent on macOS, etc.)
- Original clipboard restored after a configurable delay (default 200ms)
- Works with plain text (rich text/images not needed for v1)
- If paste fails (no focused text input), transcription remains on clipboard with notification

---

## Story 4.2: Save Transcription to Output Directory

**As a User,** I want transcriptions to be automatically saved as text files in my configured output directory
→ **views:** a file appears in the output directory with a descriptive filename (e.g., `2026-03-03_14-30_transcription.md`); notification confirms "Saved to [directory name]"

**Initiator:** System (after transcription completes, if file save mode is enabled)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Output::SaveTranscriptionToOutputDirectory`
**View Outcome:** File created in output directory; notification toast with filename and directory

**Process Manager:**
```
ProcessManager := Scribe::Output::SaveTranscriptionToOutputDirectory
  INITIALIZE(
    transcription_to_save : Transcription,
    output_directory_path : String,
    file_naming_pattern : String = "%Y-%m-%d_%H-%M_transcription",
    output_file_format : String = "md"
  )

  PERFORM:
    validate_output_directory_exists
    generate_filename_from_pattern
    format_transcription_content_for_file
    write_file_to_output_directory
    update_transcription_with_file_path
  END

  RESULTS:
    saved_file_path : String? = nil
    was_save_successful : Bool = false
  END
END
```

**Acceptance Criteria:**
- File created with timestamp-based name (configurable pattern)
- Default format: Markdown (.md) with YAML frontmatter (date, duration, source)
- Output directory created if it doesn't exist
- Duplicate filenames handled with numeric suffix (_1, _2, etc.)
- File content includes transcription text and metadata header

---

## Story 4.3: Copy Transcription to Clipboard Only

**As a User,** I want to just copy the transcription to my clipboard without auto-pasting
→ **views:** a notification saying "Transcription copied to clipboard"; clipboard contains the transcription text

**Initiator:** User (selects "Copy" from transcription preview, or configured as default output mode)
**Action Verb:** perform
**Data Model / Process:** Simple clipboard write (no cycle)
**View Outcome:** Notification toast "Copied to clipboard"; clipboard contains transcription text

**Acceptance Criteria:**
- Clipboard set to transcription text (no paste simulation)
- No clipboard restoration (User explicitly chose copy)
- Notification confirms the action
- This is the simplest output mode — no file, no paste, just clipboard

---

## Story 4.4: Configure Output Mode

**As a User,** I want to choose how transcriptions are delivered: clipboard cycle (paste + restore), clipboard copy, file save, or a combination
→ **views:** the Settings view with an "Output" section showing checkboxes for each output mode, with at least one required

**Initiator:** User (opens Settings → Output)
**Action Verb:** PUT (update configuration)
**Data Model / Process:** `OutputConfiguration`
**View Outcome:** Settings view with toggles: "Auto-paste to active input" (default on), "Save to file" (default off), "Copy to clipboard only" (mutually exclusive with auto-paste)

**Acceptance Criteria:**
- At least one output mode must be enabled
- "Auto-paste" and "Copy only" are mutually exclusive
- "Save to file" can be combined with either paste mode
- Changes saved immediately to ApplicationSetting
- Default: auto-paste enabled, file save disabled

---

## Story 4.5: Route Output to Multiple Destinations

**As a User,** I want both paste AND file save to happen when I complete a transcription
→ **views:** transcription is pasted into active input AND saved to file; two notifications confirm both actions

**Initiator:** System (transcription completes with multiple output modes enabled)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Output::RouteTranscriptionToConfiguredDestinations`
**View Outcome:** Paste occurs; file saved; sequential notifications for each completed action

**Process Manager:**
```
ProcessManager := Scribe::Output::RouteTranscriptionToConfiguredDestinations
  INITIALIZE(
    completed_transcription : Transcription,
    output_configuration : OutputConfiguration,
    clipboard_manager : Platform::ClipboardManager,
    previously_saved_clipboard_contents : String
  )

  PERFORM:
    determine_active_output_destinations
    execute_clipboard_output_if_enabled
    execute_file_save_if_enabled
    trigger_post_processing_if_configured
  END

  RESULTS:
    list_of_completed_destinations : Array(String) = [] of String
    list_of_failed_destinations : Array(String) = [] of String
  END
END
```

**Acceptance Criteria:**
- All enabled output modes execute in sequence
- Clipboard operations happen first (time-sensitive due to paste)
- File save happens after clipboard operations
- Post-processing triggered last (longest running)
- Each destination reports success/failure independently
- Partial success is acceptable (paste works, file save fails → report both)
