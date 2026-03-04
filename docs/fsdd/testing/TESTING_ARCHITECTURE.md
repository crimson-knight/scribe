# Scribe Testing Architecture

Reference implementation of FSDD 3-layer test architecture for a native cross-platform
application with Crystal backend, macOS desktop (AppKit menu bar), iOS (SwiftUI),
and Android (Compose) frontends.

---

## Overview

Scribe's test suite is organized into three layers with increasing scope and
infrastructure requirements. Each layer targets a different surface of the
application, from pure logic through platform UI to full end-to-end builds.

| Layer | What it tests | Runtime requirements | Typical speed |
|-------|--------------|----------------------|---------------|
| L1 | Crystal state machine + contracts | `crystal-alpha` only | < 100 ms |
| L2 | Platform UI elements and navigation | Simulator / emulator | 30-120 s |
| L3 | Full build-install-permission-test flow | Booted device / simulator | 2-10 min |

A CI orchestrator (`mobile/run_all_tests.sh`) ties the layers together and
reports PASS / FAIL / SKIP per layer.

---

## Layer 1 -- Crystal Specs

### Mobile Bridge State Machine

**File:** `mobile/shared/spec/scribe_bridge_spec.cr`
**Run command:**
```bash
cd mobile/shared && crystal-alpha spec spec/scribe_bridge_spec.cr -Dmacos
```

25 tests across 6 describe blocks (1 top-level, 5 nested):

| Describe block | Tests | Validates |
|---------------|-------|-----------|
| initialization | 3 | `scribe_init` return codes, idempotency |
| recording state machine | 8 | start/stop guards, double-start rejection, full lifecycle |
| playback state machine | 5 | start/stop, replacement playback, graceful no-op stop |
| recording and playback independence | 3 | concurrent recording + playback, independent stop |
| return code contracts | 6 | every public function returns only 0, 1, or -1 |

### macOS Process Manager Specs

**File:** `spec/macos/process_manager_spec.cr`
**Run command:**
```bash
cd ~/personal_coding_projects/scribe && crystal-alpha spec spec/macos/process_manager_spec.cr
```

Tests the desktop-specific process managers and app state machine without
hardware dependencies (microphone, whisper model, clipboard, AppKit). Uses the
same Option B replication approach as the mobile bridge spec.

| Describe block | Tests | FSDD Stories | Validates |
|---------------|-------|--------------|-----------|
| StartAudioCapture Process Manager | 8 | 2.2, 2.3 | perform/stop lifecycle, output path generation, error handling, re-record cycle |
| TranscribeAndPaste Process Manager | 6 | 3.1, 4.1 | transcript success/failure, empty/blank handling, audio file validation |
| App Toggle Recording State Machine | 7 | 1.1, 1.4, 1.5 | toggle start/stop, status icon/title updates, full cycle |
| App Configuration | 4 | 1.1 | output dir env var, default path, whisper model search paths |
| Clipboard Paste Cycle Contracts | 2 | 4.1 | success/failure callback semantics |
| WAV File Parsing Contracts | 7 | 2.2 | header validation, sample conversion, stereo downmix, resampling ratio |
| Transcript File Format | 2 | 4.2 | markdown frontmatter structure, filename convention |

### Why replication instead of linking

Both spec files contain standalone replicas of the state machines rather
than requiring the actual source files directly. This avoids `fun main` symbol
conflicts, hardware dependencies, and C extension linking.

See [Bridge Spec Replication Decision](bridge-spec-replication-decision.md) for
the full analysis.

---

## Layer 2 -- Platform UI Tests

### macOS (AppleScript Accessibility)

**File:** `test/macos/test_macos_ui.sh`
**Tests:** 8
**Prerequisites:** Scribe running, Accessibility permission for Terminal

| Test ID | Story | Asserts |
|---------|-------|---------|
| `1.1-no-dock-icon` | 1.1 | Scribe uses accessory activation policy (no Dock icon) |
| `1.1-process-exists` | 1.1 | Scribe process visible in System Events |
| `1.1-menu-bar-icon` | 1.1 | NSStatusItem exists in menu bar 2 |
| `1.4-menu-dropdown` | 1.4 | Clicking status item opens menu with items |
| `1.4-menu-items` | 1.4 | Menu contains "Recording" and "Quit" items |
| `1.4-idle-state` | 1.4 | Menu shows "Start Recording" in idle state |
| `1.1-binary-exists` | 1.1 | `bin/scribe` exists and is executable |
| `1.1-framework-links` | 1.1 | Binary links AppKit, AVFoundation, Carbon |

The macOS L2 tests use `osascript` (AppleScript) to query the accessibility
tree via System Events. This approach works for menu bar apps because
NSStatusItem menus are exposed through the standard accessibility API. Unlike
iOS XCUITest or Android Compose tests, these tests inspect a live running
application rather than launching a test harness.

Tests that require Accessibility permission will SKIP (not FAIL) if the
permission is not granted, allowing CI environments without GUI access to
still report useful results.

### iOS (XCUITest)

**File:** `mobile/ios/ScribeUITests/ScribeUITests.swift`
**Tests:** 7

