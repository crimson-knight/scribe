# Apple Human Interface Guidelines -- Accessibility Reference

> Extracted from Apple's HIG (developer.apple.com/design/human-interface-guidelines)
> as of 2026-03-26. This is an original synthesis of Apple's guidance organized for
> use in building accessible macOS apps with the Asset Pipeline framework.

---

## Table of Contents

1. [Core Principles](#core-principles)
2. [VoiceOver](#voiceover)
3. [Color and Contrast](#color-and-contrast)
4. [Text Display and Typography](#text-display-and-typography)
5. [Motion and Animation](#motion-and-animation)
6. [Vision Accessibility](#vision-accessibility)
7. [Hearing Accessibility](#hearing-accessibility)
8. [Mobility Accessibility](#mobility-accessibility)
9. [Speech Accessibility](#speech-accessibility)
10. [Cognitive Accessibility](#cognitive-accessibility)
11. [Keyboard Accessibility](#keyboard-accessibility)
12. [Menu Bar Apps (macOS-Specific)](#menu-bar-apps-macos-specific)
13. [Dictation Tool Considerations](#dictation-tool-considerations)
14. [macOS Color System Reference](#macos-color-system-reference)
15. [macOS Typography Reference](#macos-typography-reference)
16. [Inclusion Guidelines](#inclusion-guidelines)
17. [Implementation Checklist](#implementation-checklist)

---

## Core Principles

An accessible interface must be:

- **Intuitive**: Uses familiar, consistent interactions that make tasks straightforward.
- **Perceivable**: Does not rely on any single method (sight, hearing, touch) to convey information.
- **Adaptable**: Adapts to how people want to use their device, supporting system accessibility features and personalization.

Apple provides the **Accessibility Inspector** tool to audit your interface for accessibility issues and understand how assistive technologies represent your app.

---

## VoiceOver

VoiceOver is a screen reader that lets people experience an app's interface without seeing the screen. Supporting it is essential for users who are blind or have low vision.

### Descriptions

- **Provide alternative labels for all key interface elements.** VoiceOver uses these labels (not visible onscreen) to audibly describe the interface. System controls have generic labels by default; provide more descriptive ones that convey your app's specific functionality.
- **Add labels to custom elements.** Any custom UI element your app defines must have an accessibility label.
- **Keep descriptions up to date** as your interface and content change.
- **Describe meaningful images.** If an image conveys information, provide an alternative text description. Only describe the information the image itself conveys (nearby captions handle surrounding context).
- **Make charts and infographics fully accessible.** Provide concise descriptions explaining what each infographic conveys. Make interactive elements available to VoiceOver users via accessibility APIs.
- **Exclude purely decorative images from VoiceOver.** Images that don't convey useful or actionable information should be hidden from assistive technologies. This reduces cognitive load.
  - AppKit: `isAccessibilityElement` / `accessibilityHidden`

### Navigation

- **Use titles and headings** to help people navigate information hierarchy. Each page/screen should have a unique, succinct title. Use accurate section headings to build a mental model.
- **Specify element grouping, ordering, and linking.** Proximity and alignment help sighted users see relationships; these must be explicitly described for VoiceOver.
- **VoiceOver reads in locale order** (e.g., top-to-bottom, left-to-right for US English). Group related elements together so descriptions are coherent.
  - AppKit: `shouldGroupAccessibilityChildren`
- **Report visible content and layout changes** so VoiceOver can help users update their mental model.
  - `AccessibilityNotification` for reporting changes
- **Support the VoiceOver rotor** to let users navigate by headings, links, and other content types.
  - AppKit: `NSAccessibilityCustomRotor`
  - SwiftUI: `AccessibilityRotorEntry`

---

## Color and Contrast

### Contrast Ratios (WCAG Level AA Minimums)

| Text Size | Text Weight | Minimum Contrast Ratio |
|-----------|-------------|----------------------|
| Up to 17pt | All | 4.5:1 |
| 18pt | All | 3:1 |
| All sizes | Bold | 3:1 |

These values come from WCAG Level AA standards and are used by Apple's Accessibility Inspector.

### Best Practices

- **Meet minimum contrast standards** between foreground (text/icons) and background colors. Use standard contrast calculators (WCAG or APCA).
- **If your app does not meet minimum contrast by default**, ensure it provides a higher-contrast color scheme when the system's "Increase Contrast" setting is active.
- **Check contrast in both light and dark appearances** if your app supports Dark Mode.
- **Prefer system-defined colors** which have built-in accessible variants that automatically adapt to Increase Contrast, light/dark mode, and other user preferences.
- **Convey information with more than color alone.** Use distinct shapes, icons, or patterns in addition to color. This is critical for colorblind users (especially red-green and blue-orange pairings).
- **Allow color customization** where practical (e.g., chart colors) so users can personalize for comfort.

### Inclusive Color Usage

- Avoid relying solely on color to differentiate objects, indicate interactivity, or communicate essential information.
- Avoid insufficient contrast that causes icons and text to blend with the background.
- Consider cultural color meanings when internationalizing.

### macOS-Specific Color Guidance

- Avoid hard-coding system color values; use APIs (`NSColor` properties) to apply system colors.
- Use dynamic system colors that are semantically defined by purpose (e.g., `labelColor`, `secondaryLabelColor`, `separatorColor`).
- Do not redefine the semantic meanings of dynamic system colors.
- Supply both light and dark color variants, plus increased-contrast variants.
- Test under various lighting conditions and on different displays.
- Use wide color (Display P3) to enhance visual experience on compatible displays.

---

## Text Display and Typography

### Minimum and Default Sizes

| Platform | Default Size | Minimum Size |
|----------|-------------|-------------|
| macOS | 13 pt | 10 pt |
| iOS/iPadOS | 17 pt | 11 pt |
| tvOS | 29 pt | 23 pt |
| visionOS | 17 pt | 12 pt |
| watchOS | 16 pt | 12 pt |

### Font Weight and Legibility

- **Avoid light font weights** (Ultralight, Thin, Light), which are difficult to see at small sizes. Prefer Regular, Medium, Semibold, or Bold.
- **Thicker weights are easier to read** for smaller font sizes.
- If using a thin custom font weight, aim for larger than the recommended sizes.

### macOS Text Styles

| Style | Weight | Size (pt) | Line Height (pt) | Emphasized Weight |
|-------|--------|-----------|-------------------|-------------------|
| Large Title | Regular | 26 | 32 | Bold |
| Title 1 | Regular | 22 | 26 | Bold |
| Title 2 | Regular | 17 | 22 | Bold |
| Title 3 | Regular | 15 | 20 | Semibold |
| Headline | Bold | 13 | 16 | Heavy |
| Body | Regular | 13 | 16 | Semibold |
| Callout | Regular | 12 | 15 | Semibold |
| Subheadline | Regular | 11 | 14 | Semibold |
| Footnote | Regular | 10 | 13 | Semibold |
| Caption 1 | Regular | 10 | 13 | Medium |
| Caption 2 | Medium | 10 | 13 | Semibold |

### System Fonts

- **SF Pro**: Sans serif system font for macOS (and iOS/iPadOS/visionOS).
- **New York (NY)**: Serif typeface family, available for Mac apps built with Mac Catalyst.
- macOS does **not** support Dynamic Type (unlike iOS).
- Use dynamic system font variants to match standard control text: `controlContentFont`, `labelFont`, `menuFont`, `menuBarFont`, `messageFont`, `toolTipsFont`, etc.

### Typography Best Practices

- **Minimize the number of typefaces** used. Too many typefaces obscure information hierarchy.
- **Adjust font weight, size, and color** to emphasize important information and convey hierarchy.
- **Test legibility** in different contexts, lighting, and on different devices.
- Implement accessibility features for custom fonts (Bold Text support, etc.).

---

## Motion and Animation

### Best Practices

- **Add motion purposefully.** Do not add motion for the sake of it. Gratuitous animation can distract and cause physical discomfort.
- **Make motion optional.** Never use motion as the only way to communicate important information.
- **Supplement visual feedback** with haptics and audio alternatives.
- **Aim for brevity and precision** in feedback animations -- lightweight and unobtrusive.
- **Let people cancel motion.** Do not make users wait for animations to complete.
- **Avoid adding motion to frequently-used UI interactions.** The system already provides subtle animations for standard elements.

### Reduce Motion Setting

When the "Reduce Motion" accessibility setting is active, your app must respond by:

- Reducing automatic and repetitive animations (zooming, scaling, peripheral motion)
- Tightening animation springs to reduce bounce effects
- Tracking animations directly with user gestures
- Avoiding depth changes in z-axis layers
- Replacing x/y/z-axis transitions with fades
- Avoiding animating into and out of blurs

### Flashing Content

- **Allow people to opt out of flashing lights** in video playback. Respond to the "Dim Flashing Lights" system setting.
- Be cautious with fast-moving and blinking animations, which can cause dizziness and in some cases epileptic episodes.

---

## Vision Accessibility

Users may be blind, color blind, have low vision, or experience light sensitivity. They may also be in challenging lighting conditions.

### Key Requirements

- **Support larger text sizes.** Allow text enlargement of at least 200%. Use Dynamic Type where available (note: macOS does not support Dynamic Type, but you should still provide text size options).
- **Use recommended font size defaults** for the platform (see Typography section).
- **Meet color contrast minimums** (see Color and Contrast section).
- **Prefer system-defined colors** for automatic accessibility adaptation.
- **Convey information through multiple channels**, not just color.
- **Support VoiceOver** with comprehensive labels and descriptions (see VoiceOver section).

---

## Hearing Accessibility

Users may be deaf, hard of hearing, or in noisy/public environments.

### Key Requirements

- **Support text-based alternatives for audio/video content:**
  - **Captions**: Synchronized text equivalent of audible information
  - **Subtitles**: Live onscreen dialogue in the user's preferred language
  - **Audio descriptions**: Spoken narration of visual-only information
  - **Transcripts**: Complete textual description covering both audible and visual content
- **Use haptics alongside audio cues** for feedback (success chimes, error sounds, game feedback).
- **Augment audio cues with visual cues.** Especially important when content might be offscreen.

---

## Mobility Accessibility

### Control Sizing

| Platform | Default Control Size | Minimum Control Size |
|----------|---------------------|---------------------|
| macOS | 28x28 pt | 20x20 pt |
| iOS/iPadOS | 44x44 pt | 28x28 pt |
| tvOS | 66x66 pt | 56x56 pt |
| visionOS | 60x60 pt | 28x28 pt |
| watchOS | 44x44 pt | 28x28 pt |

### Spacing and Padding

- Include enough padding between elements to reduce accidental taps/clicks.
- **Elements with bezel**: ~12 points of padding around elements.
- **Elements without bezel**: ~24 points of padding around visible edges.

### Gesture and Interaction

- **Use the simplest gestures possible** for frequent interactions. Avoid custom multifinger/multihand gestures.
- **Offer alternatives to gestures.** Provide onscreen buttons as alternatives to swipe, etc.
- **Support Voice Control** for verbal interaction.
- **Integrate with Siri and Shortcuts** for voice-only task automation.
- **Support assistive technologies**: VoiceOver, AssistiveTouch, Full Keyboard Access, Pointer Control, Switch Control.

---

## Speech Accessibility

Apple's accessibility features help people with speech disabilities and those who prefer text-based interactions.

### Key Requirements

- **Support Full Keyboard Access** so users can navigate and interact entirely via keyboard.
- Do not override system-defined keyboard shortcuts.
- **Support Switch Control** for users who rely on separate hardware, game controllers, or sounds to control their devices.

---

## Cognitive Accessibility

### Key Requirements

- **Keep actions simple and intuitive.** Prefer system gestures and behaviors.
- **Minimize time-boxed interface elements.** Auto-dismissing views are problematic for users who need more time. Prefer explicit dismiss actions.
- **Let people control audio/video playback.** Avoid autoplaying without start/stop controls.
- **Allow opt-out of flashing lights.** Respond to "Dim Flashing Lights" setting.
- **Reduce motion** when "Reduce Motion" is enabled (see Motion section).
- **Support Assistive Access** (iOS/iPadOS) which provides a streamlined, reduced-cognitive-load version of your app.

---

## Keyboard Accessibility

### Full Keyboard Access

- Support Full Keyboard Access so people can navigate and activate all interface elements using only the keyboard.
- Test with Full Keyboard Access enabled (System Settings > Accessibility).
- The keyboard focus indicator color (`keyboardFocusIndicatorColor` in AppKit) shows which control has focus.

### Standard Keyboard Shortcuts (macOS)

Key shortcuts that must work consistently:

| Shortcut | Action |
|----------|--------|
| Cmd+Q | Quit |
| Cmd+W | Close window |
| Cmd+, | Open settings |
| Cmd+H | Hide app |
| Cmd+M | Minimize window |
| Cmd+Z | Undo |
| Cmd+Shift+Z | Redo |
| Cmd+C / Cmd+V / Cmd+X | Copy / Paste / Cut |
| Cmd+A | Select All |
| Cmd+F | Find |
| Cmd+? | Help |
| Cmd+F5 | Toggle VoiceOver |
| Ctrl+F2 | Move focus to menu bar |

### Custom Keyboard Shortcuts

- Define custom shortcuts only for frequently-used app-specific commands.
- Use **Command** as the primary modifier key.
- Use **Shift** as a secondary modifier (complement to a related shortcut).
- Use **Option** sparingly for less-common commands.
- **Avoid Control** as a modifier (reserved for system use).
- Modifier key order: Control, Option, Shift, Command.
- Do not repurpose standard shortcuts for custom actions.
- Let the system localize and mirror shortcuts for different keyboards and layouts.

---

## Menu Bar Apps (macOS-Specific)

Scribe is a menu bar app (NSStatusItem, no dock icon). These guidelines apply:

### Menu Bar Extras

- **Use a symbol (SF Symbol or custom icon) to represent the menu bar extra.** Use black and clear colors for the shape; the system applies appropriate colors for dark/light menu bars and selection state. The menu bar height is 24 pt.
- **Display a menu (not a popover) when clicked**, unless functionality is too complex for a menu.
- **Let users decide** whether to show the menu bar extra (typically via a setting).
- **Do not rely on menu bar extra presence.** The system hides/shows them; you cannot predict their location.
- **Expose functionality through other means too** (e.g., Dock menu). A Dock menu is always available when the app is running.

### Standard Menu Structure

When providing menus, use the standard order:
1. App menu (About, Settings, Hide, Quit)
2. File
3. Edit
4. Format
5. View
6. App-specific menus
7. Window
8. Help

### Menu Bar Accessibility

- **Always show the same set of menu items.** Disable unavailable items rather than hiding them. This helps users learn available actions.
- **Support keyboard shortcuts** for all standard menu items.
- **Prefer short, one-word menu titles** for easy scanning.
- Menu bar extras should be accessible via VoiceOver and Full Keyboard Access.

---

## Dictation Tool Considerations

Scribe is a dictation-to-AI-agent pipeline. Specific accessibility considerations:

### For Audio Input (Dictation)

- Provide clear **visual indicators** of recording state (not just audio cues).
- Ensure recording status is **exposed to VoiceOver** with descriptive labels (e.g., "Recording in progress" not just a red dot icon).
- Support **keyboard shortcuts** to start/stop recording without mouse interaction.
- Consider users who **cannot use voice**: provide alternative text input as a fallback.

### For Transcription Output

- Display transcriptions in **text that meets contrast and size requirements**.
- Allow users to **adjust text size** of transcription output.
- Make transcription text **selectable and copyable** for use with assistive technologies.
- Ensure transcription results are **announced by VoiceOver** when they arrive (use accessibility notifications).

### For the AI Agent Response Inbox

- Label inbox items clearly for VoiceOver navigation.
- Support **keyboard navigation** through inbox items.
- Provide **time-independent** access to responses (no auto-dismissal of important content).
- Consider **audio feedback** (optional) for users who prefer auditory confirmation of new responses.

### For Notifications

- Ensure notifications are **perceivable through multiple channels**: visual banner + optional sound + VoiceOver announcement.
- Respect system notification preferences and Do Not Disturb.

---

## macOS Color System Reference

### Dynamic System Colors (AppKit)

These colors adapt to light/dark mode and Increase Contrast automatically:

| Purpose | AppKit API |
|---------|-----------|
| Primary text | `labelColor` |
| Secondary text | `secondaryLabelColor` |
| Tertiary text | `tertiaryLabelColor` |
| Quaternary text | `quaternaryLabelColor` |
| Link text | `linkColor` |
| Placeholder text | `placeholderTextColor` |
| Separator | `separatorColor` |
| Selected text background | `selectedTextBackgroundColor` |
| Selected content background | `selectedContentBackgroundColor` |
| Control surface | `controlColor` |
| Control text | `controlTextColor` |
| Disabled text | `disabledControlTextColor` |
| Control background | `controlBackgroundColor` |
| Keyboard focus ring | `keyboardFocusIndicatorColor` |
| Window background | `windowBackgroundColor` |
| Under-page background | `underPageBackgroundColor` |
| Grid lines | `gridColor` |
| App accent color | `controlAccentColor` |
| Find highlight | `findHighlightColor` |

### App Accent Colors (macOS 11+)

- Specify an accent color to customize buttons, selection highlighting, and sidebar icons.
- The system applies your accent color when the user's system setting is "multicolor."
- If the user selects a specific accent color, the system overrides yours (except for fixed-color sidebar icons).

---

## macOS Typography Reference

### System Font Variants (AppKit APIs)

| Variant | API |
|---------|-----|
| Control content | `controlContentFont(ofSize:)` |
| Labels | `labelFont(ofSize:)` |
| Menu items | `menuFont(ofSize:)` |
| Menu bar | `menuBarFont(ofSize:)` |
| Messages | `messageFont(ofSize:)` |
| Palette | `paletteFont(ofSize:)` |
| Title bar | `titleBarFont(ofSize:)` |
| Tooltips | `toolTipsFont(ofSize:)` |
| User document text | `userFont(ofSize:)` |
| User monospaced text | `userFixedPitchFont(ofSize:)` |
| Bold system | `boldSystemFont(ofSize:)` |
| System font | `systemFont(ofSize:)` |

### SF Pro Tracking (macOS)

Tracking adjustments vary by point size. At 13pt (macOS body default), tracking is -0.08pt (-6/1000 em). Tracking values generally decrease (become tighter) from 6pt to about 17pt, then increase for larger sizes. Consult the full tracking table for precise values at each point size.

---

## Inclusion Guidelines

### Language

- Use plain, inclusive language that everyone can understand.
- Address users directly ("you" and "your") rather than "the user."
- Avoid specialized/technical terms without definitions.
- Replace colloquial expressions with plain language.
- Be cautious with humor (subjective and culture-specific).

### People and Representation

- Portray human diversity when representing people.
- Avoid stereotypical representations.
- Support gender-neutral language and imagery.
- Provide inclusive options when collecting personal information (nonbinary, self-identify, decline to state).

### Accessibility as Inclusion

- Each disability exists on a spectrum.
- Everyone can experience disabilities (permanent, temporary, or situational).
- Avoid images and language that exclude people with disabilities.
- Take a people-first approach when writing about disability.
- Prioritize simplicity and perceivability.

---

## Implementation Checklist

Use this checklist when building and auditing Scribe and other Asset Pipeline apps:

### VoiceOver
- [ ] All interactive elements have descriptive accessibility labels
- [ ] Custom UI elements are properly exposed to accessibility APIs
- [ ] Decorative images are hidden from VoiceOver
- [ ] Related elements are properly grouped
- [ ] Layout/content changes trigger accessibility notifications
- [ ] VoiceOver rotor support for navigation (if applicable)

### Color and Contrast
- [ ] All text meets 4.5:1 contrast ratio (or 3:1 for 18pt+/bold)
- [ ] Information is conveyed through multiple channels (not color alone)
- [ ] App supports Increase Contrast setting
- [ ] Both light and dark mode meet contrast requirements
- [ ] System-defined colors used where possible

### Typography
- [ ] No text below 10pt (macOS minimum)
- [ ] Body text at 13pt minimum (macOS default)
- [ ] Light/thin font weights avoided at small sizes
- [ ] Text size can be adjusted by the user
- [ ] Bold Text accessibility setting is respected

### Motion
- [ ] App responds to Reduce Motion setting
- [ ] No essential information communicated only through animation
- [ ] Animations are brief and purposeful
- [ ] Users can cancel/skip animations
- [ ] No rapid flashing content (or responds to Dim Flashing Lights)

### Keyboard
- [ ] Full Keyboard Access supported
- [ ] All standard keyboard shortcuts respected (Cmd+Q, Cmd+W, etc.)
- [ ] Custom shortcuts follow modifier key conventions
- [ ] Focus ring visible on focused elements
- [ ] Tab navigation works through all interactive elements

### Menu Bar (Scribe-Specific)
- [ ] Menu bar icon uses proper 24pt height, black+clear colors
- [ ] Menu (not popover) displayed on click
- [ ] All menu items accessible via keyboard
- [ ] Disabled items shown (not hidden) when unavailable
- [ ] Recording state communicated to VoiceOver
- [ ] Keyboard shortcut for start/stop recording

### Controls
- [ ] Minimum control size 20x20pt (macOS minimum)
- [ ] Adequate padding between controls (12pt with bezel, 24pt without)
- [ ] Simple gestures used for common interactions
- [ ] Alternative input methods supported (keyboard, Voice Control)

### General
- [ ] Tested with Accessibility Inspector
- [ ] Tested with VoiceOver enabled
- [ ] Tested with Increase Contrast enabled
- [ ] Tested with Reduce Motion enabled
- [ ] Tested with Full Keyboard Access enabled
- [ ] No time-boxed UI elements without user control

---

## Source Pages

These guidelines were synthesized from the following Apple HIG pages:

- Accessibility: developer.apple.com/design/human-interface-guidelines/accessibility
- VoiceOver: developer.apple.com/design/human-interface-guidelines/voiceover
- Color: developer.apple.com/design/human-interface-guidelines/color
- Typography: developer.apple.com/design/human-interface-guidelines/typography
- Motion: developer.apple.com/design/human-interface-guidelines/motion
- The Menu Bar: developer.apple.com/design/human-interface-guidelines/the-menu-bar
- Keyboards: developer.apple.com/design/human-interface-guidelines/keyboards
- Inclusion: developer.apple.com/design/human-interface-guidelines/inclusion
