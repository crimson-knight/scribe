# Epic 11: Inbox System

Core messaging infrastructure for Scribe's evolution from dictation tool to AI agent orchestration platform. Threads are file-based (Markdown + YAML frontmatter) with SQLite as index/cache. Users create threads from dictation transcriptions, view conversation history, send follow-ups, and manage thread lifecycle.

---

## Story 11.1: Inbox Data Layer

**As a System,** I want Grant ORM models for inbox threads and messages, plus a file I/O service for reading and writing thread Markdown files so that conversation data is persisted both as human-readable files and as a queryable database index
  **views:** no visible UI change; data layer infrastructure for inbox threads and messages

**Initiator:** System (imported by process managers and views)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Models::InboxThread`, `Scribe::Models::InboxMessage`, `Scribe::Services::ThreadFileService`
**View Outcome:** No UI -- internal data layer used by inbox process managers and views

**Models:**

```crystal
# src/models/inbox_thread.cr
class Scribe::Models::InboxThread < Grant::Base
  connection primary
  table inbox_threads

  column id : Int64, primary: true
  column thread_uuid : String       # UUID for file naming
  column title : String
  column agent_id : String          # which agent handles this (default: "default")
  column current_status : String    # "active", "processing", "completed", "failed"
  column unread : Int32             # 0 or 1 (SQLite bool)
  column file_path : String         # path to .md thread file
  timestamps
end

# src/models/inbox_message.cr
class Scribe::Models::InboxMessage < Grant::Base
  connection primary
  table inbox_messages

  column id : Int64, primary: true
  column thread_id : Int64         # FK to inbox_threads
  column message_uuid : String     # UUID
  column role : String             # "user" or "assistant"
  column content : String
  column processing_job_id : Int64? # links to CLI execution
  timestamps
end
```

**Thread File Service:**

```
Module := Scribe::Services::ThreadFileService

  write_thread(thread : InboxThread, messages : Array(InboxMessage)):
    build_yaml_frontmatter_from_thread
    build_message_sections_from_messages
    write_combined_content_to_file_path
  END

  read_thread(file_path : String) : {thread_data, messages}:
    read_file_content
    split_frontmatter_from_body
    parse_yaml_frontmatter
    parse_message_sections_from_body
    return_parsed_data
  END

  append_message(file_path : String, message : InboxMessage):
    read_existing_file_content
    append_message_section
    update_frontmatter_updated_timestamp
    write_file
  END
END
```

**Thread File Format (Markdown + YAML frontmatter):**
```markdown
---
id: abc-123-def
title: "Review PR #42 feedback"
agent: default
status: completed
created: 2026-03-04T10:30:00Z
updated: 2026-03-04T10:31:45Z
---

## User -- 10:30 AM
Review the feedback on PR #42 and draft a response addressing each comment.

## Assistant -- 10:31 AM
I've reviewed the PR feedback. Here's a summary...

[response content]

---
Processing time: 45s | Files modified: 2
```

**Files:**
- `src/models/inbox_thread.cr` -- InboxThread Grant model
- `src/models/inbox_message.cr` -- InboxMessage Grant model
- `src/services/thread_file_service.cr` -- ThreadFileService module for Markdown file I/O
- `config/database.cr` -- add migrator calls for new models

**Acceptance Criteria:**
- `InboxThread` Grant model with all columns defined, migrator creates `inbox_threads` table
- `InboxMessage` Grant model with all columns defined, migrator creates `inbox_messages` table
- `ThreadFileService.write_thread` creates a `.md` file with YAML frontmatter and message sections
- `ThreadFileService.read_thread` parses a `.md` file and returns thread metadata and message content
- `ThreadFileService.append_message` adds a new message section to an existing thread file
- YAML frontmatter includes id, title, agent, status, created, updated fields
- Message sections use `## Role -- HH:MM AM/PM` format
- `make macos` compiles successfully

---

## Story 11.2: Create Thread from Dictation

**As a User,** I want to send my transcription to an AI agent instead of pasting to clipboard so that I can start an AI-assisted conversation from my dictation
  **views:** new "Send to Agent" menu item alongside existing record toggle; transcription routed to inbox thread creation