| Test method | Story | Asserts |
|-------------|-------|---------|
| `testRecordButtonExists` | 7.1 | Record button exists by accessibility ID `7.1-record-button` |
| `testTimerInitialState` | 7.1 | Timer displays "0:00" on launch |
| `testStatusTextInitialState` | 7.1 | Status text exists and is non-empty |
| `testRecordingsTabShowsEmptyState` | 7.3 | Recordings tab navigates, nav bar appears |
| `testSettingsScreenLoads` | 7.5 | Settings tab navigates, nav bar appears |
| `testSaveLocationPickerExists` | 7.5 | Settings screen loads (picker rendering varies) |
| `testAllThreeTabsAccessible` | Nav | All 3 tabs tap-navigate and return to record |

### Android (Compose UI Test)

**File:** `mobile/android/app/src/androidTest/kotlin/com/crimsonknight/scribe/ScribeUITests.kt`
**Tests:** 9

| Test method | Story | Asserts |
|-------------|-------|---------|
| `recordButton_exists` | 7.2 | Record button displayed by testTag `7.2-record-button` |
| `timerDisplay_showsInitialState` | 7.2 | Timer element + "00:00" text displayed |
| `statusText_showsReadyState` | 7.2 | Status text + "Ready to record" displayed |
| `recordingsTab_navigates` | 7.4 | Tab click shows `7.4-empty-state` |
| `recordingsTab_showsEmptyState` | 7.4 | "No recordings yet" text displayed |
| `settingsTab_navigates` | 7.6 | Tab click shows "Save Location" text |
| `settingsScreen_showsSaveLocationOptions` | 7.6 | Local and Google Drive options displayed |
| `settingsScreen_showsAudioFormatOptions` | 7.7 | WAV and M4A options displayed |
| `allThreeTabs_accessible` | Nav | All 3 tabs navigate and return to record |

### Test ID convention

Test IDs follow the FSDD pattern `{epic}.{story}-{element-name}`:

- `7.1-record-button` -- iOS record button
- `7.2-timer-display` -- Android timer label
- `7.4-empty-state` -- Android empty recordings view
- `nav-tab-record`, `nav-tab-recordings`, `nav-tab-settings` -- shared tab IDs

These IDs originate in the Asset Pipeline `test_id` property on `UI::View`,
which maps to:

| Platform | Rendered as |
|----------|------------|
| Web | `data-testid` attribute |
| macOS (AppKit) | `setAccessibilityIdentifier:` |
| iOS (UIKit) | `setAccessibilityIdentifier:` |
| Android | `contentDescription` / Compose `testTag` |

---

## Layer 3 -- E2E Shell Scripts

End-to-end scripts automate the full build-install-test cycle. They are
designed for local development and CI runners with device access.

### macOS E2E

**File:** `test/macos/test_scribe_macos.sh`
**Steps:**

1. Build Scribe (`make macos`)
2. Launch app in background with test output directory
3. Wait for menu bar icon to appear (System Events check)
4. Run L2 UI tests (`test_macos_ui.sh`)
5. Verify startup logs (menu bar message, shortcut registration, whisper model)
6. Verify binary framework links
7. Terminate app and report results

**FSDD coverage:** Stories 1.1, 1.4, 1.5, 2.2 (state only), 2.3 (state only), 3.1 (model load)

**Hardware limitations:** Recording (2.2, 2.3), transcription (3.1), and clipboard
paste (4.1) require physical hardware (microphone) or Accessibility permission.
These are tested at L1 via state machine replication. The E2E script verifies
the infrastructure (binary links, log messages, output directory) that supports
these features.

### iOS E2E

**File:** `mobile/ios/test_scribe_ios.sh` (153 lines)
**Steps:**

1. Build Crystal bridge library (`build_crystal_lib.sh simulator`)
2. Generate Xcode project (`xcodegen generate`)
3. Build app for simulator (`xcodebuild build-for-testing`)
4. Boot iOS simulator (auto-detect UDID, prefer iPhone 16 Pro)
5. Grant microphone permission (`xcrun simctl privacy grant`)
6. Run XCUITests (`xcodebuild test-without-building -only-testing:ScribeUITests`)

**FSDD coverage:** Stories 7.1, 7.3, 7.5 + navigation

### Android E2E

**File:** `mobile/android/test_scribe_android.sh` (111 lines)
**Steps:**

1. Build Crystal library (`build_crystal_lib.sh`)
2. Build debug + test APKs (`gradlew assembleDebug assembleDebugAndroidTest`)
3. Detect running emulator or device (`adb devices`)
4. Install both APKs (`adb install -r`)
5. Grant RECORD_AUDIO permission (`adb shell pm grant`)
6. Run instrumented tests (`adb shell am instrument -w`)

**FSDD coverage:** Stories 7.2, 7.4, 7.6, 7.7 + navigation

---

## CI Orchestrator

**File:** `mobile/run_all_tests.sh`
**Run command:**
```bash
cd mobile && ./run_all_tests.sh          # L1 + L2 only
cd mobile && ./run_all_tests.sh --e2e    # L1 + L2 + L3
```

