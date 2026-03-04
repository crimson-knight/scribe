# Scribe — Distribution & App Store Plan

## Executive Summary

Scribe should use a **dual-distribution model**: a full-featured direct download (notarized DMG) and a sandbox-compatible Mac App Store version with reduced paste functionality. This is the same proven strategy used by SuperWhisper and MacWhisper.

**Why dual?** Three of our core APIs are fundamentally incompatible with the App Store sandbox:

| API | What It Does | Sandbox Status |
|-----|-------------|----------------|
| `CGEventPost` (Cmd+V injection) | Auto-paste into any app | **BLOCKED** — no workaround |
| `AXIsProcessTrusted` | Check Accessibility permission | **BLOCKED** — always returns false |
| `NSTask` with external binary | Launch whisper-cli | **BLOCKED** — can't exec outside bundle |

Everything else we use (RegisterEventHotKey, NSPasteboard, ScreenCaptureKit, NSStatusItem, NSPanel, GCD) works fine in the sandbox with appropriate entitlements.

---

## Distribution Channels

### Channel 1: Direct Download (Primary — Full Features)

- **Format:** Notarized DMG with drag-to-Applications installer
- **Signing:** Developer ID Application certificate + Hardened Runtime
- **Features:** Full auto-paste via CGEventPost, Accessibility API, external whisper-cli
- **Payment:** Paddle or LemonSqueezy (Merchant of Record, handles tax/VAT)
- **Updates:** Sparkle framework for auto-updates
- **Commission:** ~5% (payment processor) vs 15-30% (App Store)

### Channel 2: Mac App Store (Discovery — Reduced Features)

