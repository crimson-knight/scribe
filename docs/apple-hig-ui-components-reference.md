# Apple HIG UI Components Reference

Extracted from Apple Human Interface Guidelines (developer.apple.com/design/human-interface-guidelines).
Last scraped: 2026-03-26.

---

## Table of Contents

1. [Settings](#1-settings)
2. [Toggles](#2-toggles)
3. [Text Fields](#3-text-fields)
4. [Buttons](#4-buttons)
5. [Windows](#5-windows)
6. [Labels](#6-labels)
7. [The Menu Bar](#7-the-menu-bar)
8. [Onboarding](#8-onboarding)
9. [Keyboards](#9-keyboards)
10. [Notifications](#10-notifications)
11. [Focus and Selection](#11-focus-and-selection)
12. [Menus](#12-menus)

---

## 1. Settings

**Source:** https://developer.apple.com/design/human-interface-guidelines/settings

### Overview

People expect apps to just work, but they also appreciate having ways to customize the experience. The system-provided Settings app lets people adjust overall appearance, network connections, account details, accessibility requirements, and language/region settings.

### Best Practices

| Guideline | Details |
|-----------|---------|
| Provide good defaults | Aim to provide default settings that give the best experience to the largest number of people. People may not have to make any adjustments before they can start. |
| Minimize settings count | Too many settings make the experience feel less approachable and make it hard to find a particular setting. |
| Use expected access patterns | When a physical keyboard is connected, people often use **Cmd+Comma (,)** to open settings. In games, players often use **Esc**. |
| Detect instead of asking | Automatically detect connected controllers, Dark Mode, etc. instead of asking in settings. |
| Respect systemwide settings | Do not include redundant versions of global options (accessibility, scrolling behavior, auth methods) in your custom settings area. |

### General Settings

- Put general, infrequently changed settings in your custom settings area.
- People must suspend what they're doing to open settings, so include only options that do not need frequent changing.
- Examples: window configuration, game-saving behavior, keyboard mappings, account options.

### Task-Specific Options

- Prefer letting people modify task-specific options without going to your settings area.
- Show/hide parts of the current view, reorder collections, or filter lists should be in-context, not in a separate settings area.

### macOS-Specific Behavior

| Requirement | Details |
|-------------|---------|
| Settings window opens via App menu | When people choose Settings item in App menu, the custom settings window opens. |
| Keyboard shortcut | **Cmd+Comma (,)** opens settings. |
| Toolbar with pane buttons | Settings window typically contains a toolbar with buttons for switching between panes (groups of related settings). |
| Include Settings in App menu | Avoid adding settings buttons to a window's toolbar -- it decreases space for essential commands. |
| Dim minimize/maximize buttons | Settings window's minimize and maximize buttons should be dimmed. Quick to open via Cmd+Comma. |
| Noncustomizable toolbar | Toolbar remains visible, always indicates the active toolbar button. |
| Update window title | Title reflects the currently visible pane. If no multiple panes, use "App Name Settings". |
| Restore last pane | Re-open to the most recently viewed pane. |

### Do's and Don'ts

- **DO:** Include a settings item in the App menu.
- **DO:** Support Cmd+Comma keyboard shortcut.
- **DO:** Restore the most recently viewed pane on re-open.
- **DON'T:** Add settings buttons to a window's toolbar.
- **DON'T:** Use settings to ask for setup information obtainable in other ways.
- **DON'T:** Include custom versions of global/systemwide settings.

### watchOS Note

- watchOS apps don't add custom settings to the system Settings app. Make essential options available at the bottom of the main view or via a More menu.

### Developer References

- `Settings` (SwiftUI), `UserDefaults` (Foundation), Preference Panes

---

## 2. Toggles

**Source:** https://developer.apple.com/design/human-interface-guidelines/toggles

### Overview

A toggle lets people choose between a pair of opposing states (on/off) using a different appearance for each state. Styles include switch and checkbox.

### Best Practices

| Guideline | Details |
|-----------|---------|
| Use for opposing values | Use a toggle for two opposing values that affect the state of content or a view. |
| Clearly identify the setting | The surrounding context should provide enough info. In macOS, you can supply a label describing the state. |
| Make state visually obvious | Add/remove color fill, show/hide background shape, change inner details (checkmark, dot) to show on/off. |
| Don't rely solely on color | Not everyone can perceive color differences for state. |

### iOS/iPadOS-Specific

| Requirement | Details |
|-------------|---------|
| Switch toggle only in list rows | Use the switch toggle style only in a list row. Content in the row provides context. |
| Default switch color is green | Only change if necessary. May use app accent color with enough contrast. |
| Outside lists, use toggle button | Use a button that behaves like a toggle (not a switch). Add blue highlight to indicate active state. |
| No label for toggle buttons | The interface icon + alternative background appearances communicate purpose. |

### macOS-Specific

| Component | Usage |
|-----------|-------|
| **Switches** | Prefer for settings you want to emphasize. More visual weight than checkbox. Use for groups of settings. |
| **Mini switches** | In grouped forms, control setting in a single row. Height similar to buttons/other controls. |
| **Checkboxes** | Small square button: empty (off), checkmark (on), dash (mixed). Typically includes trailing-side title. |
| **Radio buttons** | Small circular button followed by label. Groups of 2-5 for mutually exclusive choices. |

### macOS Checkbox States

| State | Appearance |
|-------|-----------|
| On | Contains a checkmark |
| Off | Empty square |
| Mixed | Contains a dash (subordinate checkboxes have different states) |

### macOS Radio Button States

| State | Appearance |
|-------|-----------|
| Selected | Filled circle |
| Deselected | Empty circle |

### macOS Guidelines

- Use switches, checkboxes, and radio buttons **in the window body**, not the window frame (no toolbar/status bar).
- Use checkboxes for hierarchies of settings (alignment and indentation show dependencies).
- Use radio buttons for more than two mutually exclusive options (prefer not more than ~5).
- Consider a label to introduce a group of checkboxes if their relationship is not clear.
- Use consistent spacing for horizontal radio buttons: measure space for longest label, apply consistently.
- Don't replace a checkbox with a switch in existing UI.

### Do's and Don'ts

- **DO:** Make visual differences in toggle state obvious.
- **DO:** Use switch for emphasized settings in macOS.
- **DO:** Use checkboxes for setting hierarchies in macOS.
- **DON'T:** Rely solely on color differences for state.
- **DON'T:** Use switch toggle outside of list rows in iOS/iPadOS.
- **DON'T:** List too many radio buttons (more than ~5); use pop-up button instead.

### Developer References

- `Toggle` (SwiftUI), `UISwitch` (UIKit), `NSButton.ButtonType.toggle` (AppKit), `NSSwitch` (AppKit)

---

## 3. Text Fields

**Source:** https://developer.apple.com/design/human-interface-guidelines/text-fields

### Overview

A text field is a rectangular area for entering or editing small, specific pieces of text.

### Best Practices

| Guideline | Details |
|-----------|---------|
| Use for small amounts of info | Name, email address, etc. For larger text, use a text view. |
| Show placeholder text hint | Placeholder text like "Email" or "Password" helps communicate purpose. Disappears when typing. |
| Include separate label too | Because placeholder disappears, include a separate label describing the field. |
| Use secure text fields | Always use SecureField for sensitive data (passwords). |
| Match field size to expected input | Size helps people gauge the amount of information to provide. |
| Space multiple fields evenly | Leave enough space between fields. Stack vertically when possible. Use consistent widths. |
| Logical tab order | Tab focus should move in a logical sequence between fields. |
| Validate when appropriate | Email: validate on field switch. Username/password: validate before switching fields. |
| Use number formatter | Automatically accept only numeric values. Can display as percentage, currency, etc. |

### Formatted Text

| Option | Description |
|--------|-------------|
| Clipped text | Default. Text extending beyond bounds is clipped. |
| Wrapped text | Wrap to new line at character or word level. |
| Truncated text | Ellipsis at beginning, middle, or end. |

- Consider expansion tooltip to show full version of clipped/truncated text (shows on pointer hover).

### iOS/iPadOS-Specific

| Feature | Details |
|---------|---------|
| Clear button | Display in trailing end to help erase input (tap to clear). |
| Images and buttons | Use leading end to indicate field purpose, trailing end for features (e.g., Bookmarks). |
| Keyboard type | Show appropriate keyboard type for content (numbers, URLs, etc.). |

### macOS-Specific

- Consider using a **combo box** if you need to pair text input with a list of choices.

### watchOS-Specific

- Present a text field only when necessary; prefer displaying a list of options.

### Do's and Don'ts

- **DO:** Show hints via placeholder text.
- **DO:** Use secure text fields for passwords.
- **DO:** Match field size to anticipated text quantity.
- **DO:** Validate fields when it makes sense.
- **DON'T:** Require excessive text entry in tvOS/watchOS apps.
- **DON'T:** Forget separate labels alongside placeholders.

### Developer References

- `TextField` (SwiftUI), `SecureField` (SwiftUI), `UITextField` (UIKit), `NSTextField` (AppKit)

---

## 4. Buttons

**Source:** https://developer.apple.com/design/human-interface-guidelines/buttons

### Overview

A button initiates an instantaneous action. It combines three attributes: Style, Content (symbol/icon/label), and Role.

### Sizing and Hit Targets

| Platform | Minimum Hit Region |
|----------|--------------------|
| iOS, iPadOS, macOS, tvOS, watchOS | **44 x 44 pt** |
| visionOS | **60 x 60 pt** |

### visionOS Button Sizes

| Shape | Mini | Small | Regular | Large | Extra Large |
|-------|------|-------|---------|-------|-------------|
| Circular | 28 pt | 32 pt | 44 pt | 52 pt | 64 pt |
| Capsule (text only) | 28 pt | 32 pt | 44 pt | 52 pt | 64 pt |
| Capsule (text+icon) | 28 pt | 32 pt | 44 pt | 52 pt | 64 pt |
| Rounded rectangle | 28 pt | 32 pt | 44 pt | 52 pt | 64 pt |

### visionOS Button Spacing

- Button centers should be at least **60 pt apart**.
- If buttons measure 60 pt or larger, add **4 pt padding** around them to prevent hover effect overlap.
- Avoid displaying small/mini buttons in vertical stacks or horizontal rows.

### Button Styles

| Style | Usage |
|-------|-------|
| Prominent (accent color background) | Most likely action in a view. Limit to 1-2 per view. |
| Less prominent | Remaining/secondary options. |

- Use style (not size) to distinguish the preferred choice among multiple options.
- Use same-size buttons for coherent choice sets.

### Button Roles

| Role | Meaning | Appearance |
|------|---------|------------|
| Normal | No specific meaning | Default |
| Primary | Default button, most likely choice | Uses app accent color |
| Cancel | Cancels current action | Default |
| Destructive | Can result in data destruction | Uses system red color |

- Assign primary role to the most likely nondestructive action.
- Primary button responds to Return key.
- **Never assign primary role to a destructive action** (people choose primary buttons without reading first).

### Button Content

- Ensure each button clearly communicates its purpose (symbol, text label, or both).
- macOS/visionOS: system displays tooltip on hover.
- Use familiar icons for familiar actions (e.g., `square.and.arrow.up` for share).
- Title-style capitalization for text labels; start with a verb (e.g., "Add to Cart").

### iOS/iPadOS-Specific

- Configure activity indicator for actions that don't instantly complete (e.g., "Checkout" -> "Checking out...").

### macOS-Specific Button Types

| Type | Description |
|------|-------------|
| **Push buttons** | Standard macOS button. Text, symbol, icon, image, or combination. Can be default button. |
| **Flexible-height push buttons** | For tall or variable-height content. Same corner radius and content padding as regular. Use `NSButton.BezelStyle.flexiblePush`. |
| **Square buttons** (gradient buttons) | Actions related to a view (add/remove rows). Symbols/icons only, no text. Appear near their associated view. |
| **Help buttons** | Circular with question mark. Opens app-specific help docs. |
| **Image buttons** | Displays image, symbol, or icon. Behave like push/toggle/pop-up. |

### macOS Push Button Guidelines

- Append **trailing ellipsis** to title when button opens another window/view/app.
- Consider supporting **spring loading** (Magic Trackpad: drag items over, force click to activate).

### macOS Square Button Guidelines

- Use in a view, NOT in the window frame (no toolbars/status bars).
- Prefer SF Symbols in square buttons.
- Avoid labels to introduce square buttons.

### macOS Help Button Placement

| View Style | Position |
|------------|----------|
| Dialog with dismissal buttons | Lower corner, opposite to dismissal buttons, vertically aligned |
| Dialog without dismissal buttons | Lower-left or lower-right corner |
| Settings window or pane | Lower-left or lower-right corner |

- No more than one help button per window.
- Use in a view, not in the window frame.

### macOS Image Button Guidelines

- Include about **10 pixels of padding** between image edges and button edges.
- Avoid system-provided border in image buttons.
- If label needed, position it below the image button.

### visionOS-Specific

- Three standard shapes: circle (icon-only), roundedRectangle/capsule (text-only), capsule (icon+text).
- Four interaction states: Idle, Hover, Selected, Unavailable.
- Buttons don't support custom hover effects.
- Prefer buttons with discernible background shape and fill.
- On glass window: use thin material as background.
- Floating in space: use glass material as background.
- Do NOT use white background fill with black text/icons (reserved for toggled state).
- Prefer circular or capsule-shape buttons (corners draw eyes away from center).
- Rounded-rectangle for vertical stacks; capsule for horizontal rows.

### watchOS-Specific

- Inline buttons use capsule shape with material effect contrasting the background.
- Use toolbar for corner buttons (system applies Liquid Glass appearance).
- Prefer full-width buttons for primary actions.
- Use same height for buttons sharing horizontal space.

### Do's and Don'ts

- **DO:** Include enough space around buttons (44x44 pt minimum hit region, 60x60 pt visionOS).
- **DO:** Always include a press state for custom buttons.
- **DO:** Use prominent style for the most likely action (limit 1-2 per view).
- **DO:** Use style, not size, to distinguish preferred option.
- **DON'T:** Assign primary role to destructive actions.
- **DON'T:** Use square buttons in toolbars/status bars (macOS).
- **DON'T:** Create custom white-background buttons in visionOS.

### Developer References

- `Button` (SwiftUI), `UIButton` (UIKit), `NSButton` (AppKit)

---

## 5. Windows

**Source:** https://developer.apple.com/design/human-interface-guidelines/windows

### Overview

A window presents UI views and components. In iPadOS, macOS, and visionOS, windows define visual boundaries of app content, enable multitasking, and include system-provided interface elements (frames, controls for open/close/resize/relocate).

### Window Types

| Type | Description |
|------|-------------|
| Primary window | Main navigation and content of an app, and associated actions. |
| Auxiliary window | Specific task or area. No navigation to other app areas. Typically includes close button. |

### Best Practices

- Windows must adapt fluidly to different sizes for multitasking/multiwindow workflows.
- Choose the right moment to open a new window (avoid excessive new windows as default).
- Consider providing option to view content in a new window (context menu, File menu).
- Avoid creating custom window UI; use system-provided frames and controls.
- Use the term "window" in user-facing content (not "scene").

### macOS Window Anatomy

| Element | Description |
|---------|-------------|
| Frame | Appears above the body area. Contains window controls and toolbar. Draggable to move. |
| Body area | Main content area. |
| Bottom bar | Rare. Part of frame, appears below body content. |
| Edges | Draggable to resize. |

### macOS Window States

| State | Description | Appearance |
|-------|-------------|------------|
| Main | Frontmost window. One per app. | Title bar options use color (if also key) |
| Key (Active) | Accepts input. One onscreen at a time. Usually the main window. | Title bar close/minimize/zoom use color |
| Inactive | Not in foreground. | Gray title bar options, no vibrancy, subdued |

- Some windows (panels like Colors, Fonts) become key only when people click the title bar or a component requiring keyboard input.
- Custom windows must use system-defined appearances for each state.

### macOS Guidelines

- Avoid critical info/actions in bottom bar (often hidden when window is relocated).
- Bottom bar (status bar): small amount of info about window contents or selected item.
- If more info needed, use an inspector (typically on trailing side of split view).

### iPadOS Window Modes

| Mode | Description |
|------|-------------|
| Full screen | Windows fill entire screen; switch via app switcher. |
| Windowed | Freely resize, multiple windows onscreen, system remembers size/placement. |

- Make sure window controls don't overlap toolbar items.
- Consider pinch gesture to open content in a new window.

### visionOS Window Styles

| Style | Description |
|-------|-------------|
| Default (window) | Upright plane with glass background, close button, window bar, resize controls. |
| Volumetric (volume) | 2D/3D content viewable from any angle. Close button and window bar face viewer. |
| Plain | Like default, but no glass background. |

### visionOS Window Dimensions

| Property | Default Value |
|----------|---------------|
| Default window size | **1280 x 720 pt** |
| Default placement distance | **~2 meters** in front of wearer |
| Apparent width at default distance | **~3 meters** |

### visionOS Window Guidelines

- Retain the glass background (removing makes UI less legible, opaque feels constricting).
- Choose initial size to minimize empty areas.
- Aim for initial shape that suits content (wide for slides, tall for webpages).
- Set minimum and maximum sizes for each window.
- Minimize depth of 3D content in windows (system clips content extending too far).
- For greater 3D depth, use a volume.

### visionOS Volume Guidelines

- Use for rich 3D content viewable from any angle.
- Dynamic scaling: content remains legible regardless of distance (default for windows).
- Fixed scaling: for real-world object representation (default for volumes).
- Baseplate glow shows volume edges when people look at it.
- Consider ornament for high-value content (one per volume, avoid same edge as toolbar/tab bar).
- Choose alignment: parallel to floor (less interaction) or tilt to viewer (active interaction).

### Do's and Don'ts

- **DO:** Adapt windows fluidly to different sizes.
- **DO:** Use system-provided window frames and controls.
- **DO:** Set minimum/maximum window sizes in visionOS.
- **DO:** Retain glass background in visionOS windows.
- **DON'T:** Create custom window UI/frames.
- **DON'T:** Open new windows excessively as default behavior.
- **DON'T:** Put critical info in a bottom bar (macOS).
- **DON'T:** Use opaque backgrounds in visionOS windows.

### Developer References

- `Windows` (SwiftUI), `WindowGroup` (SwiftUI), `UIWindow` (UIKit), `NSWindow` (AppKit)

---

## 6. Labels

**Source:** https://developer.apple.com/design/human-interface-guidelines/labels

### Overview

A label is a static piece of text that people can read and often copy, but not edit. Labels display text throughout the interface in buttons, menu items, and views.

### Label Types

| Context | Usage |
|---------|-------|
| Within a button | Conveys what the button does (Edit, Cancel, Send) |
| Within lists | Describes each item, often with symbol/image |
| Within a view | Provides additional context, introduces controls, describes actions |

### Best Practices

| Guideline | Details |
|-----------|---------|
| Use for small uneditable text | For editable text, use text field. For large text, use text view. |
| Prefer system fonts | Supports Dynamic Type by default. Custom fonts must remain legible. |
| Use system label colors | Four colors for different visual importance levels. |
| Make useful text selectable | Error messages, locations, IP addresses -- let people copy/paste. |

### System Label Colors

| Color | Example Usage | iOS/iPadOS/tvOS/visionOS API | macOS API |
|-------|--------------|------------------------------|-----------|
| Label | Primary information | `label` | `labelColor` |
| Secondary label | Subheading, supplemental text | `secondaryLabel` | `secondaryLabelColor` |
| Tertiary label | Unavailable item/behavior text | `tertiaryLabel` | `tertiaryLabelColor` |
| Quaternary label | Watermark text | `quaternaryLabel` | `quaternaryLabelColor` |

### macOS-Specific

- Use the `isEditable` property of `NSTextField` to display uneditable text in a label.

### watchOS-Specific

- Date/time text components: display current date, time, or both. Configurable format, calendar, timezone.
- Countdown timer text components: display countdown/count-up timer with various formats.
- System automatically adjusts presentation to fit available space and updates content.
- Consider date and timer components in complications.

### Do's and Don'ts

- **DO:** Prefer system fonts for Dynamic Type support.
- **DO:** Use the four system label colors for importance hierarchy.
- **DO:** Make useful label text selectable for copy/paste.
- **DON'T:** Use labels for text people need to edit (use text field instead).

### Developer References

- `Label` (SwiftUI), `Text` (SwiftUI), `UILabel` (UIKit), `NSTextField` (AppKit)

---

## 7. The Menu Bar

**Source:** https://developer.apple.com/design/human-interface-guidelines/the-menu-bar

### Overview

On Mac or iPad, the menu bar at the top of the screen displays top-level menus. Mac users rely on it to learn what an app does and find commands.

### Menu Bar Order (Standard)

| Position | Menu |
|----------|------|
| 1 | YourAppName (App menu) |
| 2 | File |
| 3 | Edit |
| 4 | Format |
| 5 | View |
| 6 | App-specific menus |
| 7 | Window |
| 8 | Help |

macOS also includes: Apple menu (leading side), menu bar extras (trailing side).

### Best Practices

| Guideline | Details |
|-----------|---------|
| Support default system menus and ordering | People expect familiar order. System implements standard menu item functionality. |
| Always show same set of menu items | Disable unavailable items instead of hiding them. |
| Use familiar icons | Same icons as system for Copy, Share, Delete, etc. |
| Support standard keyboard shortcuts | Copy, Cut, Paste, Save, Print, etc. |
| Short one-word menu titles | Takes little space, easy to scan. Title-style capitalization for multi-word. |

### App Menu Items (in order)

| Menu Item | Action | Guidance |
|-----------|--------|----------|
| About YourAppName | Displays About window | Prefer short name <=16 characters. No version number. |
| Settings... | Opens settings window / iPadOS Settings page | Use only for app-level settings. Document settings go in File menu. |
| Optional app-specific items | Custom app-level actions | List after Settings in same group. |
| Services (macOS only) | Submenu of services from system/other apps | |
| Hide YourAppName (macOS only) | Hides app and all windows | Use same short app name as About. |
| Hide Others (macOS only) | Hides all other open apps | |
| Show All (macOS only) | Shows all other open apps behind yours | |
| Quit YourAppName | Quits app. Option key: Quit and Keep Windows. | Use same short app name as About. |

### File Menu Items (in order)

| Menu Item | Action | Guidance |
|-----------|--------|----------|
| New Item | Creates new document/file/window | Use term naming the type (Event, Calendar). |
| Open | Opens selected item or presents selection interface | Ellipsis if separate interface needed. |
| Open Recent | Submenu listing recently opened docs | List in order last opened. Don't show file paths. |
| Close | Closes current window/doc. Option: Close All. | Tab window: Close Tab replaces Close. |
| Save | Saves current document | Auto-save periodically. Prompt for name/location for new docs. |
| Duplicate | Duplicates current document | Prefer over Save As, Export, Copy To. |
| Rename... | Change document name | |
| Move To... | Choose new location | |
| Export As... | Export in different format | Reserve for formats app doesn't typically handle. |
| Revert To | Submenu of recent versions | With autosaving enabled. |
| Page Setup... | Printing parameters (paper size, orientation) | For document-specific params only. |
| Print... | Standard Print panel | |

### Edit Menu Items (in order)

| Menu Item | Action | Guidance |
|-----------|--------|----------|
| Undo | Reverses previous operation | Clarify target: "Undo Paste and Match Style", "Undo Typing" |
| Redo | Reverses Undo | Clarify target similarly. |
| Cut | Remove selection, store on Clipboard | |
| Copy | Duplicate selection to Clipboard | |
| Paste | Insert Clipboard contents | Clipboard unchanged, can paste multiple times. |
| Paste and Match Style | Insert matching surrounding text style | |
| Delete | Remove selected data (not to Clipboard) | Use "Delete", not "Erase" or "Clear". |
| Select All | Select all content | |
| Find | Submenu: Find, Find and Replace, Find Next, Find Previous, etc. | |
| Spelling and Grammar | Submenu for checking/correcting | |
| Substitutions | Submenu for auto-substitutions while typing | |
| Transformations | Submenu: Make Uppercase, Lowercase, Capitalize | |
| Speech | Submenu: Start/Stop Speaking | |
| Start Dictation | Opens dictation window | System adds automatically. |
| Emoji & Symbols | Character Viewer | System adds automatically. |

### View Menu Items (in order)

| Menu Item | Action |
|-----------|--------|
| Show/Hide Tab Bar | Toggle tab bar visibility |
| Show All Tabs/Exit Tab Overview | Enter/exit tab overview |
| Show/Hide Toolbar | Toggle toolbar visibility |
| Customize Toolbar | Open toolbar customization |
| Show/Hide Sidebar | Toggle sidebar visibility |
| Enter/Exit Full Screen | Full-screen mode |

- Ensure show/hide titles reflect current state.
- Provide View menu even if app only supports subset of standard view functions.

### Window Menu Items (in order)

| Menu Item | Action | Guidance |
|-----------|--------|----------|
| Minimize | Minimize to Dock. Option: Minimize All. | |
| Zoom | Toggle between predefined/user size. Option: Zoom All. | Don't use for full-screen mode. |
| Show Previous Tab | Previous tab | Tab-based window. |
| Show Next Tab | Next tab | Tab-based window. |
| Move Tab to New Window | Opens tab in new window | |
| Merge All Windows | Combines into single tabbed window | |
| Enter/Exit Full Screen | Full-screen mode | Only if no View menu. |
| Bring All to Front | Brings all windows forward. Option: Arrange in Front. | |
| Open window names | Brings selected window to front | List alphabetically. |

### Help Menu

| Menu Item | Action | Guidance |
|-----------|--------|----------|
| Send YourAppName Feedback to Apple | Opens Feedback Assistant | |
| YourAppName Help | Opens Help Viewer (Help Book format) | |
| Additional items | Separated from primary help | Keep total items small. |

### Dynamic Menu Items

- Items that change behavior with modifier key (Control, Option, Shift, Command).
- Example: Minimize changes to Minimize All with Option key.
- Don't make dynamic items the only way to accomplish a task.
- Use primarily in menu bar menus (not contextual or Dock menus).
- Require only a single modifier key.
- macOS automatically sets menu width to hold widest item including dynamic items.

### Menu Bar Height (macOS)

| Property | Value |
|----------|-------|
| Menu bar height | **24 pt** |

### Menu Bar Extras (macOS)

- Icon in menu bar for app-specific functionality, visible even when app isn't frontmost.
- Use a symbol (SF Symbols) to represent your menu bar extra.
- Display a menu (not a popover) when clicked.
- Let people decide whether to show it (via settings).
- System hides menu bar extras to make room for app menus.
- Also provide functionality via Dock menu as fallback.

### iPadOS vs macOS Differences

| Feature | iPadOS | macOS |
|---------|--------|-------|
| Menu bar visibility | Hidden until revealed | Visible by default |
| Horizontal alignment | Centered | Leading side |
| Menu bar extras | Not available | System default and custom |
| Window controls | In menu bar when full screen | Never in menu bar |
| Apple menu | Not available | Always available |
| App menu | About, Services, visibility items not available | Always available |

### Do's and Don'ts

- **DO:** Support default system-defined menus and ordering.
- **DO:** Always show the same set of menu items (disable instead of hide).
- **DO:** Support standard keyboard shortcuts.
- **DO:** Use short, one-word menu titles.
- **DON'T:** Make dynamic menu items the only way to accomplish a task.
- **DON'T:** Require more than one modifier key for dynamic items.
- **DON'T:** Use the menu bar as a catch-all for misfit functionality (iPadOS).

### Developer References

- `CommandMenu` (SwiftUI), Adding menus and shortcuts (UIKit), `NSStatusBar` (AppKit)

---

## 8. Onboarding

**Source:** https://developer.apple.com/design/human-interface-guidelines/onboarding

### Overview

Onboarding helps people get a quick start using your app. Ideally, people understand your app simply by experiencing it, but if onboarding is necessary, design a flow that's fast, fun, and optional.

### Best Practices

| Guideline | Details |
|-----------|---------|
| Teach through interactivity | People grasp info better by performing tasks vs. viewing instructional material. |
| Context-specific tips | Use TipKit for contextually relevant tips integrated into the experience. |
| Brief, enjoyable flow | Quick and entertaining = more likely to complete. Don't teach too much. |
| Make tutorials optional | Let people skip. Don't re-present on subsequent launches. Make easy to find later. |
| Focus on your experience | People don't need to learn the system/device in your onboarding. |

### Additional Content

| Guideline | Details |
|-----------|---------|
| Splash screen | If needed, design beautiful graphic. Display just long enough to absorb at a glance. |
| Avoid large download delays | Include enough media in software package. Don't make people wait for downloads. |
| No licensing details in onboarding | Let App Store display agreements. Integrate in balanced way if must include. |

### Additional Requests

| Guideline | Details |
|-----------|---------|
| Postpone nonessential setup | Provide reasonable defaults so people can start immediately. |
| Permission requests | If needed before function, integrate into onboarding to explain why. Otherwise, request when function first accessed. |
| Delay rating/purchase prompts | Let people experience the app first. |

### Do's and Don'ts

- **DO:** Design fast, fun, optional onboarding.
- **DO:** Teach through interactivity.
- **DO:** Use context-specific tips (TipKit).
- **DO:** Let people skip tutorials.
- **DON'T:** Force users to memorize a lot of information.
- **DON'T:** Display licensing/legal details in onboarding flow.
- **DON'T:** Block users with large downloads before they can interact.
- **DON'T:** Prompt for ratings/purchases before users have engaged.

### Developer References

- TipKit (SwiftUI)

---

## 9. Keyboards

**Source:** https://developer.apple.com/design/human-interface-guidelines/keyboards

### Overview

A physical keyboard is an essential input device for text entry, games, and app control. People connect keyboards to all devices except Apple Watch.

### Best Practices

| Guideline | Details |
|-----------|---------|
| Support Full Keyboard Access | Let people navigate and activate windows, menus, controls, and system features using only keyboard. |
| Respect standard keyboard shortcuts | Don't repurpose standard shortcuts for custom actions. |

### Modifier Keys (in display order)

| Modifier | Symbol | Recommended Usage |
|----------|--------|-------------------|
| Control | ^ | Avoid as modifier (system uses for many features). |
| Option | - | Use sparingly for less-common commands. |
| Shift | - | Prefer as secondary modifier complementing related shortcut. |
| Command | - | Prefer as main modifier key. |

**Always list modifier keys in this order: Control, Option, Shift, Command.**

### Standard Keyboard Shortcuts (Key Subset for macOS Apps)

| Shortcut | Action |
|----------|--------|
| **Cmd+,** | Open app settings window |
| **Cmd+Q** | Quit the app |
| **Cmd+W** | Close the active window |
| **Cmd+N** | Open a new document |
| **Cmd+O** | Open document dialog |
| **Cmd+S** | Save document |
| **Cmd+Shift+S** | Duplicate / Save As |
| **Cmd+P** | Print dialog |
| **Cmd+Z** | Undo |
| **Cmd+Shift+Z** | Redo |
| **Cmd+X** | Cut |
| **Cmd+C** | Copy |
| **Cmd+V** | Paste |
| **Cmd+A** | Select all |
| **Cmd+F** | Open Find window |
| **Cmd+G** | Find next occurrence |
| **Cmd+Shift+G** | Find previous occurrence |
| **Cmd+H** | Hide current app |
| **Cmd+Option+H** | Hide all other apps |
| **Cmd+M** | Minimize active window to Dock |
| **Cmd+Option+M** | Minimize all windows |
| **Cmd+B** | Bold |
| **Cmd+I** | Italic |
| **Cmd+U** | Underline |
| **Cmd+T** | Show Fonts window |
| **Cmd+Tab** | Move to next most recently used app |
| **Cmd+`** | Activate next open window in frontmost app |
| **Cmd+?** | Open Help menu |
| **F11** | Show desktop |
| **Cmd+Space** | Show/hide Spotlight |
| **Cmd+F5** | Toggle VoiceOver |
| **Ctrl+F2** | Move focus to menu bar |
| **Ctrl+F3** | Move focus to Dock |

### Custom Keyboard Shortcuts

| Guideline | Details |
|-----------|---------|
| Define only for frequent actions | Too many shortcuts = difficult to learn. |
| Command as main modifier | Use Command as the primary modifier key. |
| Avoid adding Shift to upper-character keys | Command-Question mark, not Shift-Command-Slash. |
| Let system localize/mirror shortcuts | System handles for connected keyboard and RTL layouts. |
| Don't add modifier to create unrelated shortcut | Command-Z is undo; Shift-Command-Z should only be redo, not unrelated. |

### iPadOS Focus Behavior

- Avoid supporting keyboard navigation for controls (buttons, segmented controls, switches).
- Let people use Full Keyboard Access for controls.
- iPadOS supports keyboard navigation in text fields, text views, sidebars, and collection views.

### visionOS

- Keyboard shortcuts appear in shortcut interface when holding Command key.
- Write descriptive shortcut titles (no submenu titles for context).

### Do's and Don'ts

- **DO:** Support Full Keyboard Access.
- **DO:** Respect standard keyboard shortcuts.
- **DO:** Use Command as the main modifier key.
- **DO:** List modifiers in order: Control, Option, Shift, Command.
- **DON'T:** Repurpose standard shortcuts for custom actions.
- **DON'T:** Use Control as a modifier in custom shortcuts (system reserves it).
- **DON'T:** Create too many custom keyboard shortcuts.
- **DON'T:** Require more than one modifier key to type certain characters.

### Developer References

- `KeyboardShortcut` (SwiftUI), Input events (SwiftUI), Handling key presses (UIKit), Mouse/Keyboard/Trackpad (AppKit)

---

## 10. Notifications

**Source:** https://developer.apple.com/design/human-interface-guidelines/notifications

### Overview

A notification gives people timely, high-value information they can understand at a glance. Requires user consent before sending.

### Notification Styles

| Style | Description |
|-------|-------------|
| Banner/view | Lock Screen, Home Screen, Home View, desktop |
| Badge | Number on app icon |
| Notification Center item | Listed in Notification Center |
| Communication notification | Distinct interface with contact images/avatars, group names |

### Best Practices

| Guideline | Details |
|-----------|---------|
| Concise, informative | Provide valuable info succinctly. |
| Don't send multiple for same thing | Even if someone hasn't responded. Fills up Notification Center. |
| Don't tell people to perform tasks in app | Hard to remember instructions after dismissing. |
| Use alerts for errors, not notifications | Don't cause confusion by using wrong component. |
| Handle gracefully when foreground | Don't send notification if app is in front. Increment badge or insert data subtly. |
| Avoid sensitive/personal info | Can be visible to others. |

### Content

| Element | Guideline |
|---------|-----------|
| Title | Short, title-style capitalization, no ending punctuation. Use for headline, event name, email subject. |
| Body | Complete sentences, sentence case, proper punctuation. Don't truncate (system does automatically). |
| Hidden preview text | Generically descriptive: "Friend request", "New comment", "Reminder". Sentence-style capitalization. |
| App name/icon | System displays automatically. Don't include in content. |
| Sound | Short, distinctive, professionally produced. Custom or system alert sound. |

### Notification Actions

- Up to **4 buttons** in customizable detail view.
- Short, title-case term or phrase per button.
- No app name or extraneous info in button labels.
- Don't provide action that merely opens the app.
- Prefer nondestructive actions.
- System gives distinct appearance to destructive actions.
- Provide recognizable interface icon for each action.

### Badging

| Guideline | Details |
|-----------|---------|
| Use only for unread notification count | Don't use for weather, dates, scores, etc. |
| Not the only method for essential info | People can turn off badging. |
| Keep badges up to date | Update immediately when notifications are read. Zero removes all from Notification Center. |
| No custom badge mimics | Don't create custom images that look like badges. |

### watchOS-Specific

| Feature | Details |
|---------|---------|
| Short look | Appears when wrist raised, disappears when lowered. Brief, discreet. |
| Long look | More detail. Scrollable. Can be static or dynamic. Custom content area. |
| Sash | System-defined at top of long look. Customizable color or blurred appearance. |
| Background color | Default transparent. White 18% opacity to match system. Or custom/brand color. |
| Custom actions | Up to **4 custom action buttons** below content area. Plus system Dismiss button. |
| Double tap | Runs first nondestructive action. Place most common action first. |

### Do's and Don'ts

- **DO:** Provide concise, high-value notifications.
- **DO:** Provide up to 4 action buttons with clear labels.
- **DO:** Keep badges up to date.
- **DO:** Provide sounds (short, distinctive, professional).
- **DON'T:** Send multiple notifications for the same thing.
- **DON'T:** Include sensitive personal info.
- **DON'T:** Use notifications to tell people to perform tasks in app.
- **DON'T:** Use notifications for error messages (use alerts).
- **DON'T:** Use badges for non-notification numeric info.

### Developer References

- User Notifications, User Notifications UI, `UNNotificationSound`

---

## 11. Focus and Selection

**Source:** https://developer.apple.com/design/human-interface-guidelines/focus-and-selection

### Overview

Focus helps people visually confirm the object their interaction targets. Focus supports component-based navigation using remotes, game controllers, or keyboards.

### Focus Communication by Platform

| Platform | Focus Indication |
|----------|-----------------|
| iPadOS | Ring around item or highlight |
| macOS | Ring around item or highlight |
| tvOS | Parallax effect (depth, liveliness) |
| visionOS | Hover effect (eyes), focus system for keyboard/controller |

### Best Practices

| Guideline | Details |
|-----------|---------|
| Rely on system-provided focus effects | Precisely tuned for Apple devices. Consistent and predictable. |
| Don't change focus without interaction | People rely on focus to know where they are. Exception: previously focused item disappears during discrete directional movement. |
| Be consistent with platform | iPadOS/macOS: focus only for content elements (list items, text fields, search fields). tvOS: every onscreen element. |
| Use focus ring for text/search fields | Use highlight in lists/collections (entire row highlighted). |

### iPadOS Focus System

| Interaction | Behavior |
|-------------|----------|
| Tab key | Moves focus among focus groups (sidebars, grids, lists) |
| Arrow keys | Directional focus within the same focus group |

### iPadOS Focus Effects

| Effect | Description |
|--------|-------------|
| Halo (focus ring) | Customizable outline around component. For custom views and opaque content in cells. |
| Highlighted appearance | Component text uses app accent color. For collection view cells with content configurations. |

- Customize halo when necessary (shape, position, rounded corners, Bezier paths).
- Ensure focus moves through custom views in reading order (leading to trailing, top to bottom).
- Adjust priority to reflect importance within a focus group. Primary item gets focus when group receives focus.

### tvOS Focus States

| State | Description |
|-------|-------------|
| Unfocused | Default. Less prominent appearance. |
| Focused | Stands out via elevation, illumination, animation. |
| Pressed | Instant visual feedback when chosen (e.g., brief color invert). |
| Selected | Chosen/activated (e.g., filled heart icon for favorite). |
| Unavailable | Can't receive focus or be chosen. Inactive appearance. |

### tvOS Guidelines

- In full-screen, let people use gestures for content, not focus.
- Avoid displaying a pointer (use focus model for menus/UI).
- Design for components in various focus states (supply assets for larger focused size).

### macOS-Specific

- Use focus ring for text/search fields.
- Use highlight in lists/collections.

### Do's and Don'ts

- **DO:** Rely on system-provided focus effects.
- **DO:** Support Tab key navigation among focus groups (iPadOS).
- **DO:** Support arrow key navigation within focus groups.
- **DO:** Supply assets for focused (larger) size in tvOS.
- **DON'T:** Change focus without user interaction.
- **DON'T:** Display a pointer in tvOS (use focus model).
- **DON'T:** Create custom focus effects unless absolutely necessary.

### Developer References

- Focus Attributes (TVML), Focus-based navigation (UIKit), `UIFocusHaloEffect`

---

## 12. Menus

**Source:** https://developer.apple.com/design/human-interface-guidelines/menus

### Overview

A menu reveals options when people interact with it. Space-efficient way to present commands. People expect menus to behave in familiar ways.

### Menu Types

| Type | Description |
|------|-------------|
| Pop-up button menu | Options related to button's action |
| Pull-down button menu | Options related to button's action |
| Context menu | Frequently used actions for current view/task |
| Menu bar menus | All commands in app (macOS, iPadOS) |

### Label Best Practices

| Guideline | Details |
|-----------|---------|
| Verb or verb phrase for actions | "View", "Close", "Select" |
| Title-style capitalization | Capitalize every word except articles, conjunctions, short prepositions |
| Remove articles (a, an, the) | Save space without losing meaning |
| Show unavailable items dimmed | Don't hide them. Menu itself stays available even if all items unavailable. |
| Append ellipsis for more input needed | Signals that people need to provide additional information |

### Icon Best Practices

- Use familiar system icons for Copy, Share, Delete, etc.
- Don't display icon if no clear representation exists.
- Use a single icon to introduce a group of similar items (first item only).

### Organization

| Guideline | Details |
|-----------|---------|
| Important/frequent items first | People scan from top. |
| Group logically related items | Use separators between groups. |
| Keep related commands in same group | Even if different importance levels. |
| Mind menu length | Too long = people miss commands. Consider separate menus or submenus. |
| User-defined content exception | Menus like History, Bookmarks can be long. Scrolling acceptable. |

### Submenus

| Guideline | Details |
|-----------|---------|
| Use sparingly | Each submenu adds complexity and hides items. |
| Consider when term repeats in >2 items | e.g., "Sort by Date/Score/Time" -> "Sort by" submenu with Date, Score, Time. |
| Limit to single level depth | Multiple levels difficult to reveal. |
| Max ~5 items per submenu | More than 5: consider a new menu. |
| Keep submenu available | Even when nested items are unavailable. |
| Prefer submenus over indenting | Indentation is inconsistent with system. |

### Toggled Items

| Approach | When to Use |
|----------|-------------|
| Changeable label | "Show Map" / "Hide Map" based on current state |
| Add verb if unclear | "Turn HDR On" / "Turn HDR Off" instead of "HDR On" / "HDR Off" |
| Show both items | When viewing both actions/states simultaneously helps |
| Checkmark | Show attribute is currently in effect. Easy to scan. |
| Bulk remove item | e.g., "Plain" to remove all formatting at once |

### iOS/iPadOS Menu Layouts

| Layout | Description |
|--------|-------------|
| Small | Row of 4 items at top (symbol/icon only, no label) + list below |
| Medium | Row of 3 items at top (symbol/icon above short label) + list below |
| Large (default) | All items in a list |

- Use medium for 3 important frequent actions (e.g., Scan, Lock, Pin in Notes).
- Use small only for closely related grouped actions (e.g., Bold, Italic, Underline, Strikethrough).
- Use recognizable symbols that identify action without a label.

### visionOS Menu Guidelines

- Can display items using small or large layout styles.
- Present menu near the content it controls.
- Prefer subtle breakthrough effect (blends with surrounding content).
- Prominent: displays prominently over entire scene (can disrupt experience).
- None: fully occluded behind 3D content (may make menu hard to access).

### In-Game Menus

- Let players navigate using platform's default interaction method.
- Make sure menus remain easy to open and read on all supported platforms.
- Modify tap target sizes and consider alternative ways to communicate content if scaling makes menus too small.

### Do's and Don'ts

- **DO:** Use title-style capitalization for menu items.
- **DO:** Show unavailable items dimmed, not hidden.
- **DO:** Append ellipsis when more input is needed.
- **DO:** Group logically related items with separators.
- **DO:** Put important/frequent items first.
- **DON'T:** Create deeply nested submenus (limit to one level).
- **DON'T:** Have more than ~5 items per submenu.
- **DON'T:** Use indentation instead of submenus.
- **DON'T:** Ignore menu readability on different screen sizes (games).

### Developer References

- `Menu` (SwiftUI), Menus and shortcuts (UIKit), Menus (AppKit)

---

## Cross-Component macOS Quick Reference

### Sizing Summary

| Component | Key Dimension |
|-----------|---------------|
| Button hit region | Min 44 x 44 pt |
| Menu bar height | 24 pt |
| Image button padding | ~10 px between image and button edges |
| visionOS default window | 1280 x 720 pt |
| visionOS button spacing | Centers at least 60 pt apart, 4 pt padding if >=60 pt |

### Common macOS Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+, | Open Settings |
| Cmd+Q | Quit |
| Cmd+W | Close Window |
| Cmd+N | New Document |
| Cmd+O | Open |
| Cmd+S | Save |
| Cmd+Z | Undo |
| Cmd+Shift+Z | Redo |
| Cmd+X / C / V | Cut / Copy / Paste |
| Cmd+A | Select All |
| Cmd+F | Find |
| Cmd+P | Print |
| Cmd+H | Hide App |
| Cmd+M | Minimize |
| Cmd+` | Next Window |
| Cmd+Tab | Next App |

### macOS Window States

| State | Title Bar Controls | Vibrancy |
|-------|-------------------|----------|
| Key (active) | Colored | Yes |
| Main (not key) | Gray | Yes |
| Inactive | Gray | No |

### Settings Window Behavior

| Feature | Requirement |
|---------|-------------|
| Access via | App menu > Settings or Cmd+, |
| Minimize/maximize buttons | Dimmed |
| Toolbar | Noncustomizable, always visible, indicates active button |
| Title | Reflects current pane, or "App Name Settings" if single pane |
| On re-open | Restores most recently viewed pane |

### System Label Color Hierarchy

| Priority | Color | Usage |
|----------|-------|-------|
| 1 (highest) | Label | Primary content |
| 2 | Secondary label | Subheading, supplemental |
| 3 | Tertiary label | Unavailable item text |
| 4 (lowest) | Quaternary label | Watermark text |

### Accessibility Requirements Summary

| Component | Requirement |
|-----------|-------------|
| Buttons | Min 44x44 pt hit region (60x60 pt visionOS). Press state required. |
| Toggles | Don't rely solely on color for state. Visual differences must be obvious. |
| Text fields | Secure fields for sensitive data. Logical tab order. |
| Focus | Support Full Keyboard Access. System-provided focus effects. |
| Labels | System fonts for Dynamic Type. Four-level color hierarchy. |
| Keyboards | Support Full Keyboard Access. Standard shortcuts. |
| Notifications | No sensitive info. Concise content. Sound as supplement (not sole method). |
| Menus | Dimmed unavailable items (not hidden). Keyboard shortcuts. |