### Execution order

1. **L1:** Crystal specs (mobile bridge state machine) -- always runs
2. **L1a:** Crystal specs (macOS process managers) -- always runs
3. **L1b:** Asset Pipeline specs (`test_id` property) -- always runs
4. **L2 iOS:** XCUITest build -- runs if `xcodebuild` available, else SKIP
5. **L2 Android:** Compose test build -- runs if Android SDK found, else SKIP
6. **L2c macOS:** Accessibility UI test -- runs if Scribe is running, else SKIP
7. **L3 macOS:** Full macOS E2E -- only with `--e2e` flag
8. **L3 iOS:** Full iOS E2E -- only with `--e2e` flag
9. **L3 Android:** Full Android E2E -- only with `--e2e` flag

### Output

The orchestrator prints a summary with PASS / FAIL / SKIP counts and an
FSDD coverage map showing which stories are covered at which layers.

Exit code: 0 if all executed tests pass, 1 if any fail.

---

## File Inventory

```
spec/
└── macos/
    └── process_manager_spec.cr         # L1: macOS process manager tests (36 tests)

test/
└── macos/
    ├── test_macos_ui.sh                # L2: macOS accessibility UI tests (8 tests)
    └── test_scribe_macos.sh            # L3: macOS full E2E script

mobile/
├── run_all_tests.sh                    # CI orchestrator (all platforms)
├── shared/
│   ├── scribe_bridge.cr                # Bridge source (C API)
│   └── spec/
│       └── scribe_bridge_spec.cr       # L1: 25 bridge tests (6 describe blocks)
├── ios/
│   ├── ScribeUITests/
│   │   └── ScribeUITests.swift         # L2: 7 iOS UI tests
│   └── test_scribe_ios.sh              # L3: iOS E2E (153 lines)
└── android/
    ├── app/src/androidTest/kotlin/
    │   └── com/crimsonknight/scribe/
    │       └── ScribeUITests.kt        # L2: 9 Android UI tests
    └── test_scribe_android.sh          # L3: Android E2E (111 lines)
```

---

## How to Add Tests for a New Epic

Follow this sequence when implementing tests for a new feature epic:

### 1. Define acceptance criteria

Write the feature story document in `docs/fsdd/feature-stories/`. Each
acceptance criterion becomes a candidate for automated testing.

### 2. Create a test coverage table

Add a table to the feature story (or a separate testability doc) with columns
for L1, L2, and L3 coverage per story. See
[Partial Testability -- Epic 7](partial-testability-epic-7.md) for the format.

### 3. Write L1 Crystal specs first

L1 specs are the fastest feedback loop (< 100 ms, no hardware). Test state
machines, return codes, and business logic contracts.

If the new epic adds Crystal bridge functions, add tests to
`mobile/shared/spec/scribe_bridge_spec.cr` or create a new spec file in the
same directory.

### 4. Add test_id to Asset Pipeline views

Every testable UI element needs a `test_id` property value in the Asset
Pipeline view definition. Follow the `{epic}.{story}-{element-name}` convention.

### 5. Write L2 platform tests

Reference the test_id values from step 4:

- **macOS:** Use `osascript` with System Events accessibility queries, or `otool` for static binary checks
- **iOS:** Use `app.buttons["id"]`, `app.staticTexts["id"]`, etc. in XCUITest
- **Android:** Use `onNodeWithTag("id")` in Compose UI Test

### 6. Create L3 E2E shell scripts

Model new E2E scripts on the existing ones. The 6-step pattern
(build Crystal -> build app -> detect device -> install -> grant permissions -> run tests)
applies to most platform targets.

### 7. Update the CI orchestrator

If the new epic introduces a new test layer or platform target, add a
corresponding `run_layer` call in `mobile/run_all_tests.sh`.

### 8. Update feature story with coverage status

Mark each acceptance criterion as Covered / Partial / Pending in the feature
story's test coverage table.

---

## Known Inconsistencies

### Story 7.7 test ID asymmetry (iOS vs Android)

iOS uses a single test ID `7.7-format-picker` for audio format selection, while Android uses separate IDs for each option: `7.7-option-wav` and `7.7-option-m4a`. This means Android tests can assert on individual format options, but iOS cannot without querying inside the picker.

**Recommendation:** Align the iOS implementation to use individual option IDs (`7.7-option-wav`, `7.7-option-m4a`) to match Android. This enables per-option L2 assertions and follows the FSDD test ID convention more consistently (`{epic}.{story}-{element-name}` should identify a single testable element, not a container).

---

## Cross-References

- [Partial Testability -- Epic 7](partial-testability-epic-7.md) -- per-story testability analysis
- [Bridge Spec Replication Decision](bridge-spec-replication-decision.md) -- Option A vs B analysis
- [FSDD Methodology](../../../Documents/remote_sync_vault/Feature-Story-Driven-Development/) -- upstream methodology docs
- [Asset Pipeline cross-platform docs](../../../../open_source_coding_projects/asset_pipeline/) -- test_id property source
- [Epic 7 Feature Stories](../feature-stories/epic-7-mobile-recording.md) -- acceptance criteria source
