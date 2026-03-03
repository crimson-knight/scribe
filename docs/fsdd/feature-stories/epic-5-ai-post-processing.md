# Epic 5: AI Post-Processing

Claude Code CLI integration for intelligent transcription processing — the "executive assistant" capability.

---

## Story 5.1: Spawn Claude Code CLI with Instruction Template

**As a User,** I want my transcription to be processed by Claude Code using my configured instruction template
→ **views:** the status indicator shows "processing" (purple) with a streaming progress view showing what Claude is doing in real-time

**Initiator:** System (after transcription completes, if post-processing is configured) OR User (clicks "Post-Process" button)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Processing::SpawnClaudeCodeCliWithInstructions`
**View Outcome:** StatusIndicator shows processing(purple); ProcessingProgressView shows streaming output from Claude Code CLI

**Process Manager:**
```
ProcessManager := Scribe::Processing::SpawnClaudeCodeCliWithInstructions
  INITIALIZE(
    transcription_to_process : Transcription,
    instruction_template : InstructionTemplate,
    output_directory_path : String,
    claude_code_cli_path : String = "claude"
  )

  PERFORM:
    build_prompt_from_template_and_transcription
    construct_cli_command_with_arguments
    spawn_cli_process_with_json_streaming
    create_processing_job_record
    begin_reading_json_stream
  END

  RESULTS:
    spawned_process_id : Int64? = nil
    processing_job : ProcessingJob? = nil
    was_spawn_successful : Bool = false
    error_message_if_failed : String? = nil
  END
END
```

**CLI Command Structure:**
```bash
claude --output-format stream-json \
  --allowedTools "Write,Edit,Read,Glob,Grep" \
  --prompt "$(cat <<'EOF'
[instruction_template content with {{transcription}} replaced]

Working directory: [output_directory_path]
Transcription content:
---
[transcription text]
---
EOF
)"
```

**Acceptance Criteria:**
- Claude Code CLI spawned as a child process
- JSON streaming enabled (`--output-format stream-json`)
- Tools scoped to file operations within output directory
- Prompt constructed from instruction template with transcription substituted
- ProcessingJob created in database with status "running"
- Process monitored for unexpected termination

---

## Story 5.2: Stream JSON Progress from CLI Process

**As a User,** I want to see what Claude is doing in real-time as it processes my transcription
→ **views:** a streaming log view showing Claude's actions: "Reading file...", "Writing meeting_notes.md...", "Updating todo.md...", with a completion indicator

**Initiator:** System (while CLI process is running)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Processing::StreamJsonProgressFromCliProcess`
**View Outcome:** ProcessingProgressView shows real-time updates; each tool use displayed as an action item; completion shown with checkmark

**Process Manager:**
```
ProcessManager := Scribe::Processing::StreamJsonProgressFromCliProcess
  INITIALIZE(
    cli_process : Process,
    processing_job : ProcessingJob
  )

  PERFORM:
    read_stdout_line_by_line
    parse_each_line_as_json
    dispatch_event_by_type
    update_processing_job_status
  END

  RESULTS:
    list_of_streamed_events : Array(JSON::Any) = [] of JSON::Any
    final_result_content : String? = nil
    was_process_completed : Bool = false
    exit_code : Int32? = nil
  END
END
```

**JSON Stream Event Types:**
- `assistant` — Claude's text responses (show as status messages)
- `tool_use` — Tool invocations (show as "Writing file.md..." action items)
- `tool_result` — Tool results (update action item with result)
- `result` — Final result (mark processing as complete)
- `error` — Error events (show error state)

**Acceptance Criteria:**
- Each JSON line parsed and displayed within 100ms
- Tool use events show human-readable descriptions
- File write events show the filename being written
- Progress view scrolls to latest event
- Completion event triggers status change to idle
- Error events display clearly with option to retry

---

## Story 5.3: Complete Post-Processing and Update Status

**As a User,** I want to know when Claude has finished processing my transcription and what files were created/modified
→ **views:** the status indicator returns to idle (green); a summary notification shows "Processing complete: 3 files written"; the processing progress view shows a final summary

**Initiator:** System (CLI process exits)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Processing::CompletePostProcessingJob`
**View Outcome:** StatusIndicator returns to idle(green); notification "Processing complete: N files written"; progress view shows summary with file list

**Acceptance Criteria:**
- ProcessingJob updated with `completed_at` timestamp and `current_status = "completed"`
- Files created/modified by Claude listed in summary
- Total processing time displayed
- If process exited with error, status set to "failed" with error details
- User can view processing history from main view

---

## Story 5.4: Create Instruction Template

**As a User,** I want to create reusable instruction templates that tell Claude how to process my transcriptions
→ **views:** a template editor with a name field, instruction text area with placeholder hints, and a Save button

**Initiator:** User (Settings → Instruction Templates → New)
**Action Verb:** POST (create)
**Data Model / Process:** `InstructionTemplate`
**View Outcome:** Template editor form with: name field, instruction textarea with `{{transcription}}` placeholder hint, "Set as Default" checkbox, Save button

**Acceptance Criteria:**
- Template name is required and unique
- Instruction text must contain `{{transcription}}` placeholder
- "Set as Default" marks this template as the auto-processing template
- Setting a new default clears the previous default
- Templates saved to database immediately

**Example Templates:**
```
Name: "Meeting Notes"
Instructions: |
  You are an executive assistant. The following is a transcription of a meeting.
  Please organize it into structured meeting notes with:
  - Date and attendees (if mentioned)
  - Key discussion points
  - Action items with owners
  - Decisions made
  Save the notes as a markdown file in the current directory.

  {{transcription}}
```

```
Name: "Quick Note"
Instructions: |
  Save the following transcription as a note in the current directory.
  Use a descriptive filename based on the content.
  Clean up any filler words but preserve the meaning.

  {{transcription}}
```

```
Name: "Todo Update"
Instructions: |
  The following transcription contains tasks and to-do items I mentioned.
  Read my existing todo.md file (if it exists) and update it with any new items.
  Mark any items I mentioned as completed.

  {{transcription}}
```

---

## Story 5.5: Select Instruction Template Before Processing

**As a User,** I want to choose which instruction template to use before post-processing starts
→ **views:** a template picker sheet/popover showing available templates with their names and first line of instructions; the default template is pre-selected

**Initiator:** User (clicks "Post-Process" on transcription preview)
**Action Verb:** GET (view templates)
**Data Model / Process:** InstructionTemplate listing
**View Outcome:** Picker showing list of templates; default pre-selected; "Process" button to confirm; "Skip" to cancel

**Acceptance Criteria:**
- Template picker appears before processing starts
- Default template is pre-selected (if one exists)
- Each template shows name and truncated first line of instructions
- "Process" begins post-processing with selected template
- "Skip" returns to transcription preview without processing
- If only one template exists, it's auto-selected with a confirmation prompt

---

## Story 5.6: Cancel Active Post-Processing

**As a User,** I want to cancel a running post-processing job if it's taking too long or doing the wrong thing
→ **views:** the processing progress view shows a "Cancel" button; clicking it stops Claude and shows "Processing cancelled" with files created so far listed

**Initiator:** User (clicks Cancel during processing)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Processing::CancelActiveProcessingJob`
**View Outcome:** CLI process terminated; status returns to idle; notification "Processing cancelled"; partial results (files already written) remain

**Acceptance Criteria:**
- CLI process sent SIGTERM (graceful) then SIGKILL after 5 seconds
- ProcessingJob status updated to "cancelled"
- Files already written by Claude are preserved (not rolled back)
- User informed of what was completed before cancellation
- Can re-process with same or different template after cancellation
