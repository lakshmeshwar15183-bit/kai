# Kai — Project Status

_Last updated: Milestone 2._

## Snapshot

Kai is being built as a **native macOS AI operating system**, organised as a
modular Swift Package. The platform-agnostic core (architecture, permissions,
plugins, AI seam, memory, automation, browser logic) is fully built and
unit-tested; macOS-only surfaces (SwiftUI UI, AppleScript/NSWorkspace bindings)
are implemented behind `#if os(macOS)` and are completed/run on a Mac in Xcode.

- **Build:** `swift build` clean on Swift 6.2 (strict concurrency).
- **Tests:** `swift test` — **62 tests, 0 failures**.
- **Demo:** `swift run kai-cli` exercises the whole pipeline on any platform.

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

## Backward compatibility

All Milestone 2 additions are additive: `Capability.sideEffect` and
`Plugin.supportedApplications` are defaulted, and `CommandRouter` gained the
mode/active-app dependencies as **optional** parameters. No existing call site
changed.

## In progress / next

Milestone 3 — **Screen Understanding (Observe deepened)** and the macOS shell &
Accessibility wiring. See `ROADMAP.md`.

## Platform constraints (CI/sandbox)

The CI/sandbox is Linux without Xcode/AppKit/SwiftUI. Consequently:
- ✅ Verified here: `KaiCore`, `KaiAI`, `KaiMemory`, `KaiAutomation`,
  `KaiPlugins`, `KaiBrowser` (logic), CLI.
- ⚠️ Compiled on macOS only: `KaiApp` (SwiftUI) and the `#if os(macOS)` drivers
  (`AppleScriptBrowserController`, the forthcoming `NSWorkspace` provider).
