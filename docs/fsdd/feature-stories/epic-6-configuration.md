# Epic 6: Configuration

Application settings, output directory management, keyboard shortcut customization, and template management.

---

## Story 6.1: Open Settings View

**As a User,** I want to access application settings from the menu bar dropdown (macOS), app navigation (iOS/Android)
→ **views:** a settings screen organized into sections: General, Recording, Output, AI Processing, Keyboard Shortcuts

**Initiator:** User (clicks Settings)
**Action Verb:** GET (view)
**Data Model / Process:** SettingsView rendering
**View Outcome:** Settings view with sections: General (launch at login, notifications), Recording (audio quality, format), Output (directory, mode, file naming), AI Processing (API keys, templates), Shortcuts (global shortcut configuration)

**Acceptance Criteria:**
- Settings organized into logical sections
- Each section collapsible/expandable on mobile
- Changes saved immediately (no explicit "Save" button needed)
- macOS: opens as a separate window (NSPanel)
- iOS/Android: pushes as a new navigation screen

---

## Story 6.2: Configure Output Directory

**As a User,** I want to choose where transcription files and AI outputs are saved on my filesystem
→ **views:** a directory picker (native file dialog on macOS, document picker on iOS) with the currently selected path displayed; a "Browse" button to change it

**Initiator:** User (Settings → Output → Output Directory)
**Action Verb:** PUT (update)
**Data Model / Process:** `OutputConfiguration.output_directory_path`
**View Outcome:** Current path displayed as text; "Browse" button opens native directory picker; selected path validated and saved

**Acceptance Criteria:**
- Native directory picker (NSOpenPanel on macOS, UIDocumentPickerViewController on iOS, SAF on Android)
- Selected directory validated for write permissions
- Path saved to OutputConfiguration
- Default: `~/Documents/Scribe/` (created on first launch if not configured)
- Invalid directory shows inline error message
- This is the directory Claude Code CLI will be scoped to

---

## Story 6.3: Configure Keyboard Shortcut (macOS)

**As a User,** I want to set my preferred keyboard shortcut for triggering recordings
→ **views:** a shortcut recorder field that captures the next key combination I press, showing the current shortcut and a "Record New Shortcut" button

**Initiator:** User (Settings → Shortcuts)
**Action Verb:** PUT (update)
**Data Model / Process:** `ApplicationSetting` (key: `global_shortcut_key_combination`)
**View Outcome:** Current shortcut displayed (e.g., "⌥⇧R"); "Record" button activates capture mode; next key combination captured and displayed; "Save" confirms

**Acceptance Criteria:**
- Shortcut recorder captures modifier + key combination
- Validates no conflict with system shortcuts
- Displays using standard macOS modifier symbols (⌘⌥⇧⌃)
- Default: Option+Shift+R
- Shortcut re-registered with system immediately on save
- Clear button to remove shortcut (recording only via UI button)

---

## Story 6.4: Configure Transcription API Key

**As a User,** I want to securely store my transcription API key (e.g., OpenAI API key) in the app settings
→ **views:** a masked text field showing "••••••••" for the saved key, with a "Show" toggle and "Update" button; a status indicator showing if the key is valid

**Initiator:** User (Settings → AI Processing → Transcription API Key)
**Action Verb:** PUT (update)
**Data Model / Process:** `ApplicationSetting` (key: `transcription_api_key`, stored encrypted)
**View Outcome:** Masked field with current key; "Show" toggles visibility; "Update" reveals editable field; "Test" button validates the key against the API

**Acceptance Criteria:**
- API key stored encrypted in the database (not plain text)
- Key masked by default, revealable via toggle
- "Test" button makes a minimal API call to validate the key
- Valid key shows green checkmark; invalid shows red X with error
- Key required before transcription can work (clear error if missing)

---

## Story 6.5: Configure Audio Recording Quality

