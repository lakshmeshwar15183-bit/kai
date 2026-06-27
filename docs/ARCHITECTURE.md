# Kai Architecture

This document explains the design of Kai's foundation, the reasoning behind each
decision, and the trade-offs accepted. It is kept current as milestones land
(latest: Milestone 3 — the AI Provider layer).

## 1. Goals that shape the architecture

Kai must be modular, extensible, fast, secure, privacy-first, native-feeling on
macOS, and easy to extend with plugins — and it must support years of evolution
without becoming a pile of scripts. Concretely the architecture must guarantee:

1. **User control** — asleep by default; activates only on explicit triggers;
   any of Stop/Pause/Cancel/Abort halts everything immediately.
2. **Safety by construction** — a three-tier (Green/Yellow/Red) permission model
   that cannot be bypassed.
3. **Privacy by construction** — secrets are never persisted or logged.
4. **Replaceable AI** — switching provider is a configuration change, not a code
   change.
5. **Extensibility** — every capability is a plugin added without modifying core.

## 2. Module boundaries and dependency direction

The system is a Swift Package split into independent modules with a strictly
downward dependency graph (no cycles):

```
                       KaiCore
              (no dependencies; pure domain)
            ┌──────────────┼──────────────┐
          KaiAI        KaiMemory      KaiAutomation
            │
       KaiAIProviders  (real OpenAI/Anthropic/Gemini/Ollama)
            └──────────────┼──────────────┐
                       KaiPlugins
                           │
                       KaiBrowser  (skill module)
            ┌──────────────┴──────────────┐
         KaiApp (macOS only)            kai-cli (any platform)
```

- **KaiCore** has no dependencies. It owns the domain primitives every other
  module relies on: the activation state machine, the **interaction mode
  controller (Observe/Execute)**, the permission engine, the stop controller,
  the event bus, the logger, the sensitive-data redactor, and the **active
  application abstraction**.
- **KaiAI / KaiMemory / KaiAutomation** are independent siblings that depend
  only on KaiCore. They never depend on each other, which keeps them swappable
  and independently testable.
- **KaiAIProviders** depends only on `KaiAI`. It supplies concrete provider
  clients behind the `AIProvider`/`AIProviderFactory` seam, so vendors are added
  or switched without touching any consumer.
- **KaiPlugins** sits on top and composes the lower layers into the plugin
  contract and command router — the single extensibility seam.
- **KaiBrowser** is the first *skill module*: a self-contained capability built
  on KaiPlugins. Future skills (Finder, Office, Gmail, Study) follow this exact
  shape — a new module depending on KaiPlugins, never modifying the core.
- **KaiApp** (SwiftUI) and **kai-cli** (demo/CI) are leaf "drivers" that wire the
  pieces together. Nothing depends on them.

**Trade-off:** more modules mean more boilerplate (`Package.swift` targets,
explicit `public` surfaces) than a single app target. We accept this because the
boundaries enforce the dependency direction at compile time and make each piece
unit-testable in isolation.

## 3. Cross-platform strategy (Linux core, macOS surface)

Kai targets macOS, but the development/CI sandbox is Linux without
AppKit/SwiftUI. To keep a single `swift build` working everywhere:

- All platform-agnostic logic lives in modules that compile on any Swift
  platform and are covered by XCTest.
- macOS-only code (the SwiftUI UI, and later the Accessibility/AppleScript-based
  skills) is wrapped in `#if os(macOS)`. On Linux these files compile to nothing;
  on macOS they are first-class.
- A `kai-cli` executable exercises the full core pipeline on Linux/CI, acting as
  living documentation and a smoke test.

**Trade-off:** the GUI cannot be run or compile-checked on Linux. We mitigate
this by keeping *all behaviour* in testable core modules and reducing the UI to a
thin, declarative projection of observable state.

## 4. Concurrency model

The package builds in Swift 6 language mode with full strict-concurrency
checking. The rules we follow:

- **Mutable shared state lives in `actor`s**: `ActivationStateMachine`,
  `StopController`, `EventBus`, `KaiLogger`, `PluginRegistry`, `AIProviderRegistry`,
  the memory stores, and `WorkflowContext`.
- **Models are `Sendable` value types** (`enum`/`struct`): states, events,
  permission levels, AI messages, manifests, commands.
- **Protocols crossing actor boundaries are `Sendable`** (`AIProvider`,
  `Plugin`, `MemoryStore`, `PermissionPrompting`, `LogSink`).

This gives data-race safety at compile time, which matters for a long-lived
assistant juggling voice, UI, and background automation.

## 5. Key components

### Activation lifecycle (`ActivationStateMachine`)
A validated state machine over `ActivationState` (sleeping → listening →
thinking → working/waitingForApproval → completed/stopped). Kai leaves
`.sleeping` only via `activate(trigger:)`. Every transition publishes a
`.stateChanged` event so the UI status indicator stays in sync without polling.

### Stop semantics (`StopController`)
Stop/Pause/Cancel/Abort are treated identically: they set a cooperative
cancellation flag. Long-running work calls `checkpoint()` at interruption
boundaries. A monotonic *generation* counter ensures a `reset()` for a new task
cannot be confused with a stale stop from the previous one.

