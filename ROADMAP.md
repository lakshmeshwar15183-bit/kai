# Kai — Roadmap

Milestones follow the project's priority order. Each milestone is completed —
designed, implemented, tested, documented, committed — before the next begins.
The platform-agnostic logic of every milestone is built and tested on CI; macOS
surfaces are finished in Xcode on a Mac.

| # | Milestone | Status |
|---|-----------|--------|
| 1 | **Foundations** — architecture, permissions, plugins, AI seam, memory, automation, UI scaffold | ✅ Done |
| 2 | **Observe/Execute mode · Active Window Intelligence · Browser automation** | ✅ Done |
| 3 | **Native macOS shell & Accessibility permissions** — real app target, permission onboarding, status menu, global shortcut, `NSWorkspace` active-app provider | ⏳ Next |
| 4 | **Screen understanding** — ScreenCaptureKit + Vision; Observe mode reads PDFs (PDFKit), spreadsheets, code, errors, dashboards | Planned |
| 5 | **Finder automation** — search, rename, organize, move, dedupe, compress, restore, downloads intelligence | Planned |
| 6 | **Voice system** — Speech (recognition + synthesis), wake word, interruptions, sleep/stop | Planned |
| 7 | **Office automation** — Excel/Word/PowerPoint/PDF generation, charts, tables, formatting | Planned |
| 8 | **Gmail automation** — search, label, archive, delete spam/OTP, draft (never send without confirmation) | Planned |
| 9 | **Study assistant** — organize material, rename PDFs, syllabus tracking, revision notes, flashcards, dashboard | Planned |
| 10 | **Autonomous workflow engine** — long multi-step flows with pause/resume/cancel/retry/undo | Planned |
| 11 | **Performance optimization** | Planned |
| 12 | **Production release** | Planned |

## Design principles carried through every milestone

- Asleep by default; user-initiated activation only; Stop/Pause/Cancel/Abort
  halts everything immediately.
- Three-tier permissions (Green/Yellow/Red) enforced at the router; the engine
  can only escalate risk, never lower it.
- Privacy first: never persist passwords/OTP/tokens; redact logs; audit trail.
- Every capability is a plugin/module; the core never changes to add one.
- AI provider is replaceable by configuration alone.
- Swift 6 concurrency: actors for shared mutable state, `Sendable` models.
