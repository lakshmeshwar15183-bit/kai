# Kai — Personal AI Operating System for macOS

Kai is a privacy-first, native-feeling AI assistant for macOS. It understands
natural-language instructions and safely performs tasks on your Mac. Kai is not
a chatbot: it is a modular operating layer that observes, plans, and acts —
always under your control.

> **Status — 0.4.0 (Final Delivery).** Kai is a modular Swift package plus a
> native SwiftUI macOS app. Delivered: the activation lifecycle and three-tier
> permission model, Observe/Execute mode, Active Window Intelligence, plugin
> framework, provider-agnostic AI with **real OpenAI/Anthropic/Gemini/Ollama**
> clients, privacy-first memory, an interruptible workflow engine with
> retry/undo/dependencies, a redacted audit trail, and skills for **browser**,
> **Finder** (real file ops + undo), **screen understanding/OCR/PDF**, and
> **voice**. The cross-platform core builds and is unit-tested in CI
> (**104 tests**); the SwiftUI shell + OS integrations are complete behind
> `#if os(macOS)` and build into `Kai.app`/`Kai.dmg` on a Mac — see
> [`docs/MACOS_STEPS.md`](docs/MACOS_STEPS.md).

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
  KaiAutomation/  Interruptible workflow engine (+ pause/resume/retry/undo/deps)
  KaiPlugins/     Plugin protocol, registry, command router, reference plugin
  KaiBrowser/     Skill: browser automation (Safari/Chrome/Edge)
  KaiFinder/      Skill: file organize/dedupe/search/rename/move/trash + undo
  KaiVision/      Skill: screen understanding, OCR, PDF reading (read-only)
  KaiVoice/       Skill: wake word, speech recognition/synthesis, session
  KaiApp/         macOS SwiftUI app + composition root (#if os(macOS))
  kai-cli/        Cross-platform demo that wires the core together
  kai-app/        Launchable macOS app entry point
App/              Info.plist, entitlements, AppIcon.svg, asset catalog
Scripts/          build_app.sh, make_dmg.sh, generate_icon.sh
Tests/            XCTest suites for every platform-agnostic module
docs/             ARCHITECTURE.md, MACOS_STEPS.md
PROJECT_STATUS.md · ROADMAP.md · CHANGELOG.md · INSTALL.md · RELEASE_NOTES.md
```

## Build, test, run

The core builds anywhere Swift 6 runs (macOS, Linux, CI):

```bash
swift build         # compile all libraries + executables
swift test          # run the full unit-test suite (104 tests)
swift run kai-cli   # exercise the whole pipeline end-to-end (offline)
make                # list all developer shortcuts
```

On a Mac (macOS 14+, Xcode 16 / Swift 6) you can build and run the app:

```bash
make run-app        # launch the SwiftUI app in development
make app            # build dist/Kai.app
make dmg            # build dist/Kai.dmg installer
```

See [`INSTALL.md`](INSTALL.md) and [`docs/MACOS_STEPS.md`](docs/MACOS_STEPS.md)
for signing, notarization, and AI-provider key setup.

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
| 4 | Final delivery — Finder, screen understanding/OCR/PDF, voice, workflow engine, audit, auto-update, native app + installer | ✅ Done |
| 5+ | Office, Gmail, Study skills; notarized distribution; performance | Planned |

See [`ROADMAP.md`](ROADMAP.md) and [`PROJECT_STATUS.md`](PROJECT_STATUS.md) for detail.
