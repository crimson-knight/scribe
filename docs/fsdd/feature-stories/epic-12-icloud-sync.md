# Epic 12: iCloud Sync

Transparent file-based synchronization of inbox threads and transcriptions across macOS devices via iCloud Drive. Thread Markdown files are the source of truth; SQLite is a local index rebuilt from files. FSEvents monitors the iCloud directory for changes from other devices.

---

## Story 12.1: iCloud Drive Directory Structure

**As a System,** I want to create and manage an iCloud Drive directory structure for Scribe so that thread files and transcriptions can sync across devices
  **views:** no visible UI change; directory structure created at launch if iCloud Drive is available

**Initiator:** System (application startup)
**Action Verb:** perform
**Data Model / Process:** `Scribe::ProcessManagers::SetupICloudDirectories`, `Scribe::Settings::Manager`
**View Outcome:** iCloud directories created; `icloud_sync_enabled` setting registered; inbox path updated if iCloud available

**iCloud Directory Structure:**
```
~/Library/Mobile Documents/com~apple~CloudDocs/Scribe/
  inbox/          -- thread .md files (synced across devices)
  transcriptions/ -- saved transcription .md files
  templates/      -- instruction template .md files
```

**Settings:**
```crystal
# Added to DEFAULTS in config/settings_manager.cr
"icloud_sync_enabled" => "auto"  # "true", "false", or "auto" (detect iCloud availability)
```

**Process Manager:**
```
ProcessManager := Scribe::ProcessManagers::SetupICloudDirectories
  PERFORM:
    resolve_icloud_base_path
    check_if_icloud_drive_available
    IF icloud_available AND sync_enabled:
      create_icloud_inbox_directory
      create_icloud_transcriptions_directory
      create_icloud_templates_directory
      update_inbox_storage_path_to_icloud
    END
  END

  RESULTS:
    icloud_available : Bool = false
    directories_created : Array(String) = []
    error_message : String? = nil
  END
END
```

**Files:**
- `src/process_managers/setup_icloud_directories.cr` -- SetupICloudDirectories PM
- `config/settings_manager.cr` -- add `icloud_sync_enabled`, `icloud_base_path`, `icloud_sync_enabled?` convenience methods
- `src/process_managers/initialize_application.cr` -- call SetupICloudDirectories after base init

**Acceptance Criteria:**
- `icloud_sync_enabled` setting added to DEFAULTS with `"auto"` default
- `icloud_base_path` convenience method returns `~/Library/Mobile Documents/com~apple~CloudDocs/Scribe/`
- `icloud_sync_enabled?` returns true when setting is "true" or when "auto" and iCloud directory parent exists
- SetupICloudDirectories PM creates `inbox/`, `transcriptions/`, `templates/` subdirectories under iCloud path
- When iCloud enabled, `inbox_storage_path` setting updated to point to iCloud inbox directory
- Graceful handling when iCloud Drive is not available (no error, stays local)
- `make macos` compiles successfully

---

## Story 12.2: FSEvents File Watcher (macOS)

**As a System,** I want to monitor the iCloud Scribe directory for file changes using macOS FSEvents so that the app detects files synced from other devices in real time
  **views:** no visible UI change; file change events emitted to EventBus

**Initiator:** System (started after iCloud setup on app launch)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Platform::MacOS::FileWatcher`, ObjC bridge FSEvents section
**View Outcome:** File change events emitted via EventBus when iCloud files are created, modified, or deleted

**ObjC Bridge (Section 13: FSEvents File Watching):**
```c
// C functions added to scribe_platform_bridge.m
void *scribe_fsevents_start(const char *path, fsevents_callback_fn callback);
void scribe_fsevents_stop(void *stream);

// Callback type
typedef void (*fsevents_callback_fn)(const char *path, uint32_t flags);
```

**Crystal Wrapper:**
```
Module := Scribe::Platform::MacOS::FileWatcher
  start(path : String):
    store_callback_reference
    call_scribe_fsevents_start_via_ffi
    store_stream_reference
  END

  stop():
    call_scribe_fsevents_stop_via_ffi
    clear_stream_reference
  END

  on_file_changed(path, flags):
    determine_change_type_from_flags
    emit_icloud_file_changed_event
  END
END
```

**Event Constants (added to `src/events/events.cr`):**
```crystal
# iCloud sync events (Epic 12)
ICLOUD_FILE_CHANGED = "icloud.file.changed"
SYNC_COMPLETE       = "sync.complete"
SYNC_CONFLICT       = "sync.conflict"
```

**Files:**
- `src/platform/macos/ext/scribe_platform_bridge.m` -- add Section 13: FSEvents
- `src/platform/macos/app.cr` -- add FSEvents FFI bindings to `LibScribePlatform`
- `src/platform/macos/file_watcher.cr` -- FileWatcher Crystal module
- `src/events/events.cr` -- add iCloud event constants

**Acceptance Criteria:**
- FSEvents section added to `scribe_platform_bridge.m` using `FSEventStreamCreate` with `kFSEventStreamCreateFlagFileEvents`
- `scribe_fsevents_start` creates and schedules an FSEventStream on the current run loop
- `scribe_fsevents_stop` invalidates and releases the FSEventStream
- Callback fires with file path and FSEvent flags for each file-level change
- `FileWatcher` Crystal module wraps the ObjC bridge functions
- `ICLOUD_FILE_CHANGED` event emitted when a file changes in the watched directory
- Event data includes file path and change type (created/modified/deleted)
- `make macos` compiles successfully

---

## Story 12.3: Write-Through to iCloud

**As a System,** I want thread file writes to go to the iCloud directory when sync is enabled so that new threads and messages appear on other devices automatically
  **views:** no visible UI change; thread files written to iCloud path instead of local path

**Initiator:** System (triggered during thread creation and message appending)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Services::ThreadFileService` (modified)
**View Outcome:** Thread .md files written to iCloud inbox directory; SQLite remains local-only