**Initiator:** User (clicks "Send to Agent" after transcription) OR System (if configured for auto-send)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Inbox::CreateThreadFromTranscription`
**View Outcome:** New InboxThread created in database and on disk; CLI adapter spawned; THREAD_CREATED event emitted

**Process Manager:**
```
ProcessManager := Scribe::Inbox::CreateThreadFromTranscription
  INITIALIZE(
    transcription_text : String,
    agent_id : String = "default",
    output_directory : String
  )

  PERFORM:
    generate_thread_uuid
    derive_title_from_transcription_first_line
    create_inbox_thread_record
    create_user_inbox_message_record
    resolve_inbox_storage_path
    write_thread_file_via_thread_file_service
    spawn_cli_adapter_for_processing
    emit_thread_created_event
  END

  RESULTS:
    thread : Scribe::Models::InboxThread? = nil
    message : Scribe::Models::InboxMessage? = nil
    processing_job : Scribe::Models::ProcessingJob? = nil
    was_successful : Bool = false
    error_message : String? = nil
  END
END
```

**Menu Integration:**
- New menu item "Send to Agent" added after "Start/Stop Recording" in menu bar dropdown
- Tag: `MENU_TAG_SEND_TO_AGENT = 2_u32`
- When clicked: takes last transcription text and creates a thread

**Event Constants (added to `src/events/events.cr`):**
```crystal
# Inbox events (Epic 11)
THREAD_CREATED        = "inbox.thread.created"
THREAD_UPDATED        = "inbox.thread.updated"
THREAD_RESPONSE_READY = "inbox.thread.response_ready"
```

**Files:**
- `src/process_managers/inbox/create_thread_from_transcription.cr`
- `src/platform/macos/menu_manager.cr` -- add "Send to Agent" menu item
- `src/platform/macos/app.cr` -- handle MENU_TAG_SEND_TO_AGENT callback
- `src/events/events.cr` -- add inbox event constants

**Acceptance Criteria:**
- `CreateThreadFromTranscription` PM creates InboxThread + InboxMessage records in database
- Thread `.md` file written to inbox storage directory via ThreadFileService
- Title derived from first line of transcription (truncated to 80 chars)
- UUID generated for thread file naming
- `SpawnClaudeCodeCli` PM invoked with transcription as prompt
- `THREAD_CREATED` event emitted with thread UUID
- "Send to Agent" menu item appears in menu bar dropdown
- Menu callback routes to thread creation with last transcription text
- `make macos` compiles successfully

---

## Story 11.3: Inbox List View (macOS)

**As a User,** I want to see a list of my inbox threads so that I can review past conversations and check their status
  **views:** NSPanel window with scrollable list of threads showing title, status badge, timestamp, and unread indicator

**Initiator:** User (clicks "Inbox" menu item)
**Action Verb:** display
**Data Model / Process:** `Scribe::Models::InboxThread` (query from database)
**View Outcome:** NSPanel window opens with Asset Pipeline ListView showing all threads sorted by updated_at desc

**View:**
```
View := Scribe::UI::InboxListView
  build() -> UI::VStack:
    create_header_with_title
    query_inbox_threads_sorted_by_updated_at_desc
    for_each_thread:
      create_thread_row_with_title_status_timestamp
      add_unread_indicator_if_unread
      set_on_tap_to_open_thread_detail
    end
    wrap_in_scroll_view
  END
END
```

**Menu Integration:**
- New menu item "Inbox" added before separator in menu bar dropdown
- Tag: `MENU_TAG_INBOX = 3_u32`
- Opens an NSPanel window via existing `LibScribePlatform` window functions

**Files:**
- `src/ui/inbox_list_view.cr` -- InboxListView using Asset Pipeline components
- `src/platform/macos/menu_manager.cr` -- add "Inbox" menu item
- `src/platform/macos/app.cr` -- handle MENU_TAG_INBOX callback, open window

**Acceptance Criteria:**
- "Inbox" menu item appears in menu bar dropdown
- Clicking "Inbox" opens an NSPanel window
- Window shows scrollable list of InboxThread records from database
- Each row displays: title, status text, updated_at timestamp
- Unread threads show visual indicator (bold or marker)
- Threads sorted by `updated_at` descending (newest first)
- Empty state shows "No threads yet" message
- `make macos` compiles successfully

---

## Story 11.4: Thread Detail View

**As a User,** I want to view the full conversation in a thread so that I can read user messages and agent responses with status indicators
  **views:** scrollable conversation view with message bubbles, status indicator, and timestamp for each message

**Initiator:** User (clicks a thread row in InboxListView)
**Action Verb:** display
**Data Model / Process:** `Scribe::Models::InboxThread`, `Scribe::Models::InboxMessage`
**View Outcome:** Window content replaced with thread detail showing all messages and status

**View:**
```
View := Scribe::UI::InboxThreadView
  build(thread : InboxThread) -> UI::VStack:
    create_header_with_thread_title_and_back_button
    create_status_indicator(thread.current_status)
    query_messages_for_thread_ordered_by_created_at
    for_each_message:
      create_message_section_with_role_label
      create_message_content_label
      create_timestamp_label
    end
    wrap_in_scroll_view
  END