**As a User,** I want to choose audio recording quality to balance file size and transcription accuracy
→ **views:** a dropdown/picker with quality presets: "Standard (recommended)", "High Quality", "Low (small files)"

**Initiator:** User (Settings → Recording → Quality)
**Action Verb:** PUT (update)
**Data Model / Process:** `ApplicationSetting` (key: `audio_recording_quality`)
**View Outcome:** Picker with presets showing quality name and approximate file size per minute

**Presets:**
| Preset | Sample Rate | Bit Rate | Size/min |
|--------|-------------|----------|----------|
| Standard (recommended) | 44.1kHz | 128kbps | ~1MB |
| High Quality | 48kHz | 256kbps | ~2MB |
| Low (small files) | 22.05kHz | 64kbps | ~0.5MB |

**Acceptance Criteria:**
- Default: Standard
- Changes apply to next recording (not current)
- File size estimate shown for reference
- Higher quality improves transcription accuracy but increases upload time

---

## Story 6.6: Manage Instruction Templates

**As a User,** I want to view, edit, and delete my instruction templates from Settings
→ **views:** a list of templates with name, first line preview, and default indicator; swipe-to-delete on mobile, delete button on macOS; tap/click to edit

**Initiator:** User (Settings → AI Processing → Instruction Templates)
**Action Verb:** GET/PUT/DELETE (CRUD)
**Data Model / Process:** `InstructionTemplate`
**View Outcome:** List of templates; each row shows name, preview, default badge; edit opens template editor (Story 5.4); delete with confirmation

**Acceptance Criteria:**
- Templates listed in alphabetical order
- Default template has a visible badge/indicator
- Edit opens the same form as creation (Story 5.4)
- Delete requires confirmation dialog
- Cannot delete the only remaining template if post-processing is enabled
- "Add Template" button at bottom of list

---

## Story 6.7: Configure Launch at Login (macOS)

**As a User,** I want Scribe to automatically start when I log in to my Mac
→ **views:** a toggle switch in General settings labeled "Launch at Login"

**Initiator:** User (Settings → General → Launch at Login)
**Action Verb:** PUT (update)
**Data Model / Process:** `ApplicationSetting` (key: `is_launch_at_login_enabled`) + LaunchAgent registration
**View Outcome:** Toggle switch; when enabled, Scribe launches automatically on next login

**Acceptance Criteria:**
- Toggle adds/removes Scribe from Login Items (SMAppService on macOS 13+, or LaunchAgent)
- Default: disabled
- Change takes effect on next login (not immediate)

---

## Story 6.8: Enable/Disable Auto-Transcribe

**As a User,** I want to control whether recordings are automatically transcribed or if I manually trigger transcription
→ **views:** a toggle switch in Recording settings labeled "Auto-transcribe after recording"

**Initiator:** User (Settings → Recording → Auto-transcribe)
**Action Verb:** PUT (update)
**Data Model / Process:** `ApplicationSetting` (key: `is_auto_transcribe_enabled`)
**View Outcome:** Toggle switch; when disabled, recordings are saved but not automatically transcribed

**Acceptance Criteria:**
- Default: enabled (auto-transcribe)
- When disabled, recording stops at "saved" status
- User can manually transcribe from the recording history
- Useful for saving bandwidth or when offline

---

## Story 6.9: Enable/Disable Auto-Post-Process

**As a User,** I want to control whether transcriptions are automatically sent to Claude for post-processing or if I manually trigger it
→ **views:** a toggle switch in AI Processing settings labeled "Auto-process with default template"

**Initiator:** User (Settings → AI Processing → Auto-process)
**Action Verb:** PUT (update)
**Data Model / Process:** `ApplicationSetting` (key: `is_auto_post_process_enabled`)
**View Outcome:** Toggle switch; when enabled, shows the default template name below; when disabled, post-processing is manual only

**Acceptance Criteria:**
- Default: disabled (manual post-processing)
- Requires a default instruction template to be set
- When enabled, shows which template will be used
- Can be toggled independently of auto-transcribe