**Modified ThreadFileService:**
```
Module := Scribe::Services::ThreadFileService (modified)
  resolve_storage_path() -> String:
    IF icloud_sync_enabled:
      return icloud_inbox_path
    ELSE:
      return local_inbox_path
    END
  END
END
```

**Key Principle:** SQLite is local-only (rebuilt from files on each device). The .md files in iCloud are the canonical source of truth.

**Files:**
- `src/services/thread_file_service.cr` -- no changes needed (already uses `Settings::Manager.inbox_storage_path`)
- `src/process_managers/inbox/create_thread_from_transcription.cr` -- no changes needed (uses settings path)

**Acceptance Criteria:**
- When iCloud sync is enabled, `inbox_storage_path` points to iCloud directory (set by Story 12.1)
- Thread files created in iCloud inbox directory automatically sync to other devices
- SQLite database remains in local App Support directory (not synced)
- Existing ThreadFileService and inbox PMs work without modification (they use settings-based path)
- `make macos` compiles successfully

---

## Story 12.4: Re-index from File System

**As a System,** I want to scan the inbox directory and rebuild the SQLite index from thread files so that changes from other devices (via iCloud sync) are reflected in the local database
  **views:** no visible UI change; database updated to match file system state

**Initiator:** System (on startup and when FSEvents detects changes)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Sync::ReIndexThreadFiles`
**View Outcome:** SQLite inbox_threads and inbox_messages tables updated to match .md files on disk

**Process Manager:**
```
ProcessManager := Scribe::Sync::ReIndexThreadFiles
  INITIALIZE(
    inbox_path : String = Settings::Manager.inbox_storage_path
  )

  PERFORM:
    scan_inbox_directory_for_md_files
    FOR EACH md_file:
      parse_thread_file_via_thread_file_service
      check_if_thread_exists_in_database
      IF new_file:
        create_inbox_thread_record
        create_inbox_message_records
      ELSIF file_modified_since_last_index:
        update_inbox_thread_record
        sync_message_records
      END
    END
    check_for_deleted_files:
      find_db_records_with_no_matching_file
      remove_orphaned_records
    END
    emit_sync_complete_event
  END

  RESULTS:
    files_scanned : Int32 = 0
    threads_created : Int32 = 0
    threads_updated : Int32 = 0
    threads_removed : Int32 = 0
    error_message : String? = nil
  END
END
```

**Files:**
- `src/process_managers/sync/re_index_thread_files.cr` -- ReIndexThreadFiles PM

**Acceptance Criteria:**
- ReIndexThreadFiles PM scans inbox directory for all `.md` files
- New files (not in DB) create InboxThread + InboxMessage records
- Modified files (newer than DB record) update existing records
- Deleted files (in DB but not on disk) remove DB records
- Thread metadata parsed from YAML frontmatter
- Messages parsed from `## Role -- Timestamp` sections
- `SYNC_COMPLETE` event emitted with scan statistics
- Efficient: checks file modification time before full parse
- `make macos` compiles successfully

---

## Story 12.5: Conflict Resolution

**As a System,** I want to handle conflicts when the same thread is edited on multiple devices simultaneously so that no data is lost during iCloud sync
  **views:** no visible UI change; conflicting messages appended with timestamps; SYNC_CONFLICT event emitted

**Initiator:** System (during re-index when file contents diverge from DB state)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Sync::ReIndexThreadFiles` (conflict handling extension)
**View Outcome:** Both versions of conflicting data preserved; conflict event emitted for potential UI notification

**Conflict Resolution Strategy:**
```
CONFLICT DETECTION:
  During re-index, compare file message count vs DB message count
  IF file has messages not in DB:
    append_new_messages_to_db (messages from other device)
  IF DB has messages not in file:
    these are local messages not yet synced
    append_local_messages_to_file
  RESULT: file and DB converge with union of all messages

MERGE RULES:
  1. .md file always wins for thread metadata (title, status, etc.)
  2. Messages are identified by content + timestamp (no UUID in file format)
  3. New messages from either source are kept (append-only merge)
  4. Worst case: duplicate messages with different timestamps (acceptable)
  5. SYNC_CONFLICT event emitted for tracking
```

**Files:**
- `src/process_managers/sync/re_index_thread_files.cr` -- add conflict detection and merge logic

**Acceptance Criteria:**
- Conflict detected when file message count differs from DB message count
- Messages from file not in DB are added to DB
- Messages in DB not in file are appended to file (preserves local work)
- Thread metadata (title, status) always taken from file (file is truth)
- `SYNC_CONFLICT` event emitted with thread UUID and conflict details
- No data loss in any conflict scenario
- Duplicate messages acceptable (append-only, no destructive merge)
- `make macos` compiles successfully
