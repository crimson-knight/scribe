# Epic 14: Mobile Inbox + Dictation

iOS companion app gains inbox access (reading iCloud-synced thread files) and dictation (creating new threads from voice input). The mobile inbox is read-only for existing threads — new threads are created via dictation and synced to macOS for processing. No Crystal dependency for inbox features; all inbox logic is pure SwiftUI reading iCloud Drive files directly.

---

## Story 14.1: iOS Inbox List View

**As a User,** I want to see my inbox threads on my iPhone so that I can review conversation status on the go
  **views:** a scrollable list of threads showing title, status badge, timestamp, and unread indicator; sorted by most recently updated; automatically refreshes when iCloud files change

**Initiator:** User (navigate to Inbox tab)
**Action Verb:** GET
**Data Model / Process:** `ICloudInboxService` (Swift), `ThreadMetadata` (Swift model)
**View Outcome:** InboxListView showing threads from iCloud `Scribe/inbox/` directory; each row displays title, status badge (active/processing/completed/failed), relative timestamp, and unread dot; empty state when no threads exist

**Service Layer:**
```
ICloudInboxService:
  - Discovers .md files in iCloud Scribe/inbox/ directory
  - Uses NSMetadataQuery to watch for iCloud file changes (new/modified/deleted)
  - Parses YAML frontmatter from each .md file for metadata
  - Published threads array drives SwiftUI list
  - Handles iCloud unavailable gracefully (shows message)
```

**Model:**
```swift
struct ThreadMetadata: Identifiable {
    let id: String          // thread_uuid from frontmatter
    let title: String       // title from frontmatter
    let agent: String       // agent from frontmatter
    let status: ThreadStatus // active, processing, completed, failed
    let created: Date       // created from frontmatter
    let updated: Date       // updated from frontmatter
    let hasCompletionMarker: Bool // completion_marker present
    let fileURL: URL        // iCloud file URL for navigation to detail
}
```

**Files:**
- `mobile/ios/Scribe/Models/ThreadMetadata.swift` -- ThreadMetadata struct + ThreadStatus enum
- `mobile/ios/Scribe/Models/ThreadMessage.swift` -- ThreadMessage struct for parsed message content
- `mobile/ios/Scribe/Services/ICloudInboxService.swift` -- file discovery + NSMetadataQuery watcher
- `mobile/ios/Scribe/Views/InboxListView.swift` -- SwiftUI list view

**Acceptance Criteria:**
- Inbox tab appears in tab bar with "tray.fill" icon
- Threads loaded from iCloud `Scribe/inbox/` directory
- Each row shows: title, status badge (color-coded), relative timestamp (e.g., "2m ago")
- Threads sorted by `updated` descending (most recent first)
- NSMetadataQuery detects new/modified/deleted files and updates list automatically
- Empty state shows "No threads yet" with instruction to use dictation
- Graceful handling when iCloud is unavailable (shows "iCloud Required" message)
- No Crystal dependency -- pure Swift/SwiftUI

**Test Coverage:**

| Acceptance Criteria | Layer 2 (UI Test) | Notes |
|---|---|---|
| Inbox tab exists | testInboxTabExists (14.1-inbox-tab) | Tab bar navigation |
| Empty state shown | testInboxEmptyState (14.1-inbox-empty) | When no iCloud files |
| Thread row displays | N/A | Requires iCloud files present |

---

## Story 14.2: iOS Thread Detail View

**As a User,** I want to read a conversation thread on my iPhone so that I can review the full exchange between user and assistant
  **views:** a conversation view similar to Messages.app with user messages right-aligned in blue bubbles and assistant messages left-aligned in gray bubbles; status indicator at top; scrolls to bottom on load

**Initiator:** User (tap thread in inbox list)
**Action Verb:** GET
**Data Model / Process:** `ThreadMessage` (Swift model), Markdown file parser
**View Outcome:** ThreadDetailView showing conversation bubbles; status bar at top with processing spinner, completed checkmark, or failed X; messages parsed from `## Role -- Time` sections in .md file