### Permission model (`PermissionEngine`)
Each action's **effective** level is `max(declared, inferred)` — the engine
scans the action text for Red signals (banking, password, OTP, payment, system
settings, sudo…) and Yellow signals (delete, move, upload, send email…). A
plugin therefore can never *under*-classify a dangerous action. Green is allowed
silently; Yellow/Red route through an injected `PermissionPrompting` (a dialog in
the app, scripted in tests). The default prompter denies, so "fail closed."

### Privacy (`SensitiveDataRedactor`)
A single primitive used in two ways: `classify(key:value:)` lets the memory
layer **reject** sensitive writes, and `redact(_:)` scrubs free-form text before
logging. Enforcement lives in the store and logger, not in callers — so a
careless caller cannot leak a secret.

### AI seam (`AIProvider` / `AIProviderRegistry` / `AIProviderConfig`)
One protocol abstracts every model vendor. Providers are built from config by
registered factories, so adding OpenAI/Anthropic/Gemini/local means registering
a factory — call sites never change. API keys are referenced by Keychain name in
config, never stored inline.

### AI providers (`KaiAIProviders`)
Concrete clients live in their own module so `KaiAI` stays a pure abstraction.
Two seams keep them production-grade and testable:
- **`HTTPTransport`** — providers build a `HTTPRequest` and hand it to a
  transport. `URLSessionTransport` (dataTask + continuation; behaves the same on
  macOS and Linux) is production; `MockTransport` records requests and returns
  canned responses so every provider is unit-tested offline.
- **`SecretResolver`** — API keys are resolved from a *reference* at call time
  (`EnvironmentSecretResolver` in CI, `KeychainSecretResolver` on macOS), so
  credentials never enter config files, the memory store, or logs.
OpenAI, Anthropic (system hoisting), Gemini (key in query, assistant→model
role), and Ollama (local, keyless) are implemented, each with a factory.
`ProviderBootstrap.registerDefaults` wires them into the registry in one call.

### Memory (`MemoryStore`)
A protocol with an `InMemoryStore` and an atomic `JSONFileStore`. Both apply the
privacy guard. Only allowed preferences (folders, browsers, editors, workflows)
are ever written.

### Automation (`WorkflowEngine`)
Runs an ordered list of `WorkflowStep`s, checking the stop controller and task
cancellation before each step, and emitting `started/stepStarted/stepFinished/
finished/interrupted/failed` events. Every step is interruptible.

### Plugins (`Plugin` / `PluginRegistry` / `CommandRouter`)
A plugin declares a `PluginManifest` (capabilities + default permission levels)
and implements `handle(_:services:)`. The `CommandRouter` is the choke point: it
intercepts stop words, honours pending stops, finds a handler, enforces the
permission gate (emitting permission events), then executes with injected
`PluginServices`. New capabilities are added purely by registering a plugin.

### Observe/Execute mode (`ModeController`)
Kai operates in `.execute` by default. Saying "Observe" switches to a read-only
mode in which the router refuses any capability whose `sideEffect` is `true`
(clicks, typing, file/email/network mutations), while read-only capabilities
(read, summarize, answer) still run. "Execute" returns to normal operation.
This is the foundation for screen understanding: Kai can analyse everything
visible without touching anything until explicitly told to act.

### Active Window Intelligence (`ApplicationContext` / `ActiveApplicationProvider`)
The router asks an `ActiveApplicationProvider` for the frontmost application and
prefers the plugin that declares it in `supportedApplications`. On macOS the
provider is backed by `NSWorkspace`; tests and the CLI use a stub. This lets the
same command ("read the page", "click Submit") resolve to the right skill based
on what the user is actually looking at.

### Browser skill (`KaiBrowser`)
The first skill module, and the template for all future skills. A
`BrowserController` protocol abstracts the driver (Safari/Chrome/Edge via
AppleScript + injected JavaScript on macOS; an in-memory fake for tests). The
platform-agnostic pieces — `BrowserCommandParser` (text → `BrowserIntent`),
`LoginDetector`, and `BrowserPlugin` — are fully unit-tested. Safety properties:
read/summarize are read-only (available in Observe); click/fill are Yellow;
anything mentioning passwords/OTP escalates to Red; on a detected login page the
plugin pauses and asks the user to authenticate and **never types credentials or
fills secure fields**.

## 6. Testing

Every platform-agnostic module has an XCTest suite (74 tests as of Milestone 3)
covering permission inference/escalation, stop/interruption, state transitions,
redaction, the event bus, provider registry, memory rejection of secrets,
workflow completion/interruption/failure, and end-to-end command routing
including denial of Red actions. `swift test` runs them on Linux/CI.

## 7. What is intentionally deferred

Voice, screen understanding, and the remaining macOS skills (Finder, Gmail,
Office, Study) are later milestones. They slot into the existing seams —
`AIProviderFactory` for vendors (already realised by `KaiAIProviders`) and
`Plugin`/skill-module for capabilities (as `KaiBrowser` demonstrates) — without
changing the core. Streaming completions (SSE) build on the existing
`AIProvider.stream` default and the `HTTPTransport` seam.