- **Format:** Sandboxed .pkg submitted via Transporter
- **Signing:** Apple Distribution certificate
- **Features:** Clipboard-only output (user Cmd+V's manually), bundled whisper model
- **Payment:** Apple IAP (15% Small Business Program commission)
- **Key changes from direct version:**
  - Remove all CGEventPost / Accessibility code
  - Bundle whisper.cpp as a linked library (not external subprocess)
  - Replace auto-paste with "Copied to clipboard" notification
  - Add Input Monitoring entitlement for global hotkeys

### Channel 3: Setapp (Optional — Subscription Marketplace)

- **Commission:** ~10% of allocated revenue
- **Audience:** Power users who subscribe to Setapp ($9.99/mo for 250+ apps)
- **Consideration:** Good supplementary channel, requires SDK integration

---

## Pricing Strategy

### Competitive Landscape

| App | Model | Price | Distribution |
|-----|-------|-------|-------------|
| SuperWhisper | Subscription + Lifetime | $8.49/mo, $250 lifetime | App Store + Direct |
| MacWhisper | One-time | $30 basic, $64-80 Pro | Gumroad + App Store |
| Voice Type | One-time | $19.99 | App Store |
| BetterDictation | One-time + sub | $39 offline, $2/mo Pro | Direct |
| Whisper Notes | One-time | $4.99 | App Store |

### Recommended Pricing for Scribe

**Direct Download:** $29.99 one-time purchase
- Full auto-paste, Accessibility integration
- Local-only processing, privacy-first
- Includes all future updates within major version

**App Store:** $19.99 one-time purchase
- Clipboard-only (user pastes manually)
- Same transcription quality
- Lower price reflects reduced convenience

**Future Claude AI Integration:** $4.99-9.99/month subscription add-on
- AI-powered note formatting, task extraction, file organization
- Requires cloud API calls (disclosed in privacy label)
- Available on both channels

### Privacy Advantage

Scribe's local-only whisper.cpp processing means we can legitimately display Apple's **"Data Not Collected"** privacy label. This is a significant competitive differentiator — most competitors either send audio to cloud APIs or don't clearly communicate their data practices.

---

## Prerequisites

### Apple Developer Program
- **Cost:** $99/year
- **Type:** Individual (ships under your name) or Organization (ships under company name)
- **Includes:** Developer ID certs, App Store distribution, TestFlight, notarization
- **Enroll at:** https://developer.apple.com/programs/enroll/

### Certificates Needed

| Certificate | Purpose | Where Used |
|-------------|---------|-----------|
| Developer ID Application | Sign .app for direct distribution | `codesign` |
| Developer ID Installer | Sign DMG for direct distribution | `codesign` on DMG |
| Apple Distribution | Sign .app for App Store | `codesign` |
| Mac Installer Distribution | Sign .pkg for App Store | `productbuild` |

Generate via Xcode > Settings > Accounts > Manage Certificates, or via the Apple Developer portal.

---

## .app Bundle Structure

```
Scribe.app/
  Contents/
    Info.plist                    # App metadata, privacy descriptions
    PkgInfo                       # "APPL????" (traditional)
    MacOS/
      scribe                      # Compiled Crystal arm64 binary
    Resources/
      AppIcon.icns                # App icon (1024x1024 source)
    _CodeSignature/
      CodeResources               # Created by codesign (don't create manually)
```

---

## Info.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Scribe</string>

    <key>CFBundleDisplayName</key>
    <string>Scribe</string>

    <key>CFBundleIdentifier</key>
    <string>com.scribeapp.scribe</string>

    <key>CFBundleVersion</key>
    <string>1</string>

    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>

    <key>CFBundleExecutable</key>
    <string>scribe</string>

    <key>CFBundlePackageType</key>
    <string>APPL</string>

    <key>CFBundleSignature</key>
    <string>SCRB</string>

    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>

    <key>CFBundleIconFile</key>
    <string>AppIcon</string>

    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>

    <!-- Menu bar agent app — no Dock icon -->
    <key>LSUIElement</key>
    <true/>

    <!-- Privacy usage descriptions (TCC prompts) -->
    <key>NSMicrophoneUsageDescription</key>
    <string>Scribe needs microphone access to capture your voice for dictation.</string>

    <key>NSAccessibilityUsageDescription</key>
    <string>Scribe needs accessibility access to paste transcribed text into other applications.</string>

    <key>LSArchitecturePriority</key>
    <array>
        <string>arm64</string>
    </array>

    <key>NSHighResolutionCapable</key>
    <true/>

    <key>NSSupportsAutomaticTermination</key>
    <false/>
</dict>
</plist>
```

Key details:
- `LSUIElement = true` — menu bar agent, no Dock icon
- `LSMinimumSystemVersion = 13.0` — ScreenCaptureKit requires macOS 13+
- `NSMicrophoneUsageDescription` — **mandatory** or app crashes on mic access
- `NSAccessibilityUsageDescription` — shown when user grants Accessibility

---

## Entitlements

### Direct Distribution (packaging/Scribe.entitlements)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Hardened runtime exception: microphone access -->
    <key>com.apple.security.device.audio-input</key>
    <true/>
</dict>
</plist>
```

No sandbox. Hardened Runtime enforced via `codesign -o runtime`. Only exception needed is audio input.

### App Store Distribution (packaging/Scribe-MAS.entitlements)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- App Sandbox REQUIRED for Mac App Store -->
    <key>com.apple.security.app-sandbox</key>
    <true/>

    <!-- Microphone access -->
    <key>com.apple.security.device.audio-input</key>
    <true/>

    <!-- Network access (for future Claude API integration) -->
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

---

## Build & Distribution Workflow

### Direct Distribution (make dist)

```
make macos-release
  → make bundle      (create .app structure)
  → make sign        (codesign with Developer ID + Hardened Runtime)
  → make notarize    (submit to Apple, wait, staple ticket)
  → make dmg         (create drag-to-Applications DMG, sign, notarize)
```

### App Store (make dist-mas)

```
make macos-release-mas  (build with -DMAS flag for sandbox-compatible code paths)
  → make bundle-mas     (create .app with embedded.provisionprofile)
  → make sign-mas       (codesign with Apple Distribution cert)
  → make pkg            (productbuild for App Store)
  → Upload via Transporter
```

---

## App Store Code Changes Required

The App Store version needs compile-time feature flags to exclude sandbox-incompatible code:

```crystal
{% if flag?(:mas) %}
  # App Store version: clipboard-only, no paste simulation
  Clipboard.write(transcript)
  show_notification("Copied to clipboard — press Cmd+V to paste")
{% else %}
  # Direct version: full auto-paste cycle
  LibScribePlatform.scribe_clipboard_paste_cycle(transcript.to_unsafe)
{% end %}

{% unless flag?(:mas) %}
  # Accessibility check only in direct version
  LibScribePlatform.scribe_accessibility_check(1)
{% end %}
```

For whisper integration in the App Store version:
- **Current:** Launch `/opt/homebrew/bin/whisper-cli` via NSTask
- **App Store:** Link whisper.cpp as a static library, call `whisper_full()` directly
- This requires compiling whisper.cpp for arm64 and linking it into the Crystal binary

---

## App Store Marketing Assets

| Asset | Requirement |
|-------|------------|
| App Icon | 1024x1024 PNG, no transparency |
| Screenshots | 1-10, min 1280x800 px |
| App Preview Video | Optional, max 30s, actual app footage |
| App Name | "Scribe" (30 chars max) |
| Subtitle | "Local AI Dictation" (30 chars max) |
| Category | Primary: Productivity, Secondary: Utilities |
| Keywords | `dictation,transcription,speech-to-text,voice,whisper,offline,privacy,dictate` |
| Privacy Policy URL | Required — host on website or GitHub Pages |
| Support URL | Required |

---

## Notarization Credentials Setup (One-Time)

```bash
# Generate app-specific password at appleid.apple.com
# Then store credentials in Keychain:
xcrun notarytool store-credentials "scribe-notarytool" \
  --apple-id "your@appleid.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

---

## Timeline Estimate

| Phase | What |
|-------|------|
| **Now** | Finalize core dictation features, fix paste |
| **Phase 1** | Apple Developer enrollment ($99), generate certificates |
| **Phase 2** | Create app icon, Info.plist, entitlements |
| **Phase 3** | Implement `make bundle` + `make sign` + `make notarize` + `make dmg` |
| **Phase 4** | Test notarized DMG on clean macOS install |
| **Phase 5** | Set up payment processor (Paddle/LemonSqueezy), create website |
| **Phase 6** | Launch direct download |
| **Phase 7** | (Optional) Create App Store version with sandbox adaptations |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| App Store rejects due to Accessibility usage | Can't sell on App Store | Use `-DMAS` flag to strip incompatible code |
| macOS 26 clipboard privacy changes | Paste workflow breaks | Monitor Apple's API changes, adapt early |
| whisper.cpp licensing (MIT) | Need to include license | Bundle MIT license in Resources/ |
| Name "Scribe" trademark conflict | App Store rejection | Search USPTO before submission |
| Crystal binary Hardened Runtime issues | Notarization fails | Test early, may need `allow-unsigned-executable-memory` entitlement |
</content>
</invoke>