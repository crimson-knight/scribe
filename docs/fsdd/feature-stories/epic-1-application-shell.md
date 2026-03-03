# Epic 1: Application Shell

The native application lifecycle — how Scribe runs as a background app on each platform.

---

## Story 1.1: Launch as Menu Bar App (macOS)

**As a User,** I want to launch Scribe and have it appear as a menu bar icon (not in the Dock)
→ **views:** a small microphone icon in the macOS menu bar, with the Dock showing no Scribe entry

**Initiator:** User (launches application)
**Action Verb:** perform (non-RESTful — app lifecycle)
**Data Model / Process:** `Scribe::Application::LaunchAsMenuBarApp`
**View Outcome:** NSStatusItem icon visible in menu bar; no Dock icon; app is running in background

**Acceptance Criteria:**
- Application launches with `LSUIElement = true` (no Dock icon)
- NSStatusItem appears in the menu bar with a microphone icon
- Icon reflects idle state (default icon)
- Application remains running when all windows are closed
- Application starts on login if User has enabled that setting

---

## Story 1.2: Launch as Background Service (iOS)

**As a User,** I want Scribe to be available as a background audio app on iOS
→ **views:** the Scribe app icon on their home screen; when opened, a minimal control screen with a record button

**Initiator:** User (opens app)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Application::LaunchAsIosApp`
**View Outcome:** App displays main control view with record button; background audio capability registered

**Acceptance Criteria:**
- App registers for background audio mode in Info.plist
- Main view shows recording controls
- App can be backgrounded and still process audio
- Siri Shortcuts integration available for hands-free trigger

---

## Story 1.3: Launch as Foreground Service (Android)

**As a User,** I want Scribe to run as an Android foreground service with a persistent notification
→ **views:** a persistent notification in the notification shade showing Scribe status, and the app icon in the launcher

**Initiator:** User (opens app)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Application::LaunchAsAndroidService`
**View Outcome:** Foreground service notification visible; app running in background

**Acceptance Criteria:**
- Foreground service starts with persistent notification
- Notification shows current state (idle/recording)
- Quick Settings tile available for recording toggle
- Service survives app being swiped from recents

---

## Story 1.4: Open Menu Bar Dropdown (macOS)

**As a User,** I want to click the menu bar icon and see a dropdown menu with controls
→ **views:** a dropdown menu with options: Start Recording, Settings, Recent Transcriptions, Quit

**Initiator:** User (clicks NSStatusItem)
**Action Verb:** GET (view menu)
**Data Model / Process:** NSMenu rendering
**View Outcome:** Dropdown menu with: recording toggle, separator, recent transcriptions list (last 5), separator, Settings, Quit

**Acceptance Criteria:**
- Menu appears on click (not on hover)
- "Start Recording" label toggles to "Stop Recording" when active
- Recent transcriptions show truncated first line with timestamp
- Clicking a recent transcription copies it to clipboard
- Settings opens the settings view
- Quit terminates the application

---

## Story 1.5: Register Global Keyboard Shortcut (macOS)

**As a User,** I want to configure a global keyboard shortcut that triggers recording from any application
→ **views:** recording starts immediately regardless of which app has focus; the menu bar icon changes to indicate recording state

**Initiator:** User (presses configured shortcut)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Platform::MacosShortcutListener`
**View Outcome:** Menu bar icon changes to recording state (red dot or pulsing indicator); recording begins immediately

**Acceptance Criteria:**
- Default shortcut: Option+Shift+R (configurable)
- Shortcut works in all applications (global scope)
- Pressing shortcut while recording stops the recording
- Shortcut registration survives sleep/wake cycles
- Conflicting shortcuts display a warning in Settings

---

## Story 1.6: Display Cross-Platform Main View

**As a User,** I want to see a consistent main interface across all platforms showing my recording status and recent activity
→ **views:** a clean interface with: current status indicator (idle/recording/transcribing/processing), a large record button, and a list of recent Scribe sessions

**Initiator:** User (opens main view)
**Action Verb:** GET (view)
**Data Model / Process:** UI rendering via Asset Pipeline cross-platform components
**View Outcome:** VStack layout with: StatusIndicatorComponent at top, RecordButton centered, list of recent ScribeSessions below

**Acceptance Criteria:**
- Uses Asset Pipeline cross-platform UI (AppKitRenderer on macOS, UIKitRenderer on iOS, AndroidRenderer on Android)
- StatusIndicatorComponent shows current state with color coding (green=idle, red=recording, blue=transcribing, purple=processing)
- Record button is large and prominent
- Recent sessions list shows date, duration, first line of transcription
- Pull-to-refresh on mobile, manual refresh on macOS
