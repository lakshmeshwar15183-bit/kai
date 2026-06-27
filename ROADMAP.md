# Kai — Roadmap

Milestones follow the project's priority order. Each milestone is completed —
designed, implemented, tested, documented, committed — before the next begins.
The platform-agnostic logic of every milestone is built and tested on CI; macOS
surfaces are finished in Xcode on a Mac.

| # | Milestone | Status |
|---|-----------|--------|
| 1 | **Foundations** — architecture, permissions, plugins, AI seam, memory, automation, UI scaffold | ✅ Done |
| 2 | **Observe/Execute mode · Active Window Intelligence · Browser automation** | ✅ Done |
| 3 | **AI Provider layer** — real OpenAI/Anthropic/Gemini/Ollama behind the seam; HTTP transport + secret resolver | ✅ Done |
| 4 | **Final delivery** — Finder automation, screen understanding (OCR/PDF), voice, workflow engine (pause/resume/retry/undo/deps), audit trail, auto-update architecture, native SwiftUI app + installer | ✅ Done |
| — | **macOS hardening** (on-device) — finish Accessibility-based app control beyond AppleScript, notarized distribution, deeper ScreenCaptureKit window targeting | ⏳ Ongoing (macOS) |
| 5 | **Office automation** — Excel/Word/PowerPoint/PDF generation, charts, tables | Planned |
| 6 | **Gmail automation** — search, label, archive, delete spam/OTP, draft (never send without confirmation) | Planned |
| 7 | **Study assistant** — organize material, rename PDFs, syllabus tracking, revision notes, flashcards, dashboard | Planned |
| 8 | **Autonomous workflow expansion** — richer long-running flows, scheduling | Planned |
| 9 | **Performance optimization** | Planned |
| 10 | **Production release** — Developer ID notarization, auto-update backend | Planned |

> **Sequencing note.** The AI Provider layer was brought forward ahead of the
> macOS shell because it is a first-class requirement that is fully verifiable in
> CI. The final-delivery milestone implemented the remaining skills and the
> native app; macOS-only surfaces are written in full behind `#if os(macOS)` and
> are built/run on a Mac (see `docs/MACOS_STEPS.md`).

## Design principles carried through every milestone

- Asleep by default; user-initiated activation only; Stop/Pause/Cancel/Abort
  halts everything immediately.
- Three-tier permissions (Green/Yellow/Red) enforced at the router; the engine
  can only escalate risk, never lower it.
- Privacy first: never persist passwords/OTP/tokens; redact logs; audit trail.
- Every capability is a plugin/module; the core never changes to add one.
- AI provider is replaceable by configuration alone.
- Swift 6 concurrency: actors for shared mutable state, `Sendable` models.
