# Apple HIG Foundations Reference

> Scraped from Apple Human Interface Guidelines on 2026-03-26.
> Source: https://developer.apple.com/design/human-interface-guidelines/

---

## Table of Contents

1. [Color](#1-color)
2. [Dark Mode](#2-dark-mode)
3. [Typography](#3-typography)
4. [Layout](#4-layout)
5. [Materials](#5-materials)
6. [SF Symbols](#6-sf-symbols)
7. [Branding](#7-branding)

---

## 1. Color

**Source:** https://developer.apple.com/design/human-interface-guidelines/color

### Best Practices

- **DO NOT** use the same color to mean different things. Use color consistently throughout your interface.
- **DO** make sure all app colors work well in light, dark, and increased contrast contexts.
- **DO** supply light and dark variants for custom colors, plus increased contrast options for each variant.
- **DO** provide both light and dark colors even for single-appearance apps (for Liquid Glass adaptivity).
- **DO** test color scheme under a variety of lighting conditions (sunny, dim, etc.).
- **DO** test on different devices (True Tone displays, different color profiles P3 vs sRGB).
- **DO** use system-provided color controls (ColorPicker) for user color selection.
- **DO NOT** hard-code system color values in your app. Use APIs like `Color` to apply system colors.
- **DO NOT** redefine the semantic meanings of dynamic system colors.

### Inclusive Color Rules

- **DO NOT** rely solely on color to differentiate between objects, indicate interactivity, or communicate essential information.
- **DO** provide the same information in alternative ways (text labels, glyph shapes).
- **DO NOT** use colors that make it hard to perceive content (insufficient contrast).
- **DO** consider how colors are perceived in other countries and cultures (red = danger in some, positive in others).

### Liquid Glass Color

- Liquid Glass has no inherent color by default; takes on colors from content behind it.
- You can apply color to some Liquid Glass elements (like colored/stained glass).
- System uses prominent button styling with accent color on Liquid Glass background.
- **DO** apply color sparingly to Liquid Glass material, symbols, and text.
- **DO** reserve color for elements that truly benefit from emphasis (status indicators, primary actions).
- **DO** apply color to background rather than symbols/text for primary actions.
- **DO NOT** add color to background of multiple controls.
- **DO NOT** use similar colors in control labels if your app has a colorful background.
- **DO** prefer monochromatic appearance for toolbars and tab bars over colorful backgrounds.
- **DO** make sure interface maintains sufficient contrast; avoid similar color overlap between content layer and controls.

### Color Management

- **DO** apply color profiles to images. sRGB produces accurate colors on most displays.
- **DO** use Display P3 color profile at 16 bits per pixel (per channel), export images in PNG format for wide color.
- **DO** provide color space-specific image and color variations when needed (P3 and sRGB).

### macOS-Specific: System Colors

> **IMPORTANT (macOS):** These are dynamic system colors. Do not hard-code values.

| Color | Use For | AppKit API |
|---|---|---|
| Alternate selected control text color | Text on a selected surface in a list or table | `alternateSelectedControlTextColor` |
| Alternating content background colors | Backgrounds of alternating rows/columns in list, table, or collection view | `alternatingContentBackgroundColors` |
| Control accent | The accent color people select in System Settings | `controlAccentColor` |
| Control background color | Background of a large interface element (browser, table) | `controlBackgroundColor` |
| Control color | Surface of a control | `controlColor` |
| Control text color | Text of a control that is available | `controlTextColor` |
| Current control tint | System-defined control tint | `currentControlTint` |
| Unavailable control text color | Text of a control that's unavailable | `disabledControlTextColor` |
| Find highlight color | Color of a find indicator | `findHighlightColor` |
| Grid color | Gridlines of an interface element (table) | `gridColor` |
| Header text color | Text of a header cell in a table | `headerTextColor` |
| Highlight color | Virtual light source onscreen | `highlightColor` |
| Keyboard focus indicator color | Ring around currently focused control via keyboard nav | `keyboardFocusIndicatorColor` |
| Label color | Text of a label containing primary content | `labelColor` |
| Link color | A link to other content | `linkColor` |
| Placeholder text color | Placeholder string in a control or text view | `placeholderTextColor` |
| Quaternary label color | Text of a label of lesser importance than tertiary | `quaternaryLabelColor` |
| Secondary label color | Text of a label of lesser importance than primary | `secondaryLabelColor` |
| Selected content background color | Background for selected content in a key window or view | `selectedContentBackgroundColor` |
| Selected control color | Surface of a selected control | `selectedControlColor` |
| Selected control text color | Text of a selected control | `selectedControlTextColor` |
| Selected menu item text color | Text of a selected menu | `selectedMenuItemTextColor` |
| Selected text background color | Background of selected text | `selectedTextBackgroundColor` |
| Selected text color | Color for selected text | `selectedTextColor` |
| Separator color | Separator between different sections of content | `separatorColor` |
| Shadow color | Virtual shadow cast by a raised object onscreen | `shadowColor` |
| Tertiary label color | Text of a label of lesser importance than secondary | `tertiaryLabelColor` |
| Text background color | Background color behind text | `textBackgroundColor` |
| Text color | Text in a document | `textColor` |
| Under page background color | Background behind a document's content | `underPageBackgroundColor` |
| Unemphasized selected content BG | Selected content in a non-key window or view | `unemphasizedSelectedContentBackgroundColor` |
| Unemphasized selected text BG | Background for selected text in a non-key window or view | `unemphasizedSelectedTextBackgroundColor` |
| Unemphasized selected text color | Selected text in a non-key window or view | `unemphasizedSelectedTextColor` |
| Window background color | Background of a window | `windowBackgroundColor` |
| Window frame text color | Text in the window's title bar area | `windowFrameTextColor` |

### macOS-Specific: App Accent Colors

- Beginning in macOS 11, you can specify an accent color for buttons, selection highlighting, and sidebar icons.
- System applies your accent color when user's General > Accent color = multicolor.
- If user sets accent color to a value other than multicolor, system overrides your accent color.
- Exception: Fixed-color sidebar icons keep their specified color regardless of accent color setting.

### iOS/iPadOS: Dynamic Background Colors

Two sets of dynamic background colors: **system** and **grouped**, each with primary/secondary/tertiary variants.

| Variant | Use For |
|---|---|
| Primary | Overall view |
| Secondary | Grouping content or elements within the overall view |
| Tertiary | Grouping content or elements within secondary elements |

**System set:** `systemBackground`, `secondarySystemBackground`, `tertiarySystemBackground`
**Grouped set:** `systemGroupedBackground`, `secondarySystemGroupedBackground`, `tertiarySystemGroupedBackground`

Use grouped background colors with grouped table views; otherwise use system set.

### iOS/iPadOS: Foreground Dynamic Colors

| Color | Use For | UIKit API |
|---|---|---|
| Label | Primary content text label | `label` |
| Secondary label | Secondary content text label | `secondaryLabel` |
| Tertiary label | Tertiary content text label | `tertiaryLabel` |
| Quaternary label | Quaternary content text label | `quaternaryLabel` |
| Placeholder text | Placeholder text in controls or text views | `placeholderText` |
| Separator | Separator allowing some underlying content visible | `separator` |
| Opaque separator | Separator not allowing underlying content visible | `opaqueSeparator` |
| Link | Text that functions as a link | `link` |

### System Colors (SwiftUI API Names)

| Name | SwiftUI API |
|---|---|
| Red | `red` |
| Orange | `orange` |
| Yellow | `yellow` |
| Green | `green` |
| Mint | `mint` |
| Teal | `teal` |
| Cyan | `cyan` |
| Blue | `blue` |
| Indigo | `indigo` |
| Purple | `purple` |
| Pink | `pink` |
| Brown | `brown` |

> Note: Color swatches with hex/RGB values are rendered as images on the HIG page. These colors have Default (light), Default (dark), Increased contrast (light), and Increased contrast (dark) variants. Use the SwiftUI/UIKit APIs to get the correct values dynamically.

### iOS/iPadOS System Gray Colors

| Name | UIKit API |
|---|---|
| Gray | `systemGray` |
| Gray (2) | `systemGray2` |
| Gray (3) | `systemGray3` |
| Gray (4) | `systemGray4` |
| Gray (5) | `systemGray5` |
| Gray (6) | `systemGray6` |

> In SwiftUI, the equivalent of `systemGray` is `gray`.

---

## 2. Dark Mode

**Source:** https://developer.apple.com/design/human-interface-guidelines/dark-mode

### Best Practices

- **DO NOT** offer an app-specific appearance setting. Respect the systemwide appearance choice.
- **DO** ensure your app looks good in both light and dark appearance modes.
- **DO** test content for legibility in both modes.
- **DO** test with Increase Contrast and Reduce Transparency turned on (both separately and together).
- In rare cases, a dark-only appearance is acceptable (e.g., immersive media viewing apps like Stocks).

### Dark Mode Colors

- The dark palette uses **dimmer background colors** and **brighter foreground colors**.
- Colors are NOT necessarily inversions of their light counterparts.
- **DO** embrace colors that adapt to the current appearance. Use semantic colors (`labelColor`, `controlColor`, `separator`).
- **DO** add a Color Set asset to your app's asset catalog in Xcode, specifying bright and dim variants for custom colors.
- **DO NOT** use hard-coded color values or non-adaptive colors.

### Contrast Requirements

| Level | Minimum Contrast Ratio |
|---|---|
| Minimum acceptable | 4.5:1 |
| Recommended (especially small text) | 7:1 |

- **DO** soften the color of white backgrounds in content images to prevent glowing in Dark Mode.

### Icons and Images

- **DO** use SF Symbols wherever possible (automatically adapt to Dark Mode).
- **DO** design separate interface icons for light and dark appearances if necessary.
- **DO** use asset catalogs to combine light and dark assets into a single named image.

### Text in Dark Mode

- **DO** use system-provided label colors (primary, secondary, tertiary, quaternary) -- they adapt automatically.
- **DO** use system views to draw text fields and text views.

### macOS-Specific: Dark Mode

**Desktop Tinting:**
- When people choose the graphite accent color, macOS causes window backgrounds to pick up color from the current desktop picture.
- **DO** include some transparency in custom component backgrounds (when appropriate) so they pick up desktop tinting color.
- **DO** add transparency only when the component is in a neutral state (not using color).
- **DO NOT** add transparency when the component is in a state that uses color.

### iOS/iPadOS-Specific: Dark Mode

**Base and Elevated backgrounds:**
- System uses two sets of background colors: **base** (dimmer, for receding backgrounds) and **elevated** (brighter, for foreground interfaces).
- **Base** = standard background
- **Elevated** = foreground interfaces (popovers, modal sheets, multitasking, multiple-window contexts)
- **DO** prefer system background colors. Custom backgrounds make it harder to perceive system-provided visual distinctions.

---

## 3. Typography

**Source:** https://developer.apple.com/design/human-interface-guidelines/typography

### Default and Minimum Font Sizes

| Platform | Default Size | Minimum Size |
|---|---|---|
| iOS, iPadOS | 17 pt | 11 pt |
| **macOS** | **13 pt** | **10 pt** |
| tvOS | 29 pt | 23 pt |
| visionOS | 17 pt | 12 pt |
| watchOS | 16 pt | 12 pt |

### Font Weight Rules

- **DO NOT** use light font weights (Ultralight, Thin, Light) -- they are difficult to see, especially at small sizes.
- **DO** prefer Regular, Medium, Semibold, or Bold font weights.

### System Typeface Families

- **San Francisco (SF):** Sans serif. Variants: SF Pro, SF Compact, SF Arabic, SF Armenian, SF Georgian, SF Hebrew, SF Mono. Also available in Rounded variants.
- **New York (NY):** Serif typeface designed to work alongside SF fonts.
- Both available in variable font format.
- Dynamic optical sizes merge discrete sizes (Text and Display) into continuous design.

### macOS-Specific: Built-in Text Styles

| Text Style | Weight | Size (pt) | Line Height (pt) | Emphasized Weight |
|---|---|---|---|---|
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

> Point size based on image resolution of 144 ppi for @2x designs.

### macOS-Specific: Dynamic System Font Variants

| Variant | API |
|---|---|
| Control content | `controlContentFont(ofSize:)` |
| Label | `labelFont(ofSize:)` |
| Menu | `menuFont(ofSize:)` |
| Menu bar | `menuBarFont(ofSize:)` |
| Message | `messageFont(ofSize:)` |
| Palette | `paletteFont(ofSize:)` |
| Title | `titleBarFont(ofSize:)` |
| Tool tips | `toolTipsFont(ofSize:)` |
| Document text (user) | `userFont(ofSize:)` |
| Monospaced document text | `userFixedPitchFont(ofSize:)` |
| Bold system font | `boldSystemFont(ofSize:)` |
| System font | `systemFont(ofSize:)` |

> **macOS does not support Dynamic Type.**

### iOS/iPadOS Dynamic Type Sizes -- Large (Default)

| Text Style | Weight | Size (pt) | Leading (pt) | Emphasized Weight |
|---|---|---|---|---|
| Large Title | Regular | 34 | 41 | Bold |
| Title 1 | Regular | 28 | 34 | Bold |
| Title 2 | Regular | 22 | 28 | Bold |
| Title 3 | Regular | 20 | 25 | Semibold |
| Headline | Semibold | 17 | 22 | Semibold |
| Body | Regular | 17 | 22 | Semibold |
| Callout | Regular | 16 | 21 | Semibold |
| Subhead | Regular | 15 | 20 | Semibold |
| Footnote | Regular | 13 | 18 | Semibold |
| Caption 1 | Regular | 12 | 16 | Semibold |
| Caption 2 | Regular | 11 | 13 | Semibold |

> Point size based on image resolution of 144 ppi for @2x and 216 ppi for @3x designs.

### iOS/iPadOS Dynamic Type -- All Sizes Summary

| Dynamic Type Size | Large Title | Title 1 | Title 2 | Title 3 | Headline | Body | Callout | Subhead | Footnote | Caption 1 | Caption 2 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| xSmall | 31 | 25 | 19 | 17 | 14 | 14 | 13 | 12 | 12 | 11 | 11 |
| Small | 32 | 26 | 20 | 18 | 15 | 15 | 14 | 13 | 12 | 11 | 11 |
| Medium | 33 | 27 | 21 | 19 | 16 | 16 | 15 | 14 | 12 | 11 | 11 |
| **Large (default)** | **34** | **28** | **22** | **20** | **17** | **17** | **16** | **15** | **13** | **12** | **11** |
| xLarge | 36 | 30 | 24 | 22 | 19 | 19 | 18 | 17 | 15 | 14 | 13 |
| xxLarge | 38 | 32 | 26 | 24 | 21 | 21 | 20 | 19 | 17 | 16 | 15 |
| xxxLarge | 40 | 34 | 28 | 26 | 23 | 23 | 22 | 21 | 19 | 18 | 17 |

### iOS/iPadOS Larger Accessibility Type Sizes

| Accessibility Size | Large Title | Title 1 | Title 2 | Title 3 | Headline | Body | Callout | Subhead | Footnote | Caption 1 | Caption 2 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| AX1 | 44 | 38 | 34 | 31 | 28 | 28 | 26 | 25 | 23 | 22 | 20 |
| AX2 | 48 | 43 | 39 | 37 | 33 | 33 | 32 | 30 | 27 | 26 | 24 |
| AX3 | 52 | 48 | 44 | 43 | 40 | 40 | 38 | 36 | 33 | 32 | 29 |
| AX4 | 56 | 53 | 50 | 49 | 47 | 47 | 44 | 42 | 38 | 37 | 34 |
| AX5 | 60 | 58 | 56 | 55 | 53 | 53 | 51 | 49 | 44 | 43 | 40 |

### macOS Tracking Values (SF Pro)

Key values for common macOS text sizes:

| Size (pt) | Tracking (1/1000 em) | Tracking (pt) |
|---|---|---|
| 10 | +12 | +0.12 |
| 11 | +6 | +0.06 |
| 12 | 0 | 0 |
| 13 | -6 | -0.08 |
| 14 | -11 | -0.15 |
| 15 | -16 | -0.23 |
| 16 | -20 | -0.31 |
| 17 | -26 | -0.43 |
| 18 | -25 | -0.44 |
| 20 | -23 | -0.45 |
| 22 | -12 | -0.26 |
| 24 | +3 | +0.07 |
| 26 | +8 | +0.22 |
| 28 | +14 | +0.38 |
| 30 | +14 | +0.40 |
| 34 | +12 | +0.40 |
| 40 | +10 | +0.37 |
| 48 | +8 | +0.35 |
| 56 | +6 | +0.30 |
| 64 | +4 | +0.22 |
| 72 | +2 | +0.14 |
| 80 | 0 | 0 |
| 96 | 0 | 0 |

### Typography Best Practices

- **DO** use built-in text styles for convenience and consistency.
- **DO** support Dynamic Type (iOS, iPadOS, tvOS, visionOS, watchOS).
- **DO** test layout with all font sizes (smallest to largest accessibility size).
- **DO** increase the size of meaningful interface icons as font size increases.
- **DO** keep text truncation to a minimum as font size increases.
- **DO** consider stacked layouts at large font sizes (instead of inline items).
- **DO** reduce number of columns when font size increases.
- **DO** maintain consistent information hierarchy regardless of current font size.
- **DO NOT** mix too many different typefaces.
- In SwiftUI, use `Font.Design.default` for system font, `Font.Design.serif` for New York.
- **DO NOT** embed system fonts in your app or game.

---

## 4. Layout

**Source:** https://developer.apple.com/design/human-interface-guidelines/layout

### Best Practices

- **DO** group related items (use negative space, background shapes, colors, materials, separator lines).
- **DO** give essential information sufficient space.
- **DO** extend content to fill the screen or window (backgrounds, full-screen artwork to display edges).
- **DO** ensure scrollable layouts continue to bottom and sides of device screen.
- Controls and navigation (sidebars, tab bars) appear on top of content, not the same plane.
- Use `backgroundExtensionEffect()` / `UIBackgroundExtensionView` for content behind the control layer.

### Visual Hierarchy

- **DO** differentiate controls from content using Liquid Glass material.
- **DO** use scroll edge effect instead of a background for transition between content and control area.
- **DO** place items in reading order (top-to-bottom, leading-to-trailing) for importance.
- **DO** align components with one another for scanning and organization.
- **DO** use progressive disclosure for hidden content.
- **DO** provide enough space around controls and group them logically.

### Adaptability

Key variations to handle:
- Different screen sizes, resolutions, color spaces
- Device orientations (portrait/landscape)
- Dynamic Island and camera control
- External display support, Display Zoom, resizable windows
- Dynamic Type text-size changes
- Internationalization (LTR/RTL, date/time/number formatting)

Rules:
- **DO** respect system-defined safe areas, margins, and guides.
- **DO** be prepared for text-size changes (Dynamic Type).
- **DO** preview on multiple devices, orientations, localizations, text sizes.
- **DO** scale artwork in response to display changes (don't change aspect ratio; scale to keep important content visible).

### macOS-Specific Layout

- **DO NOT** place controls or critical information at the bottom of a window (people move windows so bottom is below screen).
- **DO NOT** display content within the camera housing at the top edge of the window.
- Use `NSPrefersDisplaySafeAreaCompatibilityMode` for camera housing avoidance.

### iOS-Specific Layout

- **DO** support both portrait and landscape orientations when possible.
- **DO NOT** use full-width buttons. Respect system-defined margins, inset from screen edges.
- If full-width button needed, harmonize with hardware curvature and align with safe areas.
- **DO NOT** hide the status bar unless it adds value (games, media viewing).
- For games, prefer full-bleed interface filling the screen while accommodating corner radius, sensor housing, Dynamic Island.

### iPadOS-Specific Layout

- People can freely resize windows. Account for the full range of possible window sizes.
- **DO** defer switching to a compact view for as long as possible. Design for full-screen first.
- **DO** test at common system-provided sizes (halves, thirds, quadrants).
- **DO** consider a convertible tab bar for adaptive navigation (sidebar <-> tab bar).

### tvOS-Specific Layout

**Safe Area Insets:**

| Edge | Inset |
|---|---|
| Top | 60 pt |
| Bottom | 60 pt |
| Left | 80 pt |
| Right | 80 pt |

**Grid Layouts:**

| Columns | Unfocused Content Width | Horizontal Spacing | Min Vertical Spacing |
|---|---|---|---|
| 2 | 860 pt | 40 pt | 100 pt |
| 3 | 560 pt | 40 pt | 100 pt |
| 4 | 410 pt | 40 pt | 100 pt |
| 5 | 320 pt | 40 pt | 100 pt |
| 6 | 260 pt | 40 pt | 100 pt |
| 7 | 217 pt | 40 pt | 100 pt |
| 8 | 184 pt | 40 pt | 100 pt |
| 9 | 160 pt | 40 pt | 100 pt |

### visionOS-Specific Layout

- **DO** center the most important content and controls.
- **DO** keep window content within its bounds (system controls appear just outside bounds).
- **DO** use ornaments for additional controls outside the window.
- **DO** place buttons so their centers are at least 60 points apart.

### watchOS-Specific Layout

- **DO** extend content edge-to-edge (bezel provides natural padding).
- **DO NOT** place more than 3 glyph buttons or 2 text buttons side by side.

### Device Screen Dimensions (Key Models)

#### iPhone (Portrait, points)

| Model | Width x Height (pt) | Pixels | Scale |
|---|---|---|---|
| iPhone 17 Pro Max | 440 x 956 | 1320 x 2868 | @3x |
| iPhone 17 Pro | 402 x 874 | 1206 x 2622 | @3x |
| iPhone Air | 420 x 912 | 1260 x 2736 | @3x |
| iPhone 17 | 402 x 874 | 1206 x 2622 | @3x |
| iPhone 16 Pro Max | 440 x 956 | 1320 x 2868 | @3x |
| iPhone 16 Pro | 402 x 874 | 1206 x 2622 | @3x |
| iPhone 16 Plus | 430 x 932 | 1290 x 2796 | @3x |
| iPhone 16 | 393 x 852 | 1179 x 2556 | @3x |
| iPhone 16e | 390 x 844 | 1170 x 2532 | @3x |
| iPhone 15 Pro Max | 430 x 932 | 1290 x 2796 | @3x |
| iPhone 15 Pro | 393 x 852 | 1179 x 2556 | @3x |
| iPhone SE 4.7" | 375 x 667 | 750 x 1334 | @2x |

#### iPad (Portrait, points)

| Model | Width x Height (pt) | Pixels | Scale |
|---|---|---|---|
| iPad Pro 12.9" | 1024 x 1366 | 2048 x 2732 | @2x |
| iPad Pro 11" | 834 x 1194 | 1668 x 2388 | @2x |
| iPad Air 13" | 1024 x 1366 | 2048 x 2732 | @2x |
| iPad Air 11" | 820 x 1180 | 1640 x 2360 | @2x |
| iPad 11" | 820 x 1180 | 1640 x 2360 | @2x |
| iPad mini 8.3" | 744 x 1133 | 1488 x 2266 | @2x |

### Size Classes

| Device Type | Portrait | Landscape |
|---|---|---|
| All iPads | Regular width, Regular height | Regular width, Regular height |
| iPhone Pro Max / Plus models | Compact width, Regular height | Regular width, Compact height |
| iPhone Pro / standard / mini | Compact width, Regular height | Compact width, Compact height |

---

## 5. Materials

**Source:** https://developer.apple.com/design/human-interface-guidelines/materials

### Overview

Two types of materials on Apple platforms:
1. **Liquid Glass** -- unifies design language across platforms; for controls and navigation layer.
2. **Standard materials** -- blur, vibrancy, blending modes; for visual differentiation within content layer.

### Liquid Glass Rules

- **DO NOT** use Liquid Glass in the content layer. It is for controls and navigation only.
- Exception: Transient interactive elements like sliders and toggles in content layer can use Liquid Glass.
- **DO** use Liquid Glass effects sparingly. Standard system components pick it up automatically.
- **DO** limit custom Liquid Glass effects to the most important functional elements.
- API: `Applying Liquid Glass to custom views`

### Liquid Glass Variants

| Variant | Description | Use When |
|---|---|---|
| **Regular** | Blurs and adjusts luminosity of background content | Background content might create legibility issues; components have significant text (alerts, sidebars, popovers) |
| **Clear** | Highly translucent, prioritizes visibility of underlying content | Components float above media (photos, videos) for immersive experience |

**Clear variant dimming guidance:**
- Bright underlying content: add a dark dimming layer at **35% opacity**. API: `.clear`
- Dark underlying content or AVKit standard playback controls: no dimming layer needed.

### Standard Materials Rules

- **DO** choose materials based on semantic meaning and recommended usage, not apparent color.
- **DO** use vibrant colors on top of materials (system-defined vibrant colors handle contrast).
- **DO** consider contrast and visual separation: thicker = more opaque, better for text; thinner = more translucent, helps retain context.

### macOS-Specific Materials

- macOS provides several standard materials with designated purposes, plus vibrant versions of all system colors.
- Two background blending modes: **behind window** and **within window**.
- API: `NSVisualEffectView`, `NSVisualEffectView.BlendingMode`
- **DO** test vibrancy in a variety of contexts (it can either enhance or detract).

### iOS/iPadOS: Standard Material Thicknesses

| Material | Description |
|---|---|
| ultraThin | Most translucent |
| thin | Moderately translucent |
| regular (default) | Balanced |
| thick | Most opaque |

### iOS/iPadOS: Vibrancy Levels

**Labels:**
- `UIVibrancyEffectStyle.label` (default, highest contrast)
- `UIVibrancyEffectStyle.secondaryLabel`
- `UIVibrancyEffectStyle.tertiaryLabel`
- `UIVibrancyEffectStyle.quaternaryLabel` (lowest contrast -- avoid on thin and ultraThin materials)

**Fills:**
- `UIVibrancyEffectStyle.fill` (default)
- `UIVibrancyEffectStyle.secondaryFill`
- `UIVibrancyEffectStyle.tertiaryFill`

**Separators:** single default vibrancy value, works on all materials.

### tvOS Materials

| Material | Recommended For |
|---|---|
| ultraThin | Full-screen views requiring light color scheme |
| thin | Overlay views requiring light color scheme |
| regular | Overlay views that partially obscure content |
| thick | Overlay views requiring dark color scheme |

### visionOS Materials

- Windows use unmodifiable system glass material.
- Glass is adaptive: limits background color information for contrast, adapts to luminance behind it.
- visionOS has no distinct Dark Mode. Glass adapts automatically.
- **DO** prefer translucency to opaque colors in windows.

**visionOS material types for custom components:**
- **thin** -- brings attention to interactive elements (buttons, selected items)
- **regular** -- visually separates sections (sidebar, grouped table view)
- **thick** -- creates dark element visually distinct on regular background

**visionOS vibrancy values for text hierarchy:**
- `UIVibrancyEffectStyle.label` -- standard text
- `UIVibrancyEffectStyle.secondaryLabel` -- descriptive text (footnotes, subtitles)
- `UIVibrancyEffectStyle.tertiaryLabel` -- inactive elements, low legibility situations only

---

## 6. SF Symbols

**Source:** https://developer.apple.com/design/human-interface-guidelines/sf-symbols

### Overview

- Thousands of configurable symbols that integrate with San Francisco system font.
- Automatically align with text in all weights and sizes.
- Symbol availability varies by OS version; newer symbols not available on older systems.
- Download the SF Symbols app to browse the full set.
- **DO NOT** use SF Symbols (or confusingly similar images) in app icons, logos, or any trademarked use.

### Rendering Modes

| Mode | Description |
|---|---|
| **Monochrome** | One color to all layers. Paths render in specified color or as transparent shape. |
| **Hierarchical** | One color, varying opacity per hierarchical layer level. |
| **Palette** | Two or more colors, one per layer. Two colors means secondary and tertiary share a color. |
| **Multicolor** | Intrinsic colors for meaning (e.g., green for leaf, red for trash.slash). Some layers accept custom color. |

- System-provided colors ensure symbols adapt to accessibility, vibrancy, and Dark Mode.
- API: `renderingMode(_:)`
- Use `automatic` setting to get a symbol's preferred rendering mode, but verify results.

### Gradients (SF Symbols 7+)

- Smooth linear gradient from a single source color.
- Works across all rendering modes, system and custom colors, custom symbols.
- Looks best at larger sizes.

### Variable Color

- Represents a characteristic that can change over time (capacity, strength).
- Color applied to different layers as value reaches thresholds between 0-100%.
- Some layers can opt out of variable color (e.g., the speaker body in speaker.wave.3).
- **DO** use variable color for communicating change. **DO NOT** use for depth (use Hierarchical for depth).

### Weights and Scales

**9 weights** (matching San Francisco font weights):
Ultralight, Thin, Light, Regular, Medium, Semibold, Bold, Heavy, Black

**3 scales** (relative to SF cap height):
- Small
- Medium (default)
- Large

- APIs: `imageScale(_:)` (SwiftUI), `UIImage.SymbolScale` (UIKit), `NSImage.SymbolConfiguration` (AppKit)

### Design Variants

| Variant | Purpose |
|---|---|
| Outline (most common) | No solid areas, resembles text. Good for toolbars, lists, alongside text. |
| Fill | Solid areas within shapes. More visual emphasis. Good for iOS tab bars, swipe actions, accent color selection. |
| Slash | Shows unavailability. |
| Enclosed (circle, square, rectangle) | Improves legibility at small sizes. |

- Language/script-specific variants adapt automatically when device language changes.
- Views determine outline vs fill automatically (e.g., iOS tab bar prefers fill, toolbar prefers outline).

### Animations

| Animation | Purpose |
|---|---|
| **Appear** | Gradually emerges into view |
| **Disappear** | Gradually recedes out of view |
| **Bounce** | Elastic movement up/down, returns to initial state. Communicates action occurred. |
| **Scale** | Changes size, persists until reset. Feedback for selection. |
| **Pulse** | Varies opacity over time. Communicates ongoing activity. |
| **Variable color** | Incrementally varies layer opacity. Cumulative or iterative. Progress/broadcasting. |
| **Replace** | Replaces one symbol with another (down-up, up-up, off-up configurations). |
| **Magic Replace** (default) | Smart transition between related shapes (slashes draw on/off, badges appear/disappear). |
| **Wiggle** | Moves back and forth along axis. Highlights change or call to action. |
| **Breathe** | Smoothly increases/decreases presence (opacity + size). Living quality for status/recording. |
| **Rotate** | Rotates to indicate progress or imitate real-world behavior. Whole symbol or by layer. |
| **Draw On / Draw Off** (SF Symbols 7+) | Draws along a path. Conveys progress or reinforces meaning. |

Rules:
- **DO** apply symbol animations judiciously. Too many overwhelm the interface.
- **DO** make sure animations serve a clear purpose.
- **DO** use animations to communicate information efficiently.
- **DO** consider your app's tone when adding animations.

### Custom Symbols

- Export a template for a similar existing symbol, modify in a vector-editing tool.
- **DO NOT** customize symbols that depict Apple products/features (badged with Info icon in SF Symbols app).
- **DO** use the template as a guide. Match level of detail, optical weight, alignment, position, perspective.
- Goals for custom symbols: Simple, Recognizable, Inclusive, Directly related to action/content.
- **DO** assign negative side margins for optical horizontal alignment when symbols have badges.
- **DO** optimize layers for animations; annotate layers in SF Symbols app.
- **DO** test animations for custom symbols (shapes may not appear as expected in motion).
- **DO** draw custom symbols with whole shapes (use erase layers for cutouts).
- **DO NOT** design replicas of Apple products.
- **DO** provide alternative text labels (accessibility descriptions) for custom symbols.

---

## 7. Branding

**Source:** https://developer.apple.com/design/human-interface-guidelines/branding

### Best Practices

- **DO** use your brand's unique voice and tone in all written communication.
- **DO** consider choosing an accent color (system applies to buttons, selection, sidebar icons).
  - In macOS, people can override your accent color with their own preference.
- **DO** consider using a custom font for headlines/subheadings (system font for body/captions for legibility).
- **DO** ensure branding always defers to content. Don't waste screen space on brand assets that provide no function.
- **DO** use standard patterns consistently (UI components in expected locations, standard symbols for common actions).
- **DO NOT** display your logo throughout your app unless essential for context.
- **DO NOT** use the launch screen as a branding opportunity (it disappears too quickly).
  - Instead, use a welcome/onboarding screen for branding.
- **DO** follow Apple's trademark guidelines. Apple trademarks must not appear in your app name or images.

---

## Quick Reference: macOS-Specific Callouts Summary

### Typography
- System font: SF Pro (13pt default, 10pt minimum)
- No Dynamic Type support on macOS
- Use dynamic system font variants (`controlContentFont`, `labelFont`, `menuFont`, etc.) to match text in standard controls
- New York (serif) available for Mac Catalyst apps

### Color
- 30+ dynamic system colors via AppKit APIs
- App accent colors supported since macOS 11
- Accent color overridden when user chooses non-multicolor setting (exception: fixed-color sidebar icons)
- Desktop tinting: window backgrounds pick up color from desktop picture when graphite accent selected

### Layout
- Do not place controls at bottom of windows
- Avoid content in camera housing area
- Use `NSPrefersDisplaySafeAreaCompatibilityMode`

### Dark Mode
- Desktop tinting effect active in both modes
- Include transparency in custom component backgrounds for desktop tinting harmony
- Two blending modes: behind window, within window

### Materials
- `NSVisualEffectView` for standard materials
- `NSVisualEffectView.BlendingMode`: behind window, within window
- Vibrant versions of all system colors available

### Branding
- People can override your accent color in System Settings
- No platform-specific additional considerations

---

## Key Numeric Values Quick Reference

| Metric | Value |
|---|---|
| **Minimum contrast ratio** | 4.5:1 |
| **Recommended contrast ratio** | 7:1 (especially small text) |
| **macOS default font size** | 13 pt |
| **macOS minimum font size** | 10 pt |
| **iOS default font size** | 17 pt |
| **iOS minimum font size** | 11 pt |
| **Minimum button hit region** | 44x44 pt (60x60 pt visionOS) |
| **visionOS button center spacing** | min 60 pt apart |
| **tvOS safe area (top/bottom)** | 60 pt |
| **tvOS safe area (left/right)** | 80 pt |
| **tvOS grid horizontal spacing** | 40 pt |
| **tvOS grid min vertical spacing** | 100 pt |
| **Clear Liquid Glass dimming (bright bg)** | 35% opacity dark layer |
| **Wide color export** | Display P3, 16 bits/channel, PNG |
| **watchOS max controls side by side** | 3 glyph buttons or 2 text buttons |
| **macOS Image resolution** | 144 ppi (@2x) |
| **iOS Image resolution** | 144 ppi (@2x) / 216 ppi (@3x) |
