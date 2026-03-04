# Partial Testability Analysis — Epic 7: Mobile Recording

**FSDD Version:** 1.2.0
**Date:** 2026-03-04
**Status:** Active (Phase 5 — Documentation)

## Overview

Epic 7 (Mobile Recording) spans iOS and Android companion apps with Crystal audio backends. Due to the hardware-dependent nature of audio recording and platform-specific APIs, not all acceptance criteria can be fully automated in CI. This document categorizes each testable surface by what can run locally, what requires a device/simulator, and what requires manual verification.

---

## 1. Locally Testable (No Device Required)

These tests validate state, logic, and UI element existence without hardware interaction.

| What | How | Layer |
|---|---|---|
| Recording state machine (idle/recording/stopped) | Crystal spec: verify `scribe_start_recording` and `scribe_stop_recording` return codes | Layer 1 (Crystal Spec) |
| UI element existence (buttons, timer, status text) | XCUITest / Compose UI Test: assert elements by accessibility ID | Layer 2 (UI Test) |
| Tab navigation (Record / Recordings / Settings) | XCUITest / Compose UI Test: tap tabs, verify screen loads | Layer 2 (UI Test) |
| Empty state rendering (no recordings) | XCUITest / Compose UI Test: verify "No recordings yet" on fresh install | Layer 2 (UI Test) |
| Settings screen layout (save location, format options) | XCUITest / Compose UI Test: verify pickers and options exist | Layer 2 (UI Test) |
| Timer initial state (0:00 / 00:00) | XCUITest / Compose UI Test: read label text | Layer 2 (UI Test) |

---

## 2. Requires Device or Simulator

These tests depend on hardware capabilities (microphone, file system, audio playback) and must run on a real device or simulator/emulator.

| What | Why | Mitigation |
|---|---|---|
| Actual audio recording (microphone capture) | Requires mic hardware and OS audio subsystem | Run on simulator with `xcrun simctl privacy grant` (iOS) or `adb shell pm grant` (Android) |
| Recording file creation (.wav / .m4a) | Requires file system write in app sandbox | Verify post-recording via shell: `xcrun simctl get_app_container` (iOS) or `adb shell ls` (Android) |
| Audio playback | Requires audio output device | Manual or device-only test |
| Permission dialog flow | OS-level modal, not controllable via UI test frameworks | Grant permissions via CLI before test run |
| Recording latency (200ms requirement) | Timing depends on hardware and OS scheduling | Measure in device tests; not enforceable in UI tests |
| AAudio / AVFoundation backend behavior | Platform audio APIs only available on-device | Crystal specs test the bridge interface; actual audio is device-only |

---

## 3. Requires Manual Testing

These acceptance criteria cannot be automated and must be verified by a human tester.

| What | Why |
|---|---|
| Visual design fidelity (SwiftUI / Material 3) | Subjective assessment of colors, spacing, animations |
| Waveform visualization accuracy | Real-time audio visualization requires visual inspection |
| Pulse animation on record button | Animation timing and smoothness are visual |
| iCloud Drive sync (Story 7.5) | Requires signed-in iCloud account, network, and time to sync |
| Google Drive upload (Story 7.6) | Requires Google OAuth flow, network, Drive API interaction |
| Size estimate accuracy (Story 7.7) | Verify displayed estimates match actual file sizes |
| Swipe-to-delete gesture feel (Stories 7.3, 7.4) | Gesture interaction quality is subjective |

---

## 4. Mock Strategies for Hardware-Dependent Features

### Crystal Audio Bridge (Layer 1)

The Crystal native library exposes C-callable functions (`scribe_start_recording`, `scribe_stop_recording`, `scribe_start_playback`). For Layer 1 specs:

- **Mock the audio backend:** Replace the actual `CrystalAudio::Recorder` with a stub that returns success codes without accessing hardware.
- **Verify state transitions:** Test that the bridge functions correctly update internal state (idle -> recording -> stopped) without requiring actual audio capture.
- **Return code validation:** Ensure `0` on success, non-zero on error conditions (e.g., no permission, invalid path).

### UI Tests (Layer 2)

