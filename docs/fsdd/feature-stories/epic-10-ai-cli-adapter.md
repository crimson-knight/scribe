# Epic 10: AI CLI Adapter

Adapter layer for Claude Code CLI integration — spawning, streaming, completion, and cancellation of AI post-processing jobs. Implements the process managers specified in Epic 5 (Stories 5.1, 5.2, 5.3, 5.6).

---

## Story 10.1: CLI Adapter Protocol

**As a Developer,** I want an abstract CLI adapter protocol with a concrete Claude Code implementation so that the AI post-processing pipeline is decoupled from any specific CLI tool
  **views:** no visible UI change; internal adapter abstraction for CLI process management

**Initiator:** System (imported by process managers)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Adapters::CliAdapter` (abstract), `Scribe::Adapters::ClaudeCodeAdapter` (concrete)
**View Outcome:** No UI — internal infrastructure used by spawn/stream/cancel PMs

**Abstract Adapter Interface:**
```
CliAdapter := Scribe::Adapters::CliAdapter (abstract)
  abstract build_command(prompt : String, options : AdapterOptions) : Array(String)
  abstract parse_stream_line(line : String) : CliEvent
  abstract adapter_name : String
END
```

**CliEvent Struct:**
```crystal
module Scribe::Adapters
  enum CliEventType
    Assistant    # Claude's text response
    ToolUse      # Tool invocation (Write, Read, etc.)
    ToolResult   # Result from tool execution
    Result       # Final result — processing complete
    Error        # Error event
    Unknown      # Unparseable line
  end

  struct CliEvent
    getter type : CliEventType
    getter data : JSON::Any?
    getter raw_line : String
    getter tool_name : String?
    getter text_content : String?
    getter duration_ms : Int64?
  end
end
```

**AdapterOptions:**
```crystal
struct Scribe::Adapters::AdapterOptions
  getter allowed_tools : Array(String)
  getter output_format : String
  getter working_directory : String?
  getter max_turns : Int32?
end
```

**Claude Code Adapter:**
```
ClaudeCodeAdapter := Scribe::Adapters::ClaudeCodeAdapter < CliAdapter
  INITIALIZE(
    cli_path : String = "claude"
  )

  build_command(prompt, options):
    construct_array: [cli_path, "-p", prompt, "--output-format", "stream-json",
                      "--allowedTools", options.allowed_tools.join(",")]
  END

  parse_stream_line(line):
    parse_json_and_map_type_field_to_cli_event
  END

  adapter_name:
    "claude-code"
  END
END
```

**Files:**
- `src/adapters/cli_adapter.cr` -- abstract base class with CliEvent, CliEventType, AdapterOptions
- `src/adapters/claude_code_adapter.cr` -- Claude Code CLI implementation

**Acceptance Criteria:**
- Abstract `CliAdapter` defines interface for `build_command`, `parse_stream_line`, `adapter_name`
- `CliEvent` struct carries parsed event type, raw JSON data, extracted tool name and text content
- `CliEventType` enum covers all Claude Code stream-json event types
- `ClaudeCodeAdapter` builds correct `claude` CLI command array
- `ClaudeCodeAdapter.parse_stream_line` handles all 5 event types from Claude Code stream-json
- Graceful handling of unparseable lines (returns `CliEventType::Unknown`)
- `AdapterOptions` struct provides typed configuration (allowed tools, output format, working directory)
- `make macos` compiles successfully

---

## Story 10.2: Spawn Claude Code CLI with Instruction Template

**As a User,** I want my transcription to be processed by Claude Code using my configured instruction template
  **views:** the status indicator shows "processing" with streaming progress

**Initiator:** System (after transcription completes, if post-processing is configured) OR User (clicks "Post-Process")
**Action Verb:** perform
**Data Model / Process:** `Scribe::ProcessManagers::SpawnClaudeCodeCli`
**View Outcome:** ProcessingJob created; CLI process spawned with JSON streaming; EventBus emits CLI_SPAWNED

**Process Manager:**
```
ProcessManager := Scribe::ProcessManagers::SpawnClaudeCodeCli
  INITIALIZE(
    transcription_text : String,
    instruction_template : String,
    output_directory : String,
    adapter : Scribe::Adapters::CliAdapter = ClaudeCodeAdapter.new
  )

  PERFORM:
    validate_adapter_cli_exists
    build_prompt_from_template_and_transcription
    construct_cli_command_via_adapter
    spawn_cli_process_with_pipes
    create_processing_job_record
    emit_cli_spawned_event
  END

  RESULTS:
    process : Process? = nil
    processing_job : Scribe::Models::ProcessingJob? = nil
    was_spawn_successful : Bool = false
    error_message : String? = nil
  END
END
```

**Prompt Construction:**
```
[instruction_template content with {{transcription}} replaced]

Working directory: [output_directory]
Transcription content:
---
[transcription_text]
---
```

**Files:**
- `src/process_managers/spawn_claude_code_cli.cr`

**Acceptance Criteria:**
- Prompt built from instruction template with `{{transcription}}` placeholder replaced
- CLI command constructed via adapter's `build_command` method
- Process spawned with `Process.new` using `output: IO::Pipe` for stdout reading
- ProcessingJob created in database with `job_type: "ai_processing"`, `current_status: "running"`
- `CLI_SPAWNED` event emitted with job ID and process ID
- Graceful error if `claude` binary not found (error_message set, no crash)
- Working directory passed to adapter options for tool scoping
- `make macos` compiles successfully

---

## Story 10.3: Stream JSON Progress from CLI Process

**As a User,** I want to see what Claude is doing in real-time as it processes my transcription
  **views:** streaming log with tool actions and progress updates

**Initiator:** System (while CLI process is running, after Story 10.2 spawn)
**Action Verb:** perform
**Data Model / Process:** `Scribe::ProcessManagers::StreamJsonProgress`
**View Outcome:** EventBus emits CLI_PROGRESS, CLI_TOOL_USE, CLI_TOOL_RESULT for each parsed stream line

**Process Manager:**
```
ProcessManager := Scribe::ProcessManagers::StreamJsonProgress
  INITIALIZE(
    process : Process,
    processing_job : Scribe::Models::ProcessingJob,
    adapter : Scribe::Adapters::CliAdapter
  )

  PERFORM:
    read_stdout_line_by_line
    parse_each_line_via_adapter
    emit_typed_event_per_line
    accumulate_streamed_events
    detect_result_or_error_completion
  END

  RESULTS:
    streamed_events : Array(Scribe::Adapters::CliEvent) = []
    final_result_text : String? = nil
    was_completed : Bool = false
    exit_code : Int32? = nil
    error_message : String? = nil
  END