**Message Parser:**
```
Parse .md file content:
  1. Split on "---" to separate frontmatter from body
  2. Split body on "## " headers
  3. Each header: "## Role -- Time" -> extract role + timestamp
  4. Content between headers is the message body
  5. Role "User" -> right-aligned blue bubble
  6. Role "Assistant" -> left-aligned gray bubble
```

**Model:**
```swift
struct ThreadMessage: Identifiable {
    let id: UUID
    let role: MessageRole   // .user or .assistant
    let timestamp: String   // raw timestamp string from header
    let content: String     // message body text
}
```

**Files:**
- `mobile/ios/Scribe/Views/ThreadDetailView.swift` -- conversation bubble view
- `mobile/ios/Scribe/Models/ThreadMessage.swift` -- ThreadMessage struct (shared with 14.1)

**Acceptance Criteria:**
- Navigation from inbox list row to detail view via NavigationLink
- Thread title displayed in navigation bar
- User messages: right-aligned, blue background, white text
- Assistant messages: left-aligned, gray background, primary text color
- Status indicator at top: spinner for "processing"/"active", checkmark for "completed", X for "failed"
- Scroll position starts at bottom (most recent message visible)
- Handles threads with single message (user dictation, no response yet)
- Markdown in message body rendered as plain text (no rich rendering needed for v1)

**Test Coverage:**

| Acceptance Criteria | Layer 2 (UI Test) | Notes |
|---|---|---|
| Detail view navigates | N/A | Requires iCloud thread files |
| Status indicator shows | N/A | Requires iCloud thread files |

---

## Story 14.3: iOS Dictation to Thread Creation

**As a User,** I want to dictate a new thread from my iPhone so that I can start a conversation that macOS picks up and processes
  **views:** a dictation view with a large microphone button; shows live transcription text; creates a thread .md file in iCloud inbox when complete

**Initiator:** User (tap dictation button)
**Action Verb:** perform
**Data Model / Process:** `SpeechTranscriptionService` (Swift, SFSpeechRecognizer)
**View Outcome:** DictationView with mic button, live transcription text area, and send/cancel buttons; after send, thread appears in inbox list

**Service Layer:**
```
SpeechTranscriptionService:
  - Uses Apple Speech framework (SFSpeechRecognizer) -- NOT whisper-cli
  - On-device recognition preferred (SFSpeechRecognizer.supportsOnDeviceRecognition)
  - Streams live partial results to UI during recording
  - Returns final transcription text on completion
  - Requires NSSpeechRecognitionUsageDescription in Info.plist
```

**Thread File Creation:**
```
When user taps "Send":
  1. Generate UUID for thread
  2. Create .md file with YAML frontmatter:
     - id: <uuid>
     - title: first 50 chars of transcription
     - agent: default
     - status: active
     - created: ISO 8601 timestamp
     - updated: ISO 8601 timestamp
  3. Write "## User -- HH:MM AM/PM" section with transcription text
  4. Save to iCloud Scribe/inbox/<uuid>.md
  5. macOS FSEvents detects new file and begins processing
```

**Files:**
- `mobile/ios/Scribe/Services/SpeechTranscriptionService.swift` -- Apple Speech framework wrapper
- `mobile/ios/Scribe/Views/DictationView.swift` -- dictation UI with mic button and live text

**Acceptance Criteria:**
- Speech recognition permission requested on first use (NSSpeechRecognitionUsageDescription)
- Microphone permission already granted from Epic 7 (NSMicrophoneUsageDescription)
- Live partial transcription shown during dictation
- User can cancel dictation (discards text, no thread created)
- User can send transcription (creates thread .md file in iCloud inbox)
- Thread file uses correct YAML frontmatter format matching Epic 11 spec
- Created thread status is "active" (macOS changes to "processing" when picked up)
- New thread appears in inbox list after creation via NSMetadataQuery update
- Works offline if on-device recognition available (file syncs when connectivity restored)

