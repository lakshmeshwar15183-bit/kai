# Kai 0.4.0 — Release Notes

Kai is a privacy-first, native macOS AI operating system: it understands natural
language, observes your screen, and safely operates your Mac under your control.

## Highlights in 0.4.0 (Final Delivery)

- **Finder automation** — organize folders by type, find duplicates (content
  hash), search, rename, move, and move-to-trash with **one-step undo**.
- **Screen understanding** — OCR the screen and read PDFs, with structural
  analysis (headings, error detection). Read-only and Observe-safe.
- **Voice** — wake word, speech recognition and synthesis, with a stop-aware
  session that never keeps listening after you say stop.
- **Workflow engine** — pause, resume, cancel, per-step retry, automatic
  rollback of completed steps on failure, and dependency-ordered execution.
- **Audit trail** — append-only, redacted activity log of everything Kai does.
- **Auto-update architecture** — update checking that never installs silently.
- **Native macOS app** — SwiftUI interface with chat, plugin manager, activity
  log, permission manager, settings (live AI-provider switching), and an
  approval sheet; plus an installer pipeline (`.app` + `.dmg`) and app icon.

## Built on the existing architecture

Everything extends the modular Swift Package from earlier milestones — the
permission engine (Green/Yellow/Red), Observe/Execute mode, Active Window
Intelligence, the plugin framework, provider-agnostic AI (OpenAI/Anthropic/
Gemini/Ollama), privacy-first memory, and the event bus — with **no breaking
changes**.

## Quality

- `swift build` and `swift build -c release`: clean, **zero warnings**.
- `swift test`: **104 tests, 0 failures**.
- `swift run kai-cli`: end-to-end demo of providers, Observe/Execute, browser
  (with login pause), Finder, permissions, and stop/sleep.

## Security & privacy

- Never stores passwords, OTPs, tokens, cards, or keys; logs are redacted.
- API keys live in the Keychain, resolved by reference at call time.
- Every guarded action passes the permission engine; Observe mode is read-only.
- Destructive file actions are reversible (managed trash + undo).

## Platform note

The cross-platform core, skills logic, and AI providers are fully built and
tested in CI. The SwiftUI shell and OS integrations (Accessibility, AppleScript,
ScreenCaptureKit, Vision, Speech, PDFKit, Keychain) are complete and compile/run
on macOS — see [`docs/MACOS_STEPS.md`](docs/MACOS_STEPS.md) to build the `.app`.
