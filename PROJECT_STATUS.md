# Kai — Project Status

_Last updated: 0.4.0 (Final Delivery)._

## Snapshot

Kai is a modular Swift Package plus a native SwiftUI macOS application. The
platform-agnostic core, all skill logic, and the AI providers are fully built
and unit-tested in CI; the SwiftUI shell and OS integrations are complete behind
`#if os(macOS)` and build into `Kai.app`/`Kai.dmg` on a Mac.

- **Build:** `swift build` and `swift build -c release` — clean, 0 warnings.
- **Tests:** `swift test` — **104 tests, 0 failures**.
- **Demo:** `swift run kai-cli` exercises the whole pipeline on any platform.
- **App:** `make app` / `make dmg` on macOS (see `docs/MACOS_STEPS.md`).

## Completed milestones

### Milestone 1 — Foundations ✅
Modular architecture; activation state machine; three-tier permission engine
(Green/Yellow/Red, escalate-only); cooperative stop controller; event bus;
logger; sensitive-data redactor; provider-agnostic AI seam; privacy-first
memory (in-memory + JSON); interruptible workflow engine; plugin framework
(protocol, registry, command router); macOS SwiftUI scaffold; CLI demo.

### Milestone 2 — Observe/Execute, Active Window Intelligence, Browser ✅
- **Observe/Execute mode** (`ModeController`): Observe is read-only — any
  side-effecting capability is blocked until the user says "Execute".
- **Active Window Intelligence** (`ApplicationContext`, `ActiveApplicationProvider`):
  the router prefers the plugin that specialises in the frontmost application.
- **Browser automation** (`KaiBrowser`): `BrowserController` abstraction,
  page model, login detection, command parsing, and a `BrowserPlugin` that
  pauses for authentication and never enters credentials. In-memory driver for
  tests/CLI; Safari/Chrome/Edge AppleScript driver scaffolded for macOS.

### Milestone 3 — AI Provider Layer ✅
- **`KaiAIProviders`**: real OpenAI, Anthropic, Gemini, and local Ollama
  providers behind the existing `AIProvider`/`AIProviderFactory` seam, so
  switching vendor is configuration-only.
- **`HTTPTransport` seam** (URLSession in production, mock in tests) and a
  **`SecretResolver` seam** (environment now; macOS Keychain scaffold). API keys
  are resolved by reference at call time and never persisted.

### 0.4.0 — Final Delivery ✅
- **KaiFinder**: real, cross-platform file operations — organize-by-type,
  duplicate detection (SHA-256), search, rename, move, trash + **undo**.
- **KaiVision**: screen OCR + PDF reading + `DocumentAnalyzer` (read-only,
  Observe-safe); macOS Vision/PDFKit/ScreenCaptureKit engines.
- **KaiVoice**: stop-aware `VoiceSession`; macOS Speech/AVFoundation engines.
- **Workflow engine**: pause/resume/cancel, retry, undo-rollback, dependency
  ordering. **AuditTrail** (redacted JSONL). **Auto-update** architecture.
- **Native macOS app**: `KaiAssembly` composition root, full SwiftUI UI
  (chat/plugins/activity/permissions/settings/approval/voice), live provider
  switching, installer scripts, app icon.

## Backward compatibility

Milestone 3 is purely additive — the new `KaiAIProviders` module sits behind the
existing `AIProvider`/`AIProviderFactory` seam, so no existing call site changed.
(Milestone 2 additions remain backward compatible too: `Capability.sideEffect`
and `Plugin.supportedApplications` are defaulted, and `CommandRouter`'s
mode/active-app dependencies are optional.)

## In progress / next

Milestone 4 — **Native macOS shell & Accessibility** (real app target, permission
onboarding, status menu, global shortcut, `NSWorkspace` active-app provider).
This is primarily macOS-only work completed on a Mac; its platform-agnostic
substrate (system-permission model) will be built and tested in CI. See
`ROADMAP.md`.

## Platform constraints (CI/sandbox)

The CI/sandbox is Linux without Xcode/AppKit/SwiftUI. Consequently:
- ✅ Verified here: `KaiCore`, `KaiAI`, `KaiAIProviders`, `KaiMemory`,
  `KaiAutomation`, `KaiPlugins`, `KaiBrowser` (logic), CLI.
- ⚠️ Compiled on macOS only: `KaiApp` (SwiftUI) and the `#if os(macOS)` code
  (`AppleScriptBrowserController`, `KeychainSecretResolver`, the forthcoming
  `NSWorkspace` active-app provider).
