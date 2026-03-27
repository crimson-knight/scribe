# Epic 13: Notifications + Scheduling

Notification delivery, unread badge tracking, work-hours scheduling, and a sequential processing queue for Scribe's AI agent pipeline. Ensures users are alerted when agent responses arrive, threads are processed one at a time in FIFO order, and instructions received outside configured work hours are queued until the next work window opens. Lays groundwork for iOS push notifications via iCloud completion markers.

---

## Story 13.1: macOS Notifications

**As a User,** I want to receive a macOS notification when an agent response is ready or when processing fails so that I am alerted even when Scribe is in the background
  **views:** no visible Scribe UI change; system notification appears in Notification Center

**Initiator:** EventBus (THREAD_RESPONSE_READY, CLI_FAILED)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Notifications::DeliverNotification`
**View Outcome:** macOS system notification with thread title + first line of response (or error message)

**ObjC Bridge (Section 13 of scribe_platform_bridge.m):**

```
UNUserNotificationCenter integration:

scribe_notifications_request_auth():
  get_UNUserNotificationCenter_current
  request_authorization_with_options(alert | sound | badge)
  log_result
END

scribe_notification_send(title, body, identifier):
  if_not_authorized_yet → request_auth_first
  create_UNMutableNotificationContent(title, body)
  set_sound_to_default
  create_UNNotificationRequest(identifier, content, nil_trigger)
  add_request_to_notification_center
  log_result
END
```

**FFI Bindings (added to LibScribePlatform):**

```crystal
fun scribe_notifications_request_auth : Void
fun scribe_notification_send(title : UInt8*, body : UInt8*, identifier : UInt8*) : Void
```

**Process Manager:**

```
PM := Scribe::Notifications::DeliverNotification

  INPUTS:
    title : String
    body : String
    identifier : String   # thread UUID or job ID

  PERFORM:
    call_LibScribePlatform_scribe_notification_send(title, body, identifier)
    log_notification_sent
  END
END
```

**Event Wiring (in App.install_notification_event_handlers):**

```
on THREAD_RESPONSE_READY:
  look_up_thread_by_uuid_from_event_data
  derive_title_from_thread
  derive_body_from_latest_assistant_message (first 100 chars)
  DeliverNotification.new(title, body, thread_uuid).perform
END

on CLI_FAILED:
  look_up_thread_by_uuid_from_event_data
  derive_title = "Processing Failed"
  derive_body = error_message or thread title
  DeliverNotification.new(title, body, thread_uuid).perform
END
```

**Build:** Add `-framework UserNotifications` to MACOS_FRAMEWORKS in Makefile.

**Acceptance:**
- Notification appears in macOS Notification Center when agent response is ready
- Notification appears when CLI processing fails
- Permission is requested on first notification attempt, not on every launch
- Notification includes thread title and truncated response body

---

## Story 13.2: Menu Bar Badge Count

**As a User,** I want the Scribe menu bar item to show how many unread threads I have so that I can tell at a glance whether there are responses waiting
  **views:** status item title changes from "Scribe" to "Scribe [3]" when 3 unread threads exist

**Initiator:** EventBus (THREAD_RESPONSE_READY, THREAD_READ)
**Action Verb:** update
**Data Model / Process:** `Scribe::Platform::MacOS::BadgeManager`
**View Outcome:** Status item title reflects unread count; resets when threads are read

**New Event Constant:**

```crystal
THREAD_READ = "inbox.thread.read"   # emitted when user views a thread
```

**Badge Manager Module:**

```
Module := Scribe::Platform::MacOS::BadgeManager

  update_badge(status_item : Void*):
    count = query_unread_count_from_db   # SELECT COUNT(*) FROM inbox_threads WHERE unread = 1
    if count > 0
      set_status_item_title("Scribe [#{count}]")
    else
      set_status_item_title("Scribe")
    end
  END

  mark_thread_read(thread_uuid : String):
    find_thread_by_uuid
    set_thread.unread = 0
    save_thread
    emit THREAD_READ event
  END
END
```

**Event Wiring:**

```
on THREAD_RESPONSE_READY:
  BadgeManager.update_badge(status_item)
END

on THREAD_READ:
  BadgeManager.update_badge(status_item)
END
```

**Acceptance:**
- Status item title shows "Scribe [N]" when N > 0 unread threads
- Title reverts to "Scribe" when all threads are read
- Badge updates when new response arrives (THREAD_RESPONSE_READY)
- Badge updates when thread is viewed (THREAD_READ)

---

## Story 13.3: Agent Work Hours (Scheduling)

**As a User,** I want to configure work hours so that agent instructions received outside those hours are queued until the next work window so that I maintain work-life boundaries
  **views:** no visible UI change; settings stored in DB

**Initiator:** System (settings configuration)
**Action Verb:** check
**Data Model / Process:** `Scribe::Services::ScheduleService`
**View Outcome:** No UI -- service used by processing queue to gate execution

**New Settings:**

```crystal
# Added to DEFAULTS in config/settings_manager.cr
"work_hours_enabled" => "false"
"work_hours_start"   => "09:00"
"work_hours_end"     => "18:00"
"work_hours_days"    => "1,2,3,4,5"   # ISO weekday: 1=Mon ... 7=Sun
```

**Schedule Service:**

```
Module := Scribe::Services::ScheduleService

  within_work_hours? : Bool:
    return true if get("work_hours_enabled") != "true"
    parse_start_time from settings
    parse_end_time from settings
    parse_allowed_days from settings
    now = Time.local
    check now.day_of_week is in allowed_days
    check now.hour:minute is between start and end
    return result
  END

  next_work_window_start : Time:
    calculate_next_time_that_falls_within_work_hours
    return that time
  END