**Test Coverage:**

| Acceptance Criteria | Layer 2 (UI Test) | Notes |
|---|---|---|
| Dictation button exists | testDictationButtonExists (14.3-dictation-button) | On DictationView |
| Cancel button exists | testDictationCancelExists (14.3-cancel-button) | During dictation |
| Send button exists | testDictationSendExists (14.3-send-button) | After transcription |

---

## Story 14.4: iOS Quick Dictation (Floating Action Button)

**As a User,** I want to quickly dictate a new thread from the inbox list without navigating away so that I can capture thoughts with minimal friction
  **views:** a floating action button (FAB) on the inbox list; one-tap starts recording, auto-stops after 3 seconds of silence, transcribes, and creates a thread -- all without leaving the inbox

**Initiator:** User (tap FAB on inbox list)
**Action Verb:** perform
**Data Model / Process:** `SpeechTranscriptionService` (reused from 14.3)
**View Outcome:** FAB on InboxListView; tapping shows recording overlay with waveform animation; auto-stops on silence; new thread appears at top of list

**Quick Dictation Flow:**
```
1. User taps FAB (mic icon) on inbox list
2. Recording overlay appears (no navigation)
3. Speech recognition starts with silence detection
4. After 3 seconds of silence OR user taps stop:
   a. Transcription finalized
   b. Thread .md file created in iCloud inbox (same format as 14.3)
   c. Overlay dismisses
   d. New thread appears at top of inbox list
5. If no speech detected after 10 seconds, auto-cancel with "No speech detected" toast
```

**Files:**
- `mobile/ios/Scribe/Views/InboxListView.swift` -- add FAB overlay (modifies 14.1 file)
- `mobile/ios/Scribe/Views/DictationView.swift` -- reuse components for overlay mode

**Acceptance Criteria:**
- FAB visible on inbox list (bottom-right, mic icon)
- One-tap starts recording with visual feedback (pulsing animation)
- Auto-stops after 3 seconds of continuous silence
- Thread created with same format as Story 14.3
- No navigation -- overlay on top of inbox list
- Cancel gesture (tap outside overlay or swipe down) discards recording
- Timeout after 10 seconds of no speech detected
- Haptic feedback on start and completion (UIImpactFeedbackGenerator)

**Test Coverage:**

| Acceptance Criteria | Layer 2 (UI Test) | Notes |
|---|---|---|
| FAB exists on inbox | testQuickDictationFABExists (14.4-quick-dictation-fab) | Floating button |
| FAB is tappable | N/A | Requires mic permission in test |

---

## Story 14.5: Android Inbox (Architecture Stub)

**As a Developer,** I want placeholder files for Android inbox so that the architecture is documented for future implementation
  **views:** none (stub only)

**Initiator:** Developer
**Action Verb:** N/A (documentation)
**Data Model / Process:** N/A
**View Outcome:** Stub Kotlin file with TODO comments documenting the architecture

**Architecture Notes:**
```
Android Inbox Challenges:
  - No iCloud on Android -- would need alternative sync:
    a. Google Drive API (requires OAuth, more complex)
    b. Shared server/API (requires backend)
    c. Local-only with manual export (simplest)
  - Thread file format (.md with YAML frontmatter) is portable
  - Speech recognition: Android SpeechRecognizer API (similar to iOS SFSpeechRecognizer)
  - File watching: FileObserver API (similar to FSEvents/NSMetadataQuery)
```

**Files:**
- `mobile/android/app/src/main/kotlin/com/crimsonknight/scribe/InboxStub.kt` -- stub with TODO

**Acceptance Criteria:**
- Stub file created with TODO comments
- Architecture documented in comments (sync options, API choices)
- No functional code -- purely documentation
- Does not affect Android build
