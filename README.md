# Kai — Personal AI Operating System for macOS

Kai is a privacy-first, native-feeling AI assistant for macOS. It understands
natural-language instructions and safely performs tasks on your Mac. Kai is not
a chatbot: it is a modular operating layer that observes, plans, and acts —
always under your control.

> **Status — Milestone 3 (AI Provider Layer).**
> Milestone 1 delivered the modular architecture; Milestone 2 added Observe/
> Execute mode, Active Window Intelligence, and the first skill module (browser
> automation). Milestone 3 adds **real, swappable AI providers** — OpenAI,
> Anthropic, Gemini, and local Ollama — behind the existing provider seam, with
> an HTTP-transport seam and a secret resolver so switching vendor is
> configuration-only and API keys never touch config or logs. The
> platform-agnostic core **builds and is unit-tested on Linux/CI** (74 tests);
> the macOS UI and OS-specific code are scaffolded behind `#if os(macOS)` and
> land fully in later milestones.

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
  KaiAIProviders/ Real providers: OpenAI, Anthropic, Gemini, Ollama (+ HTTP &
                  secret-resolver seams)
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
| 3 | AI Provider layer (OpenAI, Anthropic, Gemini, Ollama) | ✅ Done |
| 4 | Native macOS shell & Accessibility permissions | ⏳ Next |
| 5 | Screen understanding (Observe deepened) | Planned |
| 6 | Finder automation | Planned |
| 7 | Voice system | Planned |
| 8 | Office automation | Planned |
| 9 | Gmail automation | Planned |
| 10 | Study assistant | Planned |
| 11 | Autonomous workflow engine | Planned |
| 12 | Performance optimization | Planned |
| 13 | Production release | Planned |

See [`ROADMAP.md`](ROADMAP.md) and [`PROJECT_STATUS.md`](PROJECT_STATUS.md) for detail.
