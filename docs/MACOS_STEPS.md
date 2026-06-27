# Building & Running Kai on macOS

Kai's engines, skills, AI providers, and tests are platform-agnostic and run on
any Swift 6 toolchain (including Linux CI). The **application shell** (SwiftUI)
and several **OS integrations** (Accessibility, AppleScript, ScreenCaptureKit,
Vision, Speech, PDFKit, Keychain) require Apple frameworks and therefore compile
and run **only on macOS**. They are written in full and gated with
`#if os(macOS)`.

This document is the exact checklist to turn the repository into a launchable,
installable `Kai.app` on a Mac.

## Prerequisites

- macOS 14 (Sonoma) or later
- Xcode 16 / Swift 6 toolchain (`xcode-select --install` + full Xcode)
- Optional for the icon: `brew install librsvg`

## 1. Build and run in development

```bash
swift run kai-app
```

This launches the SwiftUI app directly. On first run, open the **Permissions**
tab and grant the permissions you want to use (Accessibility, Screen Recording,
Microphone, Speech Recognition). Kai never bypasses these prompts.

## 2. Package a signed app bundle

```bash
make app        # -> dist/Kai.app   (ad-hoc signed)
# or, for distribution:
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" make app
```

`Scripts/build_app.sh` performs a release build of the `kai-app` product,
assembles `dist/Kai.app` with `App/Info.plist` and the generated icon, and code
signs it with the hardened runtime using `App/Kai.entitlements`.

## 3. Create a DMG installer

```bash
make dmg        # -> dist/Kai.dmg (with an /Applications drop link)
```

For public distribution, notarize the DMG:

```bash
xcrun notarytool submit dist/Kai.dmg --apple-id "you@example.com" \
  --team-id TEAMID --password "app-specific-password" --wait
xcrun stapler staple dist/Kai.dmg
```

## 4. Regenerate the icon (optional)

```bash
make icon       # rasterizes App/AppIcon.svg into App/AppIcon.icns + asset PNGs
```

## 5. Configure an AI provider (optional)

Out of the box Kai uses the offline **echo** provider, so it launches with zero
configuration. To use a real model, open **Settings → AI**, choose a provider
(OpenAI / Anthropic / Gemini / Ollama) and model. Store the API key in the
Keychain under service `com.kai.apikeys` with the account name shown in the
config (e.g. `OPENAI_API_KEY`):

```bash
security add-generic-password -s com.kai.apikeys -a OPENAI_API_KEY -w "sk-…"
```

Ollama needs no key — just run `ollama serve` locally.

## Notes

- Distribution is outside the Mac App Store (Developer ID + notarization),
  because automating other apps and capturing the screen are incompatible with
  the App Sandbox. The hardened runtime is enabled at signing time.
- All other functionality (provider clients, Finder logic, parsing, analysis,
  workflow engine) is already verified by `swift test` on any platform.