END
```

**Status Indicators:**
- `active` -- "Active" (neutral)
- `processing` -- "Processing..." (animated text)
- `completed` -- "Completed" (green)
- `failed` -- "Failed" (red)

**Files:**
- `src/ui/inbox_thread_view.cr` -- InboxThreadView using Asset Pipeline components

**Acceptance Criteria:**
- Thread detail view shows thread title in header
- Status indicator displays current thread status with appropriate color
- All messages displayed in chronological order
- User messages and assistant messages visually distinguished (different alignment or color)
- Each message shows role label ("User" or "Assistant") and timestamp
- Back button returns to inbox list view
- Message content displayed as multi-line text
- `make macos` compiles successfully

---

## Story 11.5: Send Follow-Up Message

**As a User,** I want to type or dictate a follow-up message in an existing thread so that I can continue the conversation with context from prior messages
  **views:** text input at bottom of thread detail view; new message appears in conversation after send

**Initiator:** User (types follow-up text and clicks Send, or uses dictation shortcut within thread)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Inbox::SendFollowUpMessage`
**View Outcome:** New message appended to thread file and database; CLI adapter spawned with full conversation context; thread status set to "processing"

**Process Manager:**
```
ProcessManager := Scribe::Inbox::SendFollowUpMessage
  INITIALIZE(
    thread : Scribe::Models::InboxThread,
    message_text : String,
    output_directory : String
  )

  PERFORM:
    create_user_inbox_message_record
    append_message_to_thread_file
    build_full_context_prompt_from_all_messages
    update_thread_status_to_processing
    spawn_cli_adapter_with_full_context
    emit_thread_updated_event
  END

  RESULTS:
    message : Scribe::Models::InboxMessage? = nil
    processing_job : Scribe::Models::ProcessingJob? = nil
    was_successful : Bool = false
    error_message : String? = nil
  END
END
```

**Context Construction:**
- All prior messages in the thread are included in the CLI prompt
- Format: `User: [message]\nAssistant: [response]\nUser: [new message]`
- CLI adapter receives the full conversation, not just the latest message

**Files:**
- `src/process_managers/inbox/send_follow_up_message.cr`

**Acceptance Criteria:**
- New InboxMessage record created with `role: "user"` and link to thread
- Message appended to thread `.md` file via ThreadFileService
- Full conversation context built from all prior messages in the thread
- `SpawnClaudeCodeCli` PM invoked with full context prompt
- Thread `current_status` updated to `"processing"`
- `THREAD_UPDATED` event emitted
- `make macos` compiles successfully

---

## Story 11.6: Thread Status Updates

**As a User,** I want thread status to update in real-time as the AI agent processes my message so that I can see when processing starts, completes, or fails
  **views:** thread status badge updates automatically; assistant response appears when ready

**Initiator:** System (CLI processing events trigger status updates)
**Action Verb:** perform
**Data Model / Process:** EventBus handlers for CLI_COMPLETED/CLI_FAILED events scoped to inbox threads
**View Outcome:** InboxThread status updated in database; assistant message created from CLI result; THREAD_RESPONSE_READY emitted

**Event Wiring:**
```
EventBus.on(CLI_COMPLETED):
  find_thread_linked_to_processing_job
  IF thread found:
    create_assistant_inbox_message_from_result
    append_assistant_message_to_thread_file
    update_thread_status_to_completed
    mark_thread_as_unread
    emit_thread_response_ready
  END
END

EventBus.on(CLI_FAILED):
  find_thread_linked_to_processing_job
  IF thread found:
    update_thread_status_to_failed
    emit_thread_updated
  END
END
```

**Files:**
- `src/platform/macos/app.cr` -- install inbox event handlers alongside existing model/CLI handlers

**Acceptance Criteria:**
- `CLI_COMPLETED` event triggers assistant message creation in the linked thread
- Assistant message content taken from CLI result text
- Thread `.md` file updated with assistant response via ThreadFileService
- Thread `current_status` set to `"completed"` on success
- Thread `current_status` set to `"failed"` on failure
- Thread marked as `unread = 1` when response arrives
- `THREAD_RESPONSE_READY` event emitted with thread UUID
- Processing job ID linked in the assistant InboxMessage record
- `make macos` compiles successfully

---

## Story 11.7: Inbox Storage Directory

**As a User,** I want my inbox threads stored as Markdown files in a configurable directory so that I can browse, search, and back them up with standard file tools
  **views:** no visible UI change; inbox directory created at launch; setting available for customization

**Initiator:** System (application startup, after InitializeApplication)
**Action Verb:** perform
**Data Model / Process:** Settings Manager + InitializeApplication PM extension
**View Outcome:** Inbox storage directory created; `inbox_storage_path` setting registered

**Storage Paths:**
- Default (local): `~/Library/Application Support/Scribe/inbox/`
- iCloud (future, Epic 12): `~/Library/Mobile Documents/com~apple~CloudDocs/Scribe/inbox/`
- Archive subdirectory: `{inbox_storage_path}/archive/`

**Settings Integration:**
```crystal
# Added to DEFAULTS in config/settings_manager.cr
"inbox_storage_path" => "~/Library/Application Support/Scribe/inbox"
```

**Files:**
- `config/settings_manager.cr` -- add `inbox_storage_path` default + convenience method
- `src/process_managers/initialize_application.cr` -- create inbox directory on startup

**Acceptance Criteria:**
- `inbox_storage_path` added to Settings Manager DEFAULTS
- Convenience method `Manager.inbox_storage_path` returns resolved path (~ expanded)
- InitializeApplication PM creates inbox directory if it does not exist
- Archive subdirectory created alongside inbox directory
- Thread files stored as `{uuid}.md` in the inbox directory
- `make macos` compiles successfully

---

## Story 11.8: Delete / Archive Threads

**As a User,** I want to archive or delete old threads so that I can keep my inbox clean while preserving important conversations
  **views:** archive moves thread file to archive subdirectory; delete removes thread file and database records

**Initiator:** User (context action on thread in inbox list)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Inbox::ArchiveThread`, `Scribe::Inbox::DeleteThread`
**View Outcome:** Thread moved or removed; inbox list refreshed

**Process Managers:**
```
ProcessManager := Scribe::Inbox::ArchiveThread
  INITIALIZE(
    thread : Scribe::Models::InboxThread
  )

  PERFORM:
    resolve_archive_directory_path
    move_thread_file_to_archive_directory
    update_thread_status_to_archived
    emit_thread_updated_event
  END

  RESULTS:
    was_successful : Bool = false
    archive_path : String? = nil
    error_message : String? = nil
  END
END

ProcessManager := Scribe::Inbox::DeleteThread
  INITIALIZE(
    thread : Scribe::Models::InboxThread
  )

  PERFORM:
    delete_thread_file_from_disk
    delete_inbox_messages_for_thread
    delete_inbox_thread_record
    emit_thread_updated_event
  END

  RESULTS:
    was_successful : Bool = false
    error_message : String? = nil
  END
END
```

**Files:**
- `src/process_managers/inbox/archive_thread.cr`
- `src/process_managers/inbox/delete_thread.cr`

**Acceptance Criteria:**
- ArchiveThread moves the thread `.md` file to `{inbox_storage_path}/archive/`
- ArchiveThread updates thread `current_status` to `"archived"` in database
- ArchiveThread emits `THREAD_UPDATED` event
- DeleteThread removes the `.md` file from disk
- DeleteThread deletes all InboxMessage records for the thread from database
- DeleteThread deletes the InboxThread record from database
- DeleteThread emits `THREAD_UPDATED` event
- Archive directory created if it does not exist
- Graceful error handling if file not found (already deleted/moved)
- `make macos` compiles successfully