- **iOS (XCUITest):** Tests run against the app's UI without needing the Crystal library to produce real audio. Button existence, timer display, and navigation are independent of audio hardware.
- **Android (Compose UI Test):** `createAndroidComposeRule` renders the Compose UI in an isolated test environment. The Crystal native library (`libscribe.so`) may not load, so tests avoid triggering JNI calls. Layout and navigation tests pass regardless.

### E2E Shell Scripts (Layer 3)

- **Permission pre-granting:** Use `xcrun simctl privacy grant booted com.crimsonknight.scribe microphone` (iOS) or `adb shell pm grant com.crimsonknight.scribe android.permission.RECORD_AUDIO` (Android) before test execution.
- **File verification:** After a recording action, verify file existence via shell commands rather than through the app UI.

---

## 5. Assumptions

| Assumption | Rationale |
|---|---|
| Fresh install = empty recordings list | UI tests assume no prior recordings exist; empty state tests depend on this |
| Permission dialogs handled by simulator/emulator CLI | `xcrun simctl privacy grant` (iOS) and `adb shell pm grant` (Android) bypass OS dialogs |
| Crystal native library may not load in UI test environment | UI tests are designed to validate layout and navigation independently of native code |
| Default audio format is WAV | Matches macOS Scribe default; settings tests verify WAV is pre-selected |
| Default save location is "Local Only" | No cloud account required for basic functionality |
| Simulator audio is silent but functional | iOS Simulator and Android Emulator accept recording API calls even without real microphone input |

---

## 6. Test File Inventory

| Platform | File | Test Count | Lines | Stories Covered |
|---|---|---|---|---|
| iOS (L2) | `mobile/ios/ScribeUITests/ScribeUITests.swift` | 7 tests | — | 7.1, 7.3, 7.5, Nav |
| Android (L2) | `mobile/android/app/src/androidTest/kotlin/com/crimsonknight/scribe/ScribeUITests.kt` | 9 tests | — | 7.2, 7.4, 7.6, 7.7, Nav |
| Crystal (L1) | `mobile/shared/spec/scribe_bridge_spec.cr` | 25 tests | 306 | 7.1-7.4 (state machine) |
| iOS E2E (L3) | `mobile/ios/test_scribe_ios.sh` | 1 script | 153 | 7.1, 7.3, 7.5 |
| Android E2E (L3) | `mobile/android/test_scribe_android.sh` | 1 script | 111 | 7.2, 7.4, 7.6, 7.7 |
| CI Orchestrator | `mobile/run_all_tests.sh` | — | 139 | All (L1+L2, optional L3) |

---

## 7. Coverage Gaps and Next Steps

### Completed

1. **Layer 1 (Crystal Specs):** 25 bridge state machine specs implemented in `mobile/shared/spec/scribe_bridge_spec.cr`. Covers initialization, recording state machine, playback state machine, independence, and return code contracts. Uses standalone replica approach (see [Bridge Spec Replication Decision](bridge-spec-replication-decision.md)).
2. **Layer 3 (E2E Shell):** iOS E2E (`mobile/ios/test_scribe_ios.sh`, 153 lines) and Android E2E (`mobile/android/test_scribe_android.sh`, 111 lines) implemented. Both automate the full build-install-permission-test cycle.
3. **CI Orchestrator:** `mobile/run_all_tests.sh` (139 lines) ties L1+L2 together by default, with `--e2e` flag for L3.

### Still Pending

1. **Playback tests (Stories 7.3, 7.4):** Playback requires existing recordings. Consider a test fixture that places a known .wav file in the app's documents directory before running playback tests.
2. **Cloud sync tests (Stories 7.5, 7.6):** These require authenticated cloud accounts and are best left as manual test checklists.
3. **iOS Story 7.7 tests:** No iOS UI tests exist for audio format selection. The iOS app uses `7.7-format-picker` (a single picker) while Android uses separate `7.7-option-wav`/`7.7-option-m4a` test IDs.
4. **FEATURE STORY annotations:** Bridge spec needs `# FEATURE STORY:` annotations per FSDD methodology.
