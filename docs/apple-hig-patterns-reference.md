# Apple HIG Patterns and Input Reference

Extracted from Apple Human Interface Guidelines (developer.apple.com/design/human-interface-guidelines).
Scraped 2026-03-26. Focus on design principles, macOS-specific details, dimensions/timing, and accessibility.

---

## Table of Contents

1. [Launching](#1-launching)
2. [Feedback](#2-feedback)
3. [Entering Data](#3-entering-data)
4. [Managing Notifications](#4-managing-notifications)
5. [Modality](#5-modality)
6. [Playing Audio](#6-playing-audio)
7. [Searching](#7-searching)
8. [Alerts](#8-alerts)
9. [Panels](#9-panels)
10. [Pickers](#10-pickers)
11. [Segmented Controls](#11-segmented-controls)
12. [Progress Indicators](#12-progress-indicators)

---

## 1. Launching

**Source:** https://developer.apple.com/design/human-interface-guidelines/launching

### Design Principles and Rules

- Launch instantly. People want to start interacting right away and sometimes will not wait more than a couple of seconds.
- If the platform requires it, provide a launch screen. macOS, visionOS, and watchOS do NOT require launch screens.
- If you need a splash screen, consider displaying it at the beginning of your onboarding flow, not as a launch screen.
- Restore the previous state when the app restarts so people can continue where they left off. Restore granular details: scroll position, window state and location.

### macOS-Specific Implementation

- **No launch screen required.** macOS does not use or require launch screens.
- **No additional platform considerations** are listed for macOS.
- Windows should be restored in the same state and location in which people left them.

### Launch Screen Rules (iOS/iPadOS -- informational)

- A launch screen is NOT a splash screen, onboarding experience, or branding opportunity.
- Design the launch screen to be nearly identical to the first screen of the app to avoid a visual flash.
- Do not include text on the launch screen (not localizable).
- Do not advertise or include logos unless they are a fixed part of the first screen.

### Accessibility Requirements

- No specific accessibility requirements listed for launching.

### Timing Values

- People sometimes will not wait more than a couple of seconds for launch to complete.

---

## 2. Feedback

**Source:** https://developer.apple.com/design/human-interface-guidelines/feedback

### Design Principles and Rules

- Feedback helps people know what is happening, discover what they can do next, understand results of actions, and avoid mistakes.
- Match the significance of information to the way it is delivered (passive vs. interruptive).
- Feedback can communicate: current status, success/failure of a task, warnings about negative consequences, opportunities to correct mistakes.
- Use alerts only for critical and ideally actionable information. Alerts lose impact when overused.
- Warn people when they initiate a task that can cause unexpected and irreversible data loss. Do NOT warn when data loss is the expected result of their action (e.g., deleting a file).
- Confirm that a significant action or task has completed when appropriate (e.g., Apple Pay transaction). Reserve for sufficiently important activities.
- Show people when a command cannot be carried out and help them understand why.

### macOS-Specific Implementation

- No additional platform considerations listed for macOS.

### Accessibility Requirements

- **Make all feedback accessible.** Use multiple modalities: color, text, sound, and haptics, so people can receive feedback whether they silence their device, look away, or use VoiceOver.
- Integrate status feedback into the interface near the items it describes so people do not have to take action or leave their current context.

### Timing Values

- No specific timing values listed.

---

## 3. Entering Data

**Source:** https://developer.apple.com/design/human-interface-guidelines/entering-data

### Design Principles and Rules

- Minimize the amount of data people need to supply. Pre-gather information from the system whenever possible.
- Be clear about the data you need: use prompts, introductory labels, and prefilled default values.
- Use secure text-entry fields for sensitive data (obscures input with filled circle symbols).
- Never prepopulate a password field. Always require entry or biometric/keychain authentication.
- Offer choices instead of requiring text entry when possible (pickers, menus, selection components).
- Let people provide data by dragging and dropping or pasting.
- Dynamically validate field values as people enter them; provide feedback immediately on errors.
- For numeric data, use a number formatter (accepts only numeric values, configurable display: decimal places, percentage, currency).
- Make people understand that required data must be provided before proceeding (e.g., disable Next/Continue button until fields are filled).

### macOS-Specific Implementation

- **Expansion tooltips:** Use expansion tooltips to show the full version of clipped or truncated text in a field. Behaves like a regular tooltip, appearing when the pointer rests on top of a field. Works in macOS apps including iOS/iPadOS apps running on Mac.
- Reference: See "Offering help > macOS, visionOS" for tooltip guidance.

### Accessibility Requirements

- Support all available input methods so people can choose the method that works for them.
- Secure text fields should obscure input visually.

### Timing Values

- No specific timing values listed.

---

## 4. Managing Notifications

**Source:** https://developer.apple.com/design/human-interface-guidelines/managing-notifications

### Design Principles and Rules

- You MUST get permission before sending any notification. People can change this in Settings.
- A Focus helps people filter notifications during reserved activities (sleeping, working, reading, driving).
- Delivery scheduling: people choose immediate delivery or scheduled summaries.
- Even when a Focus delays a notification alert, the notification itself is available immediately upon arrival.

### Interruption Levels (Noncommunication Notifications)

| Level | Overrides Scheduled Delivery | Breaks Through Focus | Overrides Ring/Silent |
|---|---|---|---|
| Passive | No | No | No |
| Active (default) | No | No | No |
| Time Sensitive | Yes | Yes | No |
| Critical | Yes | Yes | Yes |

- **Passive:** Information people can view at leisure (e.g., restaurant recommendation).
- **Active (default):** Information people might appreciate when it arrives (e.g., score update).
- **Time Sensitive:** Directly impacts the person, requires immediate attention (e.g., account security, package delivery).
- **Critical:** Urgent health/safety information. Requires a special entitlement. Extremely rare.

### Best Practices

- Build trust by accurately representing urgency of each notification.
- Use Time Sensitive only for events happening now or within an hour.
- NEVER use Time Sensitive for marketing notifications.
- Get explicit permission before sending marketing/promotional notifications. Provide an in-app settings screen for managing notification preferences.

### macOS-Specific Implementation

- No additional platform considerations listed for macOS.

### Accessibility Requirements

- No specific accessibility requirements listed beyond general notification management.

### Timing Values

- Time Sensitive: relevant events happening now or within one hour.
- The system periodically gives people opportunities to re-evaluate Time Sensitive notification permissions.

---

## 5. Modality

**Source:** https://developer.apple.com/design/human-interface-guidelines/modality

### Design Principles and Rules

- Modality presents content in a separate, dedicated mode that prevents interaction with the parent view and requires an explicit action to dismiss.
- Use modality to: deliver critical information requiring action, confirm/modify recent actions, perform distinct narrowly scoped tasks, provide immersive experiences.
- Present content modally ONLY when there is a clear benefit.
- Keep modal tasks simple, short, and streamlined. People can lose track of suspended tasks.
- Avoid creating a modal that feels like an app within an app. Avoid hierarchy of views within modals.
- Use full-screen modal style for in-depth content or complex tasks (videos, photos, camera views, document markup, photo editing).
- Always provide an obvious way to dismiss a modal view.
- Help people avoid data loss by confirming before closing a modal with user-generated content.
- Make it easy to identify the modal view's task with a title or descriptive text.
- Let people dismiss one modal view before presenting another. Avoid multiple visible modal views.
- Never display more than one alert at the same time.

### macOS-Specific Implementation

- macOS apps use sheets or popovers for distinct tasks; can also use separate windows.
- People expect to find a dismiss button in the main content view (not in a top toolbar like iOS).
- Developer guidance: Modal Windows and Panels (AppKit), UIModalPresentationStyle (UIKit).

### Accessibility Requirements

- Ensure the dismiss mechanism is clearly accessible and discoverable.

### Timing Values

- No specific timing values listed.

---

## 6. Playing Audio

**Source:** https://developer.apple.com/design/human-interface-guidelines/playing-audio

### Design Principles and Rules

- **Silence behavior:** When a device is in silent mode, it plays only audio that people explicitly initiate (media playback, alarms, audio/video messaging). All nonessential sounds (keyboard clicks, effects, game soundtracks) are silenced.
- **Volume:** People expect volume settings to affect all sound in the system. Exception: iPhone ringer volume, adjustable separately in Settings.
- **Headphones:** Sound reroutes automatically when connecting headphones (no interruption). Playback pauses immediately when headphones are disconnected.
- Adjust relative/independent volume levels for mixing, but the system volume always governs final output.
- Permit rerouting of audio when possible.
- Use the system-provided volume view (MPVolumeView) for audio adjustments.

### Audio Session Categories

| Category | Meaning | Responds to Silence | Mixes with Other | Background |
|---|---|---|---|---|
| Solo Ambient | Sound not essential, silences other audio | Yes | No | No |
| Ambient | Sound not essential, does not silence other audio | Yes | Yes | No |
| Playback | Sound essential, might mix | No | Optional | Yes |
| Record | Sound is recorded | No | No | Yes (recording) |
| Play and Record | Simultaneous record and play | No | Optional | Yes |

### Handling Interruptions

- Determine how to respond to audio-session interruptions. Can tell system to avoid interrupting for incoming calls unless accepted.
- When an interruption ends, decide whether to resume playback automatically based on interruption type (resumable vs nonresumable) and app type.
- Media playback app: check that interruption is resumable before continuing. Game: can auto-resume without checking.

### macOS-Specific Implementation

- **Notification sounds mix with other audio by default** in macOS.
- No other macOS-specific considerations listed.

### Accessibility Requirements

- Avoid communicating important information using only sound. Always provide additional ways to help people understand the app.
- Respond to audio controls only when it makes sense (actively playing audio, in audio-related context, connected via Bluetooth/AirPlay).
- Avoid repurposing audio controls; people expect consistent behavior across all apps.

### Timing Values

- No specific timing values listed.

---

## 7. Searching

**Source:** https://developer.apple.com/design/human-interface-guidelines/searching

### Design Principles and Rules

- If search is important, make it a primary action (e.g., distinct tab in tab bar, or search field in toolbar).
- Aim for a single search location to find anything in the app.
- Use placeholder text to indicate what content is searchable.
- Clearly display the current scope of a search (descriptive placeholder, scope control, or title).
- Provide search suggestions (recent searches, suggestions before and during typing) to help people search faster and type less.
- Consider privacy before displaying search history; provide a way to clear it.

### Systemwide Search (Spotlight)

- Make app content searchable in Spotlight by making it indexable with descriptive metadata attributes.
- Define metadata for custom file types with a Spotlight File Importer plug-in (CSImportExtension).
- Use Spotlight for advanced file-search capabilities within the app context.
- Prefer system-provided open and save views (include built-in search field).
- Implement a Quick Look generator for custom file types.

### macOS-Specific Implementation

- No additional platform considerations listed, but Spotlight integration and system-provided open/save views are particularly relevant on macOS.
- Quick Look generator support for custom file types.

### Accessibility Requirements

- No specific accessibility requirements listed beyond general searchability.

### Timing Values

- No specific timing values listed.

---

## 8. Alerts

**Source:** https://developer.apple.com/design/human-interface-guidelines/alerts

### Design Principles and Rules

- An alert gives people critical information they need right away.
- **Use alerts sparingly.** Each should offer only essential information and useful actions. Overuse diminishes impact.
- Avoid using an alert merely to provide information that is not actionable.
- Avoid alerts for common, undoable actions even when destructive (e.g., deleting an email is intentional and undoable).
- Avoid showing an alert when the app starts. Design information to be discoverable instead.

### Alert Anatomy

- All platforms: title, optional informative text, up to 3 buttons.
- iOS, iPadOS, macOS, visionOS: can include a text field.
- macOS and visionOS: can include an icon and accessory view.
- **macOS-specific:** can add a suppression checkbox and a Help button.

### Content Guidelines

- Use a direct, neutral, approachable tone.
- **Title:** Clearly and succinctly describe the situation. Be complete and specific. Avoid vague titles like "Error." If a complete sentence, use sentence-style capitalization with ending punctuation. If a fragment, use title-style capitalization, no ending punctuation. Keep to two lines or fewer.
- **Informative text:** Include only if it adds value. Keep as short as possible. Use complete sentences, sentence-style capitalization, appropriate punctuation.
- Do not explain alert buttons unless absolutely necessary. Use "choose" (not "click" or "tap") to account for all input methods.

### Button Guidelines

- Create succinct, logical button titles (one or two words). Prefer verbs/verb phrases that relate directly to alert text.
- Use "OK" only for informational alerts. Avoid "Yes" and "No."
- Always use "Cancel" to title the cancellation button.
- Use title-style capitalization, no ending punctuation.
- **Button placement:** Most-likely button on trailing side (row) or top (stack). Default button on trailing side or top. Cancel button on leading side or bottom.
- **Destructive style:** Apply only for destructive actions people did NOT deliberately choose. If the destructive action was the person's original intent (e.g., Empty Trash), do NOT apply destructive style.
- Always include a Cancel button when there is a destructive action.
- Do not make Cancel the default button. To encourage reading, consider having no default button.
- If a single button that is also default, use "Done" not "Cancel."

### Cancel Alternatives by Platform

| Action | Platform |
|---|---|
| Exit to Home Screen | iOS, iPadOS |
| Pressing Escape or Cmd+Period on keyboard | iOS, iPadOS, macOS, visionOS |
| Pressing Menu on remote | tvOS |

### macOS-Specific Implementation

- macOS automatically displays the app icon in an alert; you can supply an alternative icon or symbol.
- **Suppression checkbox:** Configure repeating alerts to let people suppress subsequent occurrences.
- **Custom accessory view** (accessoryView) for additional information.
- **Help button** that opens help documentation.
- **Caution symbol** (exclamationmark.triangle): Use sparingly. Only when extra attention is needed for unexpected data loss. Do NOT use for tasks whose purpose is to overwrite or remove data (save, empty trash).

### Accessibility Requirements

- Provide alternative ways to cancel alerts (keyboard shortcuts, Home button, etc.).
- Use clear, direct language in titles and button labels.

### Dimensions and Timing

- visionOS accessory view: maximum height of 154 pt with 16 pt corner radius.
- Alert title: keep to two lines maximum.

---

## 9. Panels

**Source:** https://developer.apple.com/design/human-interface-guidelines/panels

### Design Principles and Rules

- A panel typically floats above other open windows, providing supplementary controls, options, or information related to the active window or current selection.
- Panels can use a standard appearance or a dark translucent HUD (heads-up display) style.
- Use a panel for quick access to important controls or information related to current content.
- Consider using a panel for inspector functionality (auto-updates when selection changes). For Info windows (static content), use a regular window.
- Prefer simple adjustment controls (sliders, steppers) over controls requiring text typing or item selection.

### Panel Title and Behavior

- Write a brief title using a noun or noun phrase with title-style capitalization (e.g., "Fonts", "Colors", "Inspector").
- When the app becomes active, bring all open panels to the front regardless of which window was active.
- When the app is inactive, hide all panels.
- Do NOT include panels in the Window menu's documents list. Commands to show/hide panels are fine in the Window menu.
- Generally, do NOT make a panel's minimize button available.
- In menus, refer to panels by title without the word "panel" (e.g., "Show Fonts"). In help documentation, use the title alone or append "window" for clarity (e.g., "Fonts window").

### HUD-Style Panels

- Serve the same function as standard panels but with a darker, translucent appearance.
- Use HUDs ONLY in: media-oriented apps (movies, photos, slideshows), when a standard panel would obscure essential content, when you do not need standard controls (most system controls do not match HUD appearance, except disclosure triangles).
- Maintain one panel style when the app switches modes (e.g., keep HUD when leaving full-screen).
- Use color sparingly in HUDs. High-contrast color only for highlighting important information.
- Keep HUDs small; they should not obscure the content they adjust or compete for attention.

### macOS-Specific Implementation

- **macOS-only component.** Not supported in iOS, iPadOS, tvOS, visionOS, or watchOS.
- Developer guidance: NSPanel (AppKit), hudWindow (AppKit).
- On other platforms, use a modal view for supplementary content.

### Accessibility Requirements

- No specific accessibility requirements listed beyond standard panel interaction patterns.

### Dimensions and Timing

- No specific dimensions listed; HUDs should be kept small.

---

## 10. Pickers

**Source:** https://developer.apple.com/design/human-interface-guidelines/pickers

### Design Principles and Rules

- A picker displays one or more scrollable lists of distinct values for people to choose from.
- Date pickers offer additional ways: calendar view, numeric keypad entry.
- Use a picker for medium-to-long lists. For short lists, use a pull-down button instead. For very large sets, use a list or table (adjustable height, index support).
- Use predictable and logically ordered values (e.g., alphabetized countries) so people can predict hidden values.
- Display pickers in context (below or near the editing field). Appears at bottom of window or in a popover. Avoid switching views to show a picker.
- Consider less granularity for minutes in date pickers: interval must divide evenly into 60 (e.g., 0, 15, 30, 45 for quarter-hour).

### Date Picker Styles (iOS/iPadOS)

| Style | Description |
|---|---|
| Compact | Button that opens editable date/time in a modal view (popover) |
| Inline | Time: wheels of values. Dates: inline calendar view |
| Wheels | Scrolling wheels, supports keyboard data entry |
| Automatic | System-determined style based on platform and mode |

### Date Picker Modes

| Mode | Values Displayed |
|---|---|
| Date | Months, days of the month, years |
| Time | Hours, minutes, optional AM/PM |
| Date and Time | Dates, hours, minutes, optional AM/PM |
| Countdown Timer | Hours and minutes, max 23h 59m. Not available in inline/compact styles |

### macOS-Specific Implementation

- **Two date picker styles:** Textual and Graphical.
  - **Textual:** Useful for limited space and specific date/time selections.
  - **Graphical:** Useful for browsing days in a calendar, selecting date ranges, or when a clock face appearance is appropriate.
- Developer guidance: NSDatePicker (AppKit).

### Accessibility Requirements

- No specific accessibility requirements listed.

### Dimensions and Timing

- Minute interval must divide evenly into 60. Default: 60 values (0-59).
- Countdown timer maximum: 23 hours and 59 minutes.

---

## 11. Segmented Controls

**Source:** https://developer.apple.com/design/human-interface-guidelines/segmented-controls

### Design Principles and Rules

- A segmented control is a linear set of two or more segments, each functioning as a button.
- All segments are usually equal in width. Can contain text or images, and can have text labels beneath.
- Offers a single choice from options. In macOS, can also offer multiple choices.
- Can also function as momentary action buttons (no selection state), e.g., Reply/Reply All/Forward in Mail.
- Use for closely related choices that affect an object, state, or view.
- Segmented controls preserve their grouping regardless of view size or placement.
- Keep control types consistent within a single control (do not mix selection and action behaviors).
- Limit segments: no more than about 5-7 in a wide interface, no more than about 5 on iPhone.
- Keep segment sizes consistent (equal width).

### Content Guidelines

- Prefer using either text OR images in a single control (not a mix).
- Use content of similar size in each segment.
- Use nouns or noun phrases for labels with title-style capitalization.
- A segmented control displaying text labels does not need introductory text.

### macOS-Specific Implementation

- Supports both single-choice and **multiple-choice** selection modes (e.g., bold + italic + underline).
- Can function as momentary action buttons (isMomentary, NSSegmentedControl.SwitchTracking.momentary).
- Consider using introductory text or labels below segments to clarify purpose, especially with symbols/icons.
- If the app includes tooltips, provide one for each segment.
- Use a **tab view** (not segmented control) in the main window area for view switching. Use segmented controls for view switching in toolbars or inspector panes.
- **Spring loading support:** On Macs with Magic Trackpad, people can activate a segment by dragging items over it and force clicking without dropping.

### Accessibility Requirements

- visionOS: When using icons, the system displays tooltips with descriptive text.
- macOS: Provide tooltips for each segment.

### Dimensions and Timing

- Maximum recommended segments: 5-7 in wide interfaces, ~5 on iPhone.

---

## 12. Progress Indicators

**Source:** https://developer.apple.com/design/human-interface-guidelines/progress-indicators

### Design Principles and Rules

- Progress indicators let people know the app is not stalled while loading content or performing lengthy operations.
- All progress indicators are transient: appear only during operations, disappear on completion.
- **Two types:**
  - **Determinate:** For tasks with well-defined duration (e.g., file conversion). Fills a linear or circular track.
  - **Indeterminate:** For unquantifiable tasks (e.g., loading, synchronizing). Uses an animated spinning image.
- Progress bars fill from leading to trailing side. Circular indicators fill clockwise.

### Best Practices

- **Prefer determinate indicators.** They help people estimate wait time and decide whether to do something else.
- Be as accurate as possible reporting advancement. Even out the pace (avoid 90% in 5 seconds then 10% in 5 minutes).
- **Keep indicators moving** so people know something is happening. A stationary indicator suggests a stalled or frozen app.
- Switch from indeterminate to determinate when possible (when duration becomes known).
- Do NOT switch from circular style to bar style (different shapes/sizes cause disruption).
- Display a description for additional context if helpful. Avoid vague terms like "loading" or "authenticating."
- Use a consistent location for progress indicators across platforms and within/between apps.
- Let people halt processing when feasible. Include a Cancel button. If interruption has negative side effects (e.g., losing downloaded data), also provide a Pause button.
- When canceling results in lost progress, provide an alert with options to confirm cancellation or resume.

### macOS-Specific Implementation

- macOS supports an **indeterminate progress bar** in addition to the standard circular activity indicator (spinner).
- **Prefer an activity indicator (spinner)** for background operations or when space is constrained (e.g., within text fields, next to buttons).
- Spinners are small and unobtrusive; useful for async background tasks like retrieving messages from a server.
- Avoid labeling a spinning progress indicator (label is usually unnecessary since people initiated the process).

### iOS-Specific: Refresh Content Controls

- A refresh control lets people immediately reload content by dragging down (pull-to-refresh). Hidden by default.
- Perform automatic content updates in addition to manual refresh.
- A short title is optional; use only if it adds value (e.g., last update time). Do not use to explain how to refresh.

### Accessibility Requirements

- No specific accessibility requirements listed, but visual progress indicators should be supplemented with accessible descriptions.

### Dimensions and Timing

- macOS indeterminate progress bar and circular spinner are both animated.
- No specific pixel dimensions listed for progress indicators in the HIG.
- watchOS: System displays progress indicators in white over the scene's background color by default; customizable via tint color.

---

## Cross-Cutting Themes

### General macOS Conventions (across all patterns)

1. **No launch screen needed.** Apps should launch instantly and restore previous state.
2. **Panels are macOS-only** and float above windows. Use NSPanel, not available on other platforms.
3. **Alerts include suppression checkboxes, Help buttons, and custom accessory views** on macOS.
4. **Tooltips** (expansion tooltips for text fields, segment tooltips for segmented controls) are a macOS pattern.
5. **Keyboard shortcuts:** Escape or Cmd+Period to dismiss alerts and cancel operations.
6. **Spring loading** on Magic Trackpad for segmented controls.
7. **Tab views** for main-area view switching; segmented controls for toolbar/inspector switching.
8. **Notification sounds mix with other audio** by default on macOS.
9. **Date pickers** come in textual and graphical styles on macOS.

### Accessibility Across All Patterns

- Make all feedback accessible through multiple modalities (color + text + sound + haptics).
- Never rely solely on one modality (especially sound or color alone) to communicate important information.
- Support all available input methods.
- Provide tooltips and descriptive text for icon-based controls.
- Ensure dismiss mechanisms are discoverable and accessible.
- Use clear, direct, neutral language in all alert and notification copy.
- Provide keyboard shortcuts as alternative interaction paths (Escape, Cmd+Period).