END
```

**Event Constants (added to `src/events/events.cr`):**
```crystal
CLI_SPAWNED     = "cli.spawned"
CLI_PROGRESS    = "cli.progress"      # assistant text events
CLI_TOOL_USE    = "cli.tool_use"      # tool invocation events
CLI_TOOL_RESULT = "cli.tool_result"   # tool result events
CLI_COMPLETED   = "cli.completed"     # successful completion
CLI_FAILED      = "cli.failed"        # error/failure
CLI_CANCELLED   = "cli.cancelled"     # user cancellation
```

**JSON Stream Event Mapping:**
| Claude Code `type` | EventBus Event | CliEventType |
|---|---|---|
| `assistant` | `CLI_PROGRESS` | `Assistant` |
| `tool_use` | `CLI_TOOL_USE` | `ToolUse` |
| `tool_result` | `CLI_TOOL_RESULT` | `ToolResult` |
| `result` | `CLI_COMPLETED` | `Result` |
| `error` | `CLI_FAILED` | `Error` |

**Files:**
- `src/process_managers/stream_json_progress.cr`
- `src/events/events.cr` (add new constants)

**Acceptance Criteria:**
- Reads stdout from spawned process line-by-line until EOF
- Each line parsed via adapter's `parse_stream_line` method
- Correct EventBus event emitted for each parsed event type
- `assistant` events emit `CLI_PROGRESS` with text content in EventData
- `tool_use` events emit `CLI_TOOL_USE` with tool name in EventData
- `tool_result` events emit `CLI_TOOL_RESULT` with result content in EventData
- `result` event captures final text and signals completion
- `error` event captures error message and signals failure
- All events accumulated in `streamed_events` array for history
- Process exit code captured after stdout closes
- Unparseable lines logged but do not crash the stream reader
- `make macos` compiles successfully

---

## Story 10.4: Complete Post-Processing Job

**As a User,** I want to know when Claude has finished processing my transcription and what the outcome was
  **views:** status indicator returns to idle; completion notification shown

**Initiator:** System (CLI process exits, after Story 10.3 streaming completes)
**Action Verb:** perform
**Data Model / Process:** `Scribe::ProcessManagers::CompleteProcessingJob`
**View Outcome:** ProcessingJob updated in DB; EventBus emits CLI_COMPLETED or CLI_FAILED

**Process Manager:**
```
ProcessManager := Scribe::ProcessManagers::CompleteProcessingJob
  INITIALIZE(
    processing_job : Scribe::Models::ProcessingJob,
    exit_code : Int32,
    final_result_text : String? = nil,
    error_message : String? = nil
  )

  PERFORM:
    determine_outcome_from_exit_code
    update_processing_job_status
    record_completed_at_timestamp
    emit_completion_or_failure_event
  END

  RESULTS:
    final_status : String = "unknown"
    was_successful : Bool = false
    duration_seconds : Float64? = nil
  END
END
```

**Files:**
- `src/process_managers/complete_processing_job.cr`

**Acceptance Criteria:**
- Exit code 0 sets `current_status = "completed"`, non-zero sets `current_status = "failed"`
- `completed_at` timestamp recorded on ProcessingJob
- `error_message` stored on ProcessingJob if process failed
- `CLI_COMPLETED` event emitted on success with final result text and duration
- `CLI_FAILED` event emitted on failure with error message
- Duration calculated from `started_at` to `completed_at`
- ProcessingJob saved to database with updated fields
- `make macos` compiles successfully

---

## Story 10.5: Cancel Active Processing Job

**As a User,** I want to cancel a running post-processing job if it is taking too long or doing the wrong thing
  **views:** processing stops; status returns to idle; "Processing cancelled" shown; partial results preserved

**Initiator:** User (clicks Cancel during processing)
**Action Verb:** perform
**Data Model / Process:** `Scribe::ProcessManagers::CancelProcessingJob`
**View Outcome:** CLI process terminated; ProcessingJob status set to "cancelled"; EventBus emits CLI_CANCELLED

**Process Manager:**
```
ProcessManager := Scribe::ProcessManagers::CancelProcessingJob
  INITIALIZE(
    process : Process,
    processing_job : Scribe::Models::ProcessingJob
  )

  PERFORM:
    send_sigterm_to_process
    wait_up_to_five_seconds_for_exit
    send_sigkill_if_still_running
    update_processing_job_to_cancelled
    emit_cli_cancelled_event
  END

  RESULTS:
    was_cancelled : Bool = false
    required_sigkill : Bool = false
    error_message : String? = nil
  END
END
```

**Files:**
- `src/process_managers/cancel_processing_job.cr`

**Acceptance Criteria:**
- SIGTERM sent to CLI process first (graceful shutdown)
- If process still running after 5 seconds, SIGKILL sent
- ProcessingJob `current_status` updated to "cancelled"
- `completed_at` timestamp recorded
- `CLI_CANCELLED` event emitted with job ID and whether SIGKILL was required
- Files already written by Claude are preserved (no rollback)
- Partial output (events streamed before cancellation) remains in memory
- Cancelling an already-exited process does not error
- `make macos` compiles successfully
