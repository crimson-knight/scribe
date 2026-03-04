package com.crimsonknight.scribe

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Compose UI test suite for Scribe Android app.
 * Organized by FSDD feature stories (Epic 7: Mobile Recording).
 * Test tags follow pattern: {epic}.{story}-{element-name}
 *
 * NOTE: These are instrumented tests that require a running emulator or device.
 * The Crystal native library (libscribe.so) may not be available in the test
 * environment, so tests that trigger native calls (e.g., record/play) may fail
 * at runtime. UI layout and navigation tests should pass regardless.
 */
@RunWith(AndroidJUnit4::class)
class ScribeUITests {

    @get:Rule
    val composeTestRule = createAndroidComposeRule<MainActivity>()

    // ── Story 7.2: Record Voice Memo on Android ──

    @Test
    fun recordButton_exists() {
        composeTestRule
            .onNodeWithTag("7.2-record-button")
            .assertIsDisplayed()
    }

    @Test
    fun timerDisplay_showsInitialState() {
        composeTestRule
            .onNodeWithTag("7.2-timer-display")
            .assertIsDisplayed()
        // Verify initial text is "00:00"
        composeTestRule
            .onNodeWithText("00:00")
            .assertIsDisplayed()
    }

    @Test
    fun statusText_showsReadyState() {
        composeTestRule
            .onNodeWithTag("7.2-status-text")
            .assertIsDisplayed()
        composeTestRule
            .onNodeWithText("Ready to record")
            .assertIsDisplayed()
    }

    // ── Story 7.4: Browse Recordings (Android) ──

    @Test
    fun recordingsTab_navigates() {
        // Tap recordings tab
        composeTestRule
            .onNodeWithTag("nav-tab-recordings")
            .performClick()

        // On fresh install, empty state should appear
        composeTestRule
            .onNodeWithTag("7.4-empty-state")
            .assertIsDisplayed()
    }

    @Test
    fun recordingsTab_showsEmptyState() {
        composeTestRule
            .onNodeWithTag("nav-tab-recordings")
            .performClick()

        composeTestRule
            .onNodeWithText("No recordings yet")
            .assertIsDisplayed()
    }

    // ── Story 7.6: Settings Save Location (Android) ──

    @Test
    fun settingsTab_navigates() {
        composeTestRule
            .onNodeWithTag("nav-tab-settings")
            .performClick()

        // Verify settings content is displayed
        composeTestRule
            .onNodeWithText("Save Location")
            .assertIsDisplayed()
    }

    @Test
    fun settingsScreen_showsSaveLocationOptions() {
        composeTestRule
            .onNodeWithTag("nav-tab-settings")
            .performClick()

        composeTestRule
            .onNodeWithTag("7.6-option-local")
            .assertIsDisplayed()

        composeTestRule
            .onNodeWithTag("7.6-option-google-drive")
            .assertIsDisplayed()
    }

    // ── Story 7.7: Audio Format Selection ──

    @Test
    fun settingsScreen_showsAudioFormatOptions() {
        composeTestRule
            .onNodeWithTag("nav-tab-settings")
            .performClick()

        composeTestRule
            .onNodeWithTag("7.7-option-wav")
            .assertIsDisplayed()

        composeTestRule
            .onNodeWithTag("7.7-option-m4a")
            .assertIsDisplayed()
    }

    // ── Navigation ──

    @Test
    fun allThreeTabs_accessible() {
        // Record tab (default, should be visible)
        composeTestRule
            .onNodeWithTag("nav-tab-record")
            .assertIsDisplayed()

        // Recordings tab
        composeTestRule
            .onNodeWithTag("nav-tab-recordings")
            .assertIsDisplayed()
            .performClick()

        // Settings tab
        composeTestRule
            .onNodeWithTag("nav-tab-settings")
            .assertIsDisplayed()
            .performClick()

        // Navigate back to record
        composeTestRule
            .onNodeWithTag("nav-tab-record")
            .performClick()

        // Verify record screen elements are back
        composeTestRule
            .onNodeWithTag("7.2-record-button")
            .assertIsDisplayed()
    }
}
