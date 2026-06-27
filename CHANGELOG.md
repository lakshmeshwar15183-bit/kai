# Changelog

All notable changes to Kai are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project aims
to follow Semantic Versioning.

## [0.3.0] — Milestone 3: AI Provider Layer

### Added
- **`KaiAIProviders` module** (depends only on `KaiAI`) delivering real,
  swappable AI backends behind the existing `AIProvider`/`AIProviderFactory`
  seam — switching vendor is configuration-only:
  - **OpenAI** (Chat Completions), **Anthropic** (Messages, with system
    hoisting), **Google Gemini** (`generateContent`), and **Ollama** (local,
    no key) providers, each with a factory.
  - **`HTTPTransport` seam**: `URLSessionTransport` (dataTask + continuation,
    identical on macOS/Linux) for production and a request-recording
    `MockTransport` actor for deterministic tests.
  - **`SecretResolver` seam**: `EnvironmentSecretResolver` and
    `StaticSecretResolver`, plus a macOS `KeychainSecretResolver`
    (`#if os(macOS)`). API keys are resolved by reference at call time and
    never stored in config or logs.
  - `AIProviderError` (module-local — the shared `KaiError` was intentionally
    left untouched) and `ProviderBootstrap.registerDefaults(...)`.
- 12 new tests (74 total): mock transport, secret resolution, per-provider
  request shaping + response parsing, HTTP/decoding error mapping, and registry
  integration proving config-only provider switching.
- CLI demo section showing provider listing and an offline completion through a
  selected provider.

### Notes
- `MockTransport` returns `Data` (Sendable) rather than `[String: Any]` to stay
  within Swift 6 actor-isolation rules; tests decode bodies locally.

## [0.2.0] — Milestone 2: Observe/Execute, Active Window Intelligence, Browser

### Added
- **Observe/Execute mode** in `KaiCore`: `InteractionMode` and the
  `ModeController` actor. Observe mode is read-only; the router blocks any
  capability with side effects until the user switches to Execute. New
  `KaiEvent.modeChanged` and `KaiError.blockedInObserveMode`.
- **Active Window Intelligence** in `KaiCore`: `ApplicationContext`,
  `ActiveApplicationProvider` (+ `StubActiveApplicationProvider`), and
  `KnownApplication` bundle identifiers. `PluginRegistry.handler(for:in:)`
  prefers the plugin that specialises in the frontmost application.
- **`KaiBrowser` module**: `BrowserController` protocol, page model
  (`PageSnapshot`/`PageElement`), `LoginDetector`, `BrowserCommandParser`
  (`BrowserIntent`), `InMemoryBrowserController` (test/CLI driver with
  simulated authentication), and `BrowserPlugin` (open/navigate/scroll/click/
  fill/read/summarize/wait-for-login). The plugin pauses on login pages and
  never enters credentials. macOS `AppleScriptBrowserController` scaffolded
  (`#if os(macOS)`).
- 29 new tests (62 total) covering mode gating, app-aware routing, login
  detection, command parsing, the in-memory driver, and the browser plugin.
- Governance docs: `PROJECT_STATUS.md`, `ROADMAP.md`, this changelog.

### Changed
- `Capability` gained a defaulted `sideEffect` flag; `Plugin` gained a defaulted
  `supportedApplications`; `CommandRouter` gained optional `modeController` and
  `activeApplicationProvider` parameters. **All additions are backward
  compatible** — no existing call site changed.
- `ConversationPlugin`'s chat capability is marked read-only so it remains
  available in Observe mode.

### Notes
- Inserting an enum case mid-list changes the type's in-memory layout; a clean
  build (`swift package clean`) is required to avoid stale incremental artifacts.

## [0.1.0] — Milestone 1: Foundations

### Added
- Modular Swift Package: `KaiCore`, `KaiAI`, `KaiMemory`, `KaiAutomation`,
  `KaiPlugins`, `KaiApp` (macOS), and the `kai-cli` demo.
- Activation state machine; three-tier permission engine (Green/Yellow/Red,
  escalate-only); cooperative stop controller; event bus; redacting logger;
  sensitive-data redactor.
- Provider-agnostic AI seam (`AIProvider` + registry + echo provider);
  privacy-first memory (in-memory + atomic JSON, secret-rejecting);
  interruptible workflow engine; plugin framework + command router.
- macOS SwiftUI scaffold and 33 unit tests.
