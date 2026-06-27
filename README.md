# Kai — Personal AI Operating System for macOS

Kai is a privacy-first, native-feeling AI assistant for macOS. It understands
natural-language instructions and safely performs tasks on your Mac. Kai is not
a chatbot: it is a modular operating layer that observes, plans, and acts —
always under your control.

> **Status — Milestone 2 (Observe/Execute · Active Window Intelligence · Browser).**
> Milestone 1 delivered the modular architecture (activation lifecycle, the
> three-tier permission model, plugin framework, provider-agnostic AI seam,
> privacy-first memory, interruptible automation, macOS UI scaffold). Milestone 2
> adds **Observe/Execute mode**, **Active Window Intelligence**, and the first
> **skill module — browser automation**. The platform-agnostic core **builds and
> is unit-tested on Linux/CI** (62 tests); the macOS UI and OS-specific drivers
> are scaffolded behind `#if os(macOS)` and land fully in later milestones.

## Core principles

Modular · Extensible · Fast · Secure · Privacy-first · Native-feeling · Easy to
maintain · Easy to extend via plugins. Kai is asleep by default and only acts on
explicit activation. Saying **Stop / Pause / Cancel / Abort** halts everything.

## Repository layout

```
Sources/
  KaiCore/        Activation + Observe/Execute mode, permission engine, stop
                  controller, event bus, logger, redactor, active-app model
  KaiAI/          Provider-agnostic AI abstraction + registry + echo provider
  KaiMemory/      Privacy-first preference stores (in-memory + JSON file)
  KaiAutomation/  Interruptible multi-step workflow engine
  KaiPlugins/     Plugin protocol, registry, command router, reference plugin
  KaiBrowser/     Skill module: browser automation plugin (Safari/Chrome/Edge)
  KaiApp/         macOS SwiftUI app  (compiled only on macOS via #if os(macOS))
  kai-cli/        Linux/CI-runnable demo that wires the core together
Tests/            XCTest suites for every platform-agnostic module
docs/ARCHITECTURE.md   Design, dependency direction, and trade-offs
PROJECT_STATUS.md · ROADMAP.md · CHANGELOG.md   Project governance
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

| Milestone | Theme | Status |
|-----------|-------|--------|
| 1 | Architecture, plugin framework, permissions, AI seam, memory, automation, UI scaffold | ✅ Done |
| 2 | Observe/Execute mode, Active Window Intelligence, browser automation | ✅ Done |
| 3 | Native macOS shell & Accessibility permissions | ⏳ Next |
| 4 | Screen understanding (Observe deepened) | Planned |
| 5 | Finder automation | Planned |
| 6 | Voice system | Planned |
| 7 | Office automation | Planned |
| 8 | Gmail automation | Planned |
| 9 | Study assistant | Planned |
| 10 | Autonomous workflow engine | Planned |
| 11 | Performance optimization | Planned |
| 12 | Production release | Planned |

See [`ROADMAP.md`](ROADMAP.md) and [`PROJECT_STATUS.md`](PROJECT_STATUS.md) for detail.