END
```

**Convenience Methods on Settings Manager:**

```crystal
def self.work_hours_enabled? : Bool
def self.work_hours_start : String
def self.work_hours_end : String
def self.work_hours_days : String
```

**Acceptance:**
- `within_work_hours?` returns true when work hours are disabled (default)
- `within_work_hours?` returns true when current time is within configured range on allowed days
- `within_work_hours?` returns false outside configured hours or on non-allowed days
- Settings persist in DB via Settings Manager

---

## Story 13.4: Processing Queue

**As a System,** I want to queue multiple instructions and execute them sequentially so that only one CLI process runs at a time and results are delivered in order
  **views:** no visible UI change; threads show "pending" status until processed

**Initiator:** EventBus (THREAD_CREATED) + System startup
**Action Verb:** perform
**Data Model / Process:** `Scribe::Scheduling::ProcessInstructionQueue`
**View Outcome:** Threads transition from "pending" to "processing" to "completed"/"failed" sequentially

**New Event Constants:**

```crystal
QUEUE_ITEM_ADDED   = "queue.item.added"
QUEUE_PROCESSING   = "queue.processing"
QUEUE_IDLE         = "queue.idle"
```

**New Settings:**

```crystal
"max_concurrent_jobs" => "1"
```

**Process Manager:**

```
PM := Scribe::Scheduling::ProcessInstructionQueue

  CLASS STATE:
    @@queue : Array(Int64) = []   # thread IDs in FIFO order
    @@processing : Bool = false
    @@current_thread_id : Int64? = nil

  enqueue(thread_id : Int64):
    add thread_id to @@queue
    emit QUEUE_ITEM_ADDED
    process_next unless @@processing
  END

  process_next:
    return if @@processing
    return if @@queue.empty?
    check_work_hours → if outside, schedule_delayed_start and return

    @@processing = true
    thread_id = @@queue.shift
    @@current_thread_id = thread_id

    look_up_thread_from_db
    look_up_user_message_for_thread
    set thread.current_status = "processing"
    save thread

    spawn_cli_process_for_thread(thread, message)
    emit QUEUE_PROCESSING
  END

  on_completed(thread_id : Int64):
    @@processing = false
    @@current_thread_id = nil
    process_next   # dequeue and process next item
  END

  on_failed(thread_id : Int64):
    @@processing = false
    @@current_thread_id = nil
    process_next
  END

  queue_size : Int32:
    return @@queue.size
  END

  processing? : Bool:
    return @@processing
  END
END
```

**Event Wiring:**

```
on CLI_COMPLETED:
  ProcessInstructionQueue.on_completed(thread_id)
END

on CLI_FAILED:
  ProcessInstructionQueue.on_failed(thread_id)
END
```

**Integration with Story 13.3:**
- `process_next` calls `ScheduleService.within_work_hours?` before spawning CLI
- If outside work hours, item stays at front of queue and a GCD timer is set for next work window start

**Acceptance:**
- Instructions are processed one at a time (sequential, not concurrent)
- Queue processes in FIFO order
- New instructions enqueued while one is processing wait until completion
- On CLI_COMPLETED or CLI_FAILED, next item is automatically dequeued
- Queue respects work hours when enabled (Story 13.3)

---

## Story 13.5: Mobile Push Notification Readiness (Stub)

**As a System,** I want the macOS side to write a completion marker into thread file frontmatter so that the iOS companion app can detect completed threads and fire local notifications
  **views:** no visible change; frontmatter gains `completion_marker` field

**Initiator:** EventBus (THREAD_RESPONSE_READY)
**Action Verb:** update
**Data Model / Process:** `Scribe::Services::ThreadFileService` (extended)
**View Outcome:** Thread .md file frontmatter includes `completion_marker: <ISO timestamp>`

**Frontmatter Extension:**

```yaml
---
id: abc-123
title: "My Thread"
agent: default
status: completed
created: 2026-03-04T10:00:00Z
updated: 2026-03-04T10:05:00Z
completion_marker: 2026-03-04T10:05:00Z
---
```

**ThreadFileService Extension:**

```
write_completion_marker(file_path : String, timestamp : Time):
  read_file_content
  if frontmatter contains "completion_marker:" line
    replace with new timestamp
  else
    insert "completion_marker: <timestamp>" before closing "---"
  end
  write_file
END
```

**Event Wiring:**

```
on THREAD_RESPONSE_READY:
  look_up_thread_by_uuid
  ThreadFileService.write_completion_marker(thread.file_path, Time.utc)
END
```

**iOS Side (Deferred to Epic 14):**
- `NSMetadataQuery` watches iCloud inbox directory for file changes
- On detecting `completion_marker` in frontmatter, fires `UNUserNotificationCenter` local notification
- This story only prepares the macOS writer side

**Acceptance:**
- Thread file frontmatter includes `completion_marker` after agent response completes
- Marker value is ISO 8601 UTC timestamp
- Existing thread files without marker get it added (not overwritten)
- No iOS implementation in this story -- macOS write-side only
