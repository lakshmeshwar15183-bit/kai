# Kai — Personal AI Operating System for macOS

Kai is a privacy-first, native-feeling AI assistant for macOS. It understands
natural-language instructions and safely performs tasks on your Mac. Kai is not
a chatbot: it is a modular operating layer that observes, plans, and acts —
always under your control.

> **Status — Milestone 1 (Architecture & Foundations).**
> This milestone delivers the modular architecture: the activation lifecycle,
> the three-tier permission model, the plugin framework, the provider-agnostic
> AI seam, privacy-first memory, an interruptible automation engine, and a
> macOS SwiftUI scaffold. The platform-agnostic core **builds and is unit-tested
> on Linux/CI**; the macOS UI and OS-specific skills are scaffolded and land in
> later milestones.

## Core principles

Modular · Extensible · Fast · Secure · Privacy-first · Native-feeling · Easy to
maintain · Easy to extend via plugins. Kai is asleep by default and only acts on
explicit activation. Saying **Stop / Pause / Cancel / Abort** halts everything.

## Repository layout

```
Sources/
  KaiCore/        Activation state machine, permission engine, stop controller,
                  event bus, logger, sensitive-data redactor  (platform-agnostic)
  KaiAI/          Provider-agnostic AI abstraction + registry + echo provider
  KaiMemory/      Privacy-first preference stores (in-memory + JSON file)
  KaiAutomation/  Interruptible multi-step workflow engine
  KaiPlugins/     Plugin protocol, registry, command router, reference plugin
  KaiApp/         macOS SwiftUI app  (compiled only on macOS via #if os(macOS))
  kai-cli/        Linux/CI-runnable demo that wires the core together
Tests/            XCTest suites for every platform-agnostic module
docs/ARCHITECTURE.md   Design, dependency direction, and trade-offs
```

## Build, test, run

The core builds anywhere Swift 6 runs (macOS, Linux, CI):

```bash
swift build        # compile all libraries + the CLI
swift test         # run the full unit-test suite
swift run kai-cli  # exercise the whole pipeline end-to-end
```

On a Mac, the `KaiApp` target provides the SwiftUI interface (status indicator,
chat, plugin manager, activity log, approval sheets), embedded in an Xcode app
that calls `KaiAppEntry.main()`.

## Why this shape?

- **Swift Package, not a single Xcode app** → strict module boundaries, fast
  feedback, and a core that is testable without a Mac in the loop.
- **macOS surfaces behind `#if os(macOS)`** → one `swift build` works on Linux
  while the real UI/skills remain first-class on macOS.
- **The permission engine is a hard gate** → it can only *escalate* an action's
  risk level (e.g. text mentioning "password" becomes Red), never lower it.
- **Privacy is enforced by the store, not the caller** → memory and logs run
  every value through a redactor and *reject* secrets outright.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full design.

## Roadmap

| Milestone | Theme |
|-----------|-------|
| **1 (this)** | Architecture, plugin framework, permissions, AI seam, memory, automation, UI scaffold |
| 2 | Voice, memory persistence UX, permission dialogs |
| 3 | Browser automation skill |
| 4 | Screen understanding (Observe / Execute) |
| 5 | Finder automation |
| 6 | Office automation |
| 7 | Study assistant |
| 8 | Workflow automation |
| 9 | Performance optimization |
| 10 | Production release |
