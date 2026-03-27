# Apple HIG Design Reference for macOS Menu Bar App
## Preferences Window & First-Run Wizard

Extracted from Apple Human Interface Guidelines and Apple Developer Documentation (March 2026).
Covers macOS 26 (Tahoe) with Liquid Glass design language.

---

## Table of Contents

1. [Window Design — Preferences/Settings](#1-window-design--preferencessettings)
2. [Liquid Glass / Materials](#2-liquid-glass--materials)
3. [System Colors](#3-system-colors)
4. [Typography & Text Styles](#4-typography--text-styles)
5. [Form Controls](#5-form-controls)
6. [Onboarding / First-Run Wizard](#6-onboarding--first-run-wizard)
7. [Accessibility & Permission Requests](#7-accessibility--permission-requests)
8. [Layout & Spacing Metrics](#8-layout--spacing-metrics)
9. [macOS-Specific Patterns](#9-macos-specific-patterns)

---

## 1. Window Design — Preferences/Settings

### Settings Window Architecture (SwiftUI)

The standard macOS Settings scene:

```swift
@main
struct MyApp: App {
    var body: some Scene {
        // ... main window ...
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
```

SwiftUI automatically:
- Enables the app's Settings menu item (Cmd+,)
- Manages displaying/removing the settings view
- Applies `.scenePadding()` for proper insets

### Tab-Based Settings Layout

```swift
struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                GeneralSettingsView()
            }
            Tab("Advanced", systemImage: "star") {
                AdvancedSettingsView()
            }
        }
        .scenePadding()
        .frame(maxWidth: 350, minHeight: 100)
    }
}
```

### NSWindow Toolbar Styles

| Style | Placement | Use Case |
|-------|-----------|----------|
| `.automatic` | System-determined | Default behavior |
| `.expanded` | Below title | Standard toolbar |
| **`.preference`** | **Below title, centered** | **Settings/Preferences windows** |
| `.unified` | Next to title | Modern compact UI |
| `.unifiedCompact` | Next to title, minimal margins | Content-focused windows |

**For a settings window, always use:**
```swift
window.toolbarStyle = .preference
```

### NSWindow Configuration for Settings

```swift
// Title bar
window.titlebarAppearsTransparent = false  // Keep standard title bar
window.titleVisibility = .visible
window.titlebarSeparatorStyle = .automatic

// Style mask
window.styleMask = [.titled, .closable]  // No .resizable, no .miniaturizable

// Size constraints
window.contentMinSize = NSSize(width: 450, height: 300)
window.contentMaxSize = NSSize(width: 650, height: 500)

// Shadow and appearance
window.hasShadow = true
window.isOpaque = true
```

### NSTabView for AppKit Settings

```swift
let tabView = NSTabView()
tabView.tabViewType = .topTabSet
tabView.tabPosition = .top
tabView.controlSize = .regular
```

---

## 2. Liquid Glass / Materials

### macOS 26 Liquid Glass (New in 2025)

Liquid Glass is Apple's new translucent material design language introduced with macOS 26 (Tahoe).

#### SwiftUI Glass Effect

```swift
// Basic usage — default is .regular style with capsule shape
Text("Hello")
    .padding()
    .glassEffect()

// Configured glass
Text("Hello")
    .padding()
    .glassEffect(
        .regular.tint(.blue).interactive(true),
        in: RoundedRectangle(cornerRadius: 12)
    )
```

#### Glass Variants

| Variant | Description |
|---------|-------------|
| `.regular` | Standard Liquid Glass material (default) |
| `.clear` | Clear/transparent glass variant |
| `.identity` | No effect applied (passthrough) |

#### Glass Configuration Methods

- `.tint(_ color: Color?)` — Apply a tint color to the glass
- `.interactive(_ isInteractive: Bool)` — Enable interactive behavior

#### GlassEffectContainer (Morphing)

Combine multiple glass effects that morph into each other:
```swift
GlassEffectContainer {
    // Views with .glassEffect() modifiers
}
```

#### AppKit: NSGlassEffectView (macOS 26+)

```swift
let glassView = NSGlassEffectView()
glassView.contentView = yourContentView
glassView.style = .regular  // NSGlassEffectView.Style
glassView.cornerRadius = 12.0
glassView.tintColor = NSColor.controlAccentColor
```

**Properties:**
- `contentView: NSView?` — The view to embed in glass
- `style: NSGlassEffectView.Style` — Glass style
- `tintColor: NSColor?` — Tint color for the glass
- `cornerRadius: CGFloat` — Corner rounding

#### NSGlassEffectContainerView (Performance)

Merges nearby glass effect views for better rendering performance:
```swift
let container = NSGlassEffectContainerView()
container.contentView = viewWithMultipleGlassChildren
container.spacing = 8.0  // Proximity threshold for merging
```

#### NSButton Glass Bezel

Buttons now have a `.glass` bezel style for Liquid Glass appearance:
```swift
button.bezelStyle = .glass
```

### NSVisualEffectView Materials (Pre-Liquid Glass)

Still relevant for non-glass translucency:

| Material | Use Case |
|----------|----------|
| `.sidebar` | Window sidebars |
| `.windowBackground` | Opaque window backgrounds |
| `.contentBackground` | Opaque content areas |
| `.headerView` | Inline headers/footers |
| `.sheet` | Sheet backgrounds |
| `.popover` | Popover backgrounds |
| `.menu` | Menu backgrounds |
| `.titlebar` | Window titlebars |
| `.selection` | Selection indication |
| `.toolTip` | Tooltip backgrounds |
| `.hudWindow` | HUD window backgrounds |
| `.fullScreenUI` | Full-screen modal backgrounds |
| `.underWindowBackground` | Under window background |
| `.underPageBackground` | Behind document pages |

**Blending Modes:**
- `.behindWindow` — Uses content behind the window (sheets, popovers)
- `.withinWindow` — Uses window's own content (toolbars, scrolling areas)

#### NSBackgroundExtensionView (macOS 26+)

Extends content to fill bounds (e.g., under titlebar, sidebars):
```swift
let bgExtView = NSBackgroundExtensionView()
bgExtView.contentView = mainContentView
bgExtView.automaticallyPlacesContentView = true  // Respects safe areas
```

---

## 3. System Colors

### Adaptable System Colors (Auto-adapt to Light/Dark/Vibrancy)

| Color Name | Usage |
|------------|-------|
| `systemRed` | Errors, destructive actions |
| `systemOrange` | Warnings, attention |
| `systemYellow` | Caution, highlights |
| `systemGreen` | Success, positive state |
| `systemMint` | Fresh/health related |
| `systemTeal` | Secondary accent |
| `systemCyan` | Info, links |
| `systemBlue` | Primary accent, links, actions |
| `systemIndigo` | Deep accent |
| `systemPurple` | Creative/special |
| `systemPink` | Love/favorites |
| `systemBrown` | Earth/natural |
| `systemGray` | Neutral, disabled |

### Semantic UI Element Colors

#### Label Colors (Text Hierarchy)

| Color | Usage | Relative Contrast |
|-------|-------|-------------------|
| `labelColor` | Primary text | Highest |
| `secondaryLabelColor` | Secondary/subtitle text | High |
| `tertiaryLabelColor` | Placeholder, disabled text | Medium |
| `quaternaryLabelColor` | Watermarks, separators | Low |
| `quinaryLabel` | Subtle decorations | Lowest |

#### Text Colors

| Color | Usage |
|-------|-------|
| `textColor` | General text |
| `placeholderTextColor` | Input placeholder text |
| `selectedTextColor` | Selected text foreground |
| `textBackgroundColor` | Text background |
| `selectedTextBackgroundColor` | Selection highlight |
| `textInsertionPointColor` | Cursor/caret |
| `keyboardFocusIndicatorColor` | Focus ring |
| `unemphasizedSelectedTextColor` | Unfocused selection text |
| `unemphasizedSelectedTextBackgroundColor` | Unfocused selection BG |

#### Control Colors

| Color | Usage |
|-------|-------|
| `controlAccentColor` | System accent color (user-configurable) |
| `controlColor` | Control surface |
| `controlBackgroundColor` | Control background (text fields, lists) |
| `controlTextColor` | Text on controls |
| `disabledControlTextColor` | Disabled control text |
| `selectedControlColor` | Selected control surface |
| `selectedControlTextColor` | Selected control text |

#### Window & Background Colors

| Color | Usage |
|-------|-------|
| `windowBackgroundColor` | Window background |
| `windowFrameTextColor` | Window title text |
| `underPageBackgroundColor` | Behind document pages |

#### Content & Selection Colors

| Color | Usage |
|-------|-------|
| `linkColor` | Hyperlinks |
| `separatorColor` | Visual separators |
| `selectedContentBackgroundColor` | Selected rows/items (focused) |
| `unemphasizedSelectedContentBackgroundColor` | Selected rows (unfocused) |
| `selectedMenuItemTextColor` | Selected menu item text |
| `selectedMenuItemColor` | Selected menu item BG |
| `gridColor` | Table grid lines |
| `headerTextColor` | Table header text |
| `alternatingContentBackgroundColors` | Alternating row backgrounds |
| `findHighlightColor` | Find/search highlight |
| `highlightColor` | General highlight |
| `shadowColor` | Drop shadows |

#### Fill Colors (Overlays)

| Color | Usage | Opacity |
|-------|-------|---------|
| `systemFill` | Primary fill | Highest |
| `secondarySystemFill` | Secondary fill | High |
| `tertiarySystemFill` | Tertiary fill | Medium |
| `quaternarySystemFill` | Quaternary fill | Low |
| `quinarySystemFill` | Quinary fill | Lowest |

### Color Best Practices for Vibrancy

When using vibrancy (NSVisualEffectView or glass effects), use built-in grayscale semantic colors:
- `labelColor` — Highest contrast (primary)
- `secondaryLabelColor` — Secondary contrast
- `tertiaryLabelColor` — Tertiary contrast
- `quaternaryLabelColor` — Lowest contrast

**Do NOT:**
- Mix dramatically different foreground/background hues
- Use non-semantic fixed colors with vibrancy

---

## 4. Typography & Text Styles

### System Font

macOS uses **SF Pro** (San Francisco Pro) as the system font family.
- `SF Pro Display` — For large sizes (20pt+)
- `SF Pro Text` — For smaller body text
- `SF Mono` — Monospaced variant

### macOS Default Font Sizes

| Context | Size (pt) |
|---------|-----------|
| System font (NSFont.systemFontSize) | **13** |
| Small system font (NSFont.smallSystemFontSize) | **11** |
| Label font | **10** |
| Mini control | **9** |
| Small control | **11** |
| Regular control | **13** |
| Large control | **system-determined** |

### NSFont.TextStyle Hierarchy (AppKit)

| Style | Typical Size | Use Case |
|-------|-------------|----------|
| `.largeTitle` | ~26pt | Hero headings, welcome screens |
| `.title1` | ~22pt | First-level headings |
| `.title2` | ~17pt | Second-level headings |
| `.title3` | ~15pt | Third-level headings |
| `.headline` | ~13pt bold | Section headers, emphasis |
| `.subheadline` | ~11pt | Subheadings |
| `.body` | ~13pt | Default body text |
| `.callout` | ~12pt | Callout boxes |
| `.footnote` | ~10pt | Footnotes, minor details |
| `.caption1` | ~10pt | Standard captions |
| `.caption2` | ~10pt | Alternate captions |

*Note: Exact sizes are resolved at runtime and may vary with Dynamic Type settings.*

### SwiftUI Font Styles (Full Catalog)

| Style | Purpose |
|-------|---------|
| `.extraLargeTitle2` | Largest title variant |
| `.extraLargeTitle` | Extra large title |
| `.largeTitle` | Large title |
| `.title` | Primary title |
| `.title2` | Secondary heading |
| `.title3` | Tertiary heading |
| `.headline` | Bold heading |
| `.subheadline` | Subheading |
| `.body` | Default body text |
| `.callout` | Callout text |
| `.footnote` | Footnote text |
| `.caption` | Caption text |
| `.caption2` | Alternate caption |

### Font Design Options

| Design | Description |
|--------|-------------|
| default | Standard SF Pro |
| `.rounded` | Rounded variant |
| `.monospaced` | Fixed-width (SF Mono) |
| `.serif` | Serif variant (New York) |

### Font Retrieval (AppKit)

```swift
// System text style fonts
let bodyFont = NSFont.preferredFont(forTextStyle: .body, options: [:])
let titleFont = NSFont.preferredFont(forTextStyle: .title1, options: [:])

// Specific UI element fonts
let labelFont = NSFont.labelFont(ofSize: NSFont.labelFontSize)
let menuFont = NSFont.menuFont(ofSize: 0)        // 0 = default size
let titleBarFont = NSFont.titleBarFont(ofSize: 0)
let toolTipFont = NSFont.toolTipsFont(ofSize: 0)
let messageFont = NSFont.messageFont(ofSize: 0)   // Buttons, menu items

// Explicit system font
let font = NSFont.systemFont(ofSize: 13, weight: .regular)
```

### Typography Recommendations for Settings Window

| Element | Style | Weight |
|---------|-------|--------|
| Window title | `.title2` or `.title3` | `.semibold` |
| Section header | `.headline` | `.bold` (default) |
| Setting label | `.body` | `.regular` |
| Setting description | `.subheadline` or `.callout` | `.regular` |
| Footnote/help text | `.footnote` | `.regular` |
| Button text | `.body` | `.regular` |
| Status/badge text | `.caption` | `.medium` |

---

## 5. Form Controls

### macOS Form Layout with SwiftUI

On macOS, `Form` renders as a **vertical stack** (not a grouped list like iOS):
- Labels conventionally end with colons (`:`)
- Pickers default to inline/radio button style
- Forms are typically centered with `HStack` + `Spacer`

```swift
Form {
    Picker("Notify Me About:", selection: $notifyMeAbout) {
        Text("Direct Messages").tag(NotifyMeAboutType.directMessages)
        Text("Mentions").tag(NotifyMeAboutType.mentions)
    }
    Toggle("Play notification sounds", isOn: $playNotificationSounds)
    Picker("Profile Image Size:", selection: $profileImageSize) {
        Text("Large").tag(ProfileImageSize.large)
        Text("Small").tag(ProfileImageSize.small)
    }
    .pickerStyle(.inline)
}
```

### NSButton Bezel Styles

| Style | Use Case |
|-------|----------|
| `.automatic` | Default, context-dependent |
| `.push` | Standard push button |
| `.flexiblePush` | Push button with flexible height |
| **`.glass`** | **Liquid Glass effect (macOS 26+)** |
| `.toolbar` | Toolbar items |
| `.accessoryBar` | Accessory toolbar narrowing filters |
| `.accessoryBarAction` | Accessory toolbar actions |
| `.disclosure` | Disclosure triangle |
| `.pushDisclosure` | Push + disclosure triangle |
| `.helpButton` | Round `?` help button |
| `.badge` | Additional info badge |
| `.circular` | Round icon button |
| `.smallSquare` | Simple scalable square |

### NSTextField Patterns

```swift
// Editable input field
let input = NSTextField(string: "")
input.placeholderString = "Enter value..."
input.isBezeled = true          // Standard input appearance
input.bezelStyle = .rounded     // Modern rounded (.rounded or .squareBezel)
input.drawsBackground = true

// Static label
let label = NSTextField(labelWithString: "Username:")

// Multi-line wrapping label
let desc = NSTextField(wrappingLabelWithString: "Long description text here")
```

### NSSwitch (Toggle)

```swift
let toggle = NSSwitch()
toggle.state = .on  // or .off
toggle.target = self
toggle.action = #selector(toggleChanged)
// Binary on/off only. No cell support (unlike legacy NSButton checkboxes).
```

### NSPopUpButton (Dropdown Picker)

```swift
let popup = NSPopUpButton(frame: rect, pullsDown: false)
popup.addItems(withTitles: ["Option 1", "Option 2", "Option 3"])
popup.selectItem(at: 0)
```

### Control Sizes (AppKit)

| Size | Constant | Font Size | Use Case |
|------|----------|-----------|----------|
| Mini | `.mini` | ~9pt | Tight spaces, utility panels |
| Small | `.small` | ~11pt | Secondary controls, toolbars |
| **Regular** | **`.regular`** | **~13pt** | **Default for most controls** |
| Large | `.large` | varies | Prominent actions |
| Extra Large | `.extraLarge` | varies | Hero-level controls |

### Control Sizes (SwiftUI)

```swift
Button("Action")
    .controlSize(.regular)  // .mini, .small, .regular, .large, .extraLarge
```

### GroupBox (Section Grouping)

```swift
GroupBox("Notification Settings") {
    Toggle("Enable notifications", isOn: $notifications)
    Toggle("Play sounds", isOn: $sounds)
}
```

### NSGridView for Form Layout (AppKit)

Best for label-value form pairs:

```swift
let gridView = NSGridView(views: [
    [label1, input1],
    [label2, input2],
    [label3, input3]
])
gridView.columnSpacing = 20   // Space between label and control
gridView.rowSpacing = 10      // Space between form rows
gridView.rowAlignment = .firstBaseline  // Align text baselines
```

### NSBox for Section Grouping (AppKit)

```swift
let box = NSBox()
box.title = "Recording Settings"
box.titlePosition = .atTop
box.contentViewMargins = NSSize(width: 10, height: 10)
box.contentView = sectionContentView
```

---

## 6. Onboarding / First-Run Wizard

### Apple's Onboarding Principles

1. **Keep it minimal** — Show only what users need to get started
2. **Delay sign-in** — Don't force account creation before showing value
3. **Progressive disclosure** — Reveal features as users need them
4. **Request permissions in context** — Ask when the feature is first used, not all at once
5. **Provide value first** — Show what the app does before asking for permissions

### First-Run Wizard Pattern

A wizard/walkthrough should:
- Be **skippable** — Never force users through if possible
- Use **2-5 screens maximum** — Each focused on one concept
- Include **clear progress indication** (dots, step numbers)
- End with a **clear call-to-action** to start using the app

### Recommended Structure for Scribe

```
Screen 1: Welcome
  - App icon + name
  - One-sentence value proposition
  - "Get Started" button

Screen 2: Core Feature Introduction
  - Brief visual/animation of dictation workflow
  - "Next" button

Screen 3: Permission Requests
  - Explain WHY accessibility/microphone access is needed
  - "Grant Access" button → system permission dialog
  - "Skip for Now" option

Screen 4: Configuration
  - Key settings (hotkey, AI provider, model selection)
  - "Finish Setup" button
```

### SwiftUI Wizard Implementation Pattern

```swift
struct OnboardingView: View {
    @State private var currentStep = 0

    var body: some View {
        VStack {
            // Step content
            switch currentStep {
            case 0: WelcomeStep()
            case 1: FeatureStep()
            case 2: PermissionsStep()
            case 3: ConfigurationStep()
            default: EmptyView()
            }

            // Navigation
            HStack {
                if currentStep > 0 {
                    Button("Back") { currentStep -= 1 }
                }
                Spacer()
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<4) { i in
                        Circle()
                            .fill(i == currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                Spacer()
                Button(currentStep == 3 ? "Finish" : "Next") {
                    if currentStep < 3 { currentStep += 1 }
                    else { dismissOnboarding() }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 480, height: 360)
        .scenePadding()
    }
}
```

### macOS Onboarding Window Configuration

```swift
// Onboarding window should be:
window.styleMask = [.titled, .closable]     // No resize, no minimize
window.isMovableByWindowBackground = true    // Easy to move
window.titlebarAppearsTransparent = true     // Clean look
window.titleVisibility = .hidden             // Hide title text
window.backgroundColor = .windowBackgroundColor
window.center()                              // Center on screen
```

---

## 7. Accessibility & Permission Requests

### Permission Request Best Practices

1. **Explain BEFORE requesting** — Show a custom UI explaining why the permission is needed
2. **Use clear, specific language** — "Scribe needs Accessibility access to paste transcriptions into any app"
3. **Provide visual context** — Show what the permission enables
4. **Always offer "Skip" / "Later"** — Never block the entire app
5. **Handle denial gracefully** — Offer degraded functionality, not an error
6. **Guide to System Preferences** — If denied, provide a button to open the right pane

### Pre-Permission Explanation Screen Pattern

Before triggering the system dialog:

```swift
VStack(spacing: 16) {
    Image(systemName: "accessibility")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)

    Text("Accessibility Access Required")
        .font(.title2)
        .fontWeight(.semibold)

    Text("Scribe needs Accessibility access to automatically paste transcriptions into your active application. This permission allows Scribe to simulate keyboard shortcuts.")
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 340)

    HStack(spacing: 12) {
        Button("Skip for Now") { skipPermission() }
            .controlSize(.large)

        Button("Grant Access") { requestAccessibility() }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
    }
}
```

### Opening System Settings Programmatically

```swift
// Open Accessibility preferences
NSWorkspace.shared.open(
    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
)

// Open Microphone preferences
NSWorkspace.shared.open(
    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
)
```

### NSAlert for Permission Dialogs

```swift
let alert = NSAlert()
alert.messageText = "Accessibility Permission Required"
alert.informativeText = "Scribe needs Accessibility access to paste transcriptions. Please enable it in System Settings > Privacy & Security > Accessibility."
alert.alertStyle = .informational
alert.addButton(withTitle: "Open System Settings")
alert.addButton(withTitle: "Later")
alert.icon = NSImage(systemSymbolName: "accessibility", accessibilityDescription: nil)

let response = alert.runModal()
if response == .alertFirstButtonReturn {
    // Open System Settings
}
```

---

## 8. Layout & Spacing Metrics

### Standard macOS Spacing Values

| Metric | Value (pt) | Usage |
|--------|-----------|-------|
| Window content margin | **20** | Distance from window edge to content |
| Scene padding | **~20** | SwiftUI `.scenePadding()` value |
| Section spacing | **20-24** | Space between major sections |
| Group internal padding | **12-16** | Inside a GroupBox or section |
| Control vertical spacing | **8-10** | Between adjacent form rows |
| Label-to-control spacing | **4-8** | Between a label and its control |
| Button spacing | **12** | Between adjacent buttons |
| Small inter-element gap | **4** | Tight spacing |
| Grid column spacing | **20** | NSGridView label-to-control |
| Grid row spacing | **10** | NSGridView row-to-row |
| Corner radius (standard) | **6-8** | Most rounded rects |
| Corner radius (glass) | **12** | Glass effect views |
| Corner radius (large) | **16-20** | Cards, large containers |

### SwiftUI Settings Window Frame

```swift
TabView { ... }
    .scenePadding()                              // Standard scene insets
    .frame(minWidth: 350, maxWidth: 500)         // Width range
    .frame(minHeight: 200, maxHeight: 400)       // Height range
```

### NSStackView Spacing for Settings

```swift
let stackView = NSStackView()
stackView.orientation = .vertical
stackView.spacing = 12                           // Default inter-item spacing
stackView.edgeInsets = NSEdgeInsets(
    top: 20, left: 20, bottom: 20, right: 20     // Content margins
)
stackView.alignment = .leading
```

### NSGridView Spacing for Forms

```swift
let grid = NSGridView(views: formRows)
grid.columnSpacing = 20                          // Label-to-field gap
grid.rowSpacing = 10                             // Row-to-row gap
grid.rowAlignment = .firstBaseline               // Text baseline alignment
```

### Button Layout

Standard button arrangement:
- **Right-aligned** in the window
- **Primary action on the right** (e.g., "Save" rightmost)
- **Cancel/secondary on the left** of the button group
- **12pt horizontal spacing** between buttons
- **20pt from bottom edge** of content area

```swift
HStack(spacing: 12) {
    Spacer()
    Button("Cancel") { cancel() }
    Button("Save") { save() }
        .keyboardShortcut(.defaultAction)
}
```

### Wizard/Onboarding Window Dimensions

| Property | Value |
|----------|-------|
| Width | 480-560pt |
| Height | 320-400pt |
| Not resizable | `styleMask` without `.resizable` |
| Centered on screen | `window.center()` |

### Settings Window Dimensions

| Property | Value |
|----------|-------|
| Min width | 350pt |
| Max width | 500-650pt |
| Min height | 200pt |
| Adapts to content | Height follows tab content |

---

## 9. macOS-Specific Patterns

### Menu Bar App Considerations

- No dock icon (LSUIElement = true)
- Settings accessible via menu bar dropdown
- First-run wizard appears on first launch only
- Window appears near menu bar item when possible

### macOS Form Conventions (vs iOS)

| Aspect | macOS | iOS |
|--------|-------|-----|
| Form layout | Vertical stack | Grouped list |
| Labels | End with colon (`:`) | No colon |
| Pickers | Inline (radio buttons) | Push navigation |
| Sections | GroupBox or visual spacing | Section headers |
| Toggles | NSSwitch or checkbox | Toggle only |
| Alignment | Grid/baseline aligned | Full-width rows |

### Storing Preferences

```swift
// SwiftUI
@AppStorage("showPreview") private var showPreview = true
@AppStorage("fontSize") private var fontSize = 12.0

// AppKit
UserDefaults.standard.set(value, forKey: "settingKey")
```

### Opening Settings Programmatically

```swift
// SwiftUI
@Environment(\.openSettings) var openSettings
openSettings()

// SwiftUI via SettingsLink
SettingsLink {
    Text("Open Settings")
}
```

### Color Scheme / Dark Mode

```swift
// Follow system appearance (default)
window.appearance = nil

// Force specific appearance
window.appearance = NSAppearance(named: .aqua)       // Light
window.appearance = NSAppearance(named: .darkAqua)   // Dark

// React to changes
NSColor.systemColorsDidChangeNotification
```

### Vibrancy Best Practices for Settings Windows

1. Enable vibrancy only in **leaf views** (bottom of hierarchy)
2. Use **grayscale semantic colors** (`labelColor`, `secondaryLabelColor`)
3. Select materials based on **intended use**, not visual appearance
4. Do NOT override `draw(_:)` or `updateLayer()` on vibrancy views
5. Do NOT change vibrancy settings on standard AppKit controls

### Key Color Recommendations for a Settings Window

| Element | Color |
|---------|-------|
| Window background | `windowBackgroundColor` |
| Primary text | `labelColor` |
| Secondary text | `secondaryLabelColor` |
| Disabled text | `disabledControlTextColor` |
| Input field BG | `controlBackgroundColor` |
| Input field text | `controlTextColor` |
| Accent/CTA button | `controlAccentColor` |
| Separators | `separatorColor` |
| Section titles | `labelColor` with `.headline` style |
| Help/description | `secondaryLabelColor` with `.footnote` style |
| Links | `linkColor` |
| Error state | `systemRed` |
| Success state | `systemGreen` |
| Warning state | `systemYellow` |

---

## Quick Reference Card

### Settings Window Recipe

```
Window:     .preference toolbar style, titled+closable, no resize
Size:       ~450x350pt, constrained min/max
Padding:    20pt all sides (.scenePadding)
Sections:   Tab-based (TabView or NSTabView)
Forms:      NSGridView (20pt col, 10pt row) or SwiftUI Form
Controls:   .regular control size (13pt font)
Buttons:    Right-aligned, 12pt spacing, primary rightmost
Colors:     All semantic (labelColor, controlBackgroundColor, etc.)
Typography: .body for labels, .headline for sections, .footnote for help
Glass:      .glassEffect() on macOS 26+ for modern feel
```

### First-Run Wizard Recipe

```
Window:     480x360pt, centered, transparent titlebar, no resize
Steps:      2-5 screens, progress dots, Back/Next buttons
Permissions: Pre-explain before system dialog, always skippable
Content:    Centered vertically, 340pt max text width
Typography: .title2 for headings, .body for descriptions
Glass:      Optional .glassEffect() on cards/containers
Finish:     Dismisses to menu bar, settings accessible via menu
```
