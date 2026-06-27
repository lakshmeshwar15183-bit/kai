import Foundation

/// Whether Kai is allowed to *act* or may only *understand*.
///
/// In `.observe` mode Kai analyses whatever is visible — pages, PDFs,
/// spreadsheets, code, errors — and answers questions, but it never clicks,
/// types, or performs any action with side effects. Automation resumes only
/// after the user explicitly switches to `.execute`.
public enum InteractionMode: String, Sendable, Codable, CaseIterable, Equatable {
    /// Read-only. Side-effecting capabilities are blocked.
    case observe
    /// Normal operation. Side effects are allowed, still subject to permissions.
    case execute

    public var displayName: String {
        switch self {
        case .observe: return "Observe"
        case .execute: return "Execute"
        }
    }

    /// Recognises the standalone "Observe" / "Execute" mode-switch utterances.
    public init?(modeUtterance: String) {
        let normalized = modeUtterance.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "observe": self = .observe
        case "execute": self = .execute
        default: return nil
        }
    }
}

/// Owns the current ``InteractionMode``. Kai operates in `.execute` by default;
/// saying "Observe" enters read-only mode and "Execute" leaves it. The
/// controller publishes a `.modeChanged` event so the UI can reflect the mode.
public actor ModeController {
    public private(set) var mode: InteractionMode
    private let eventBus: EventBus?

    public init(mode: InteractionMode = .execute, eventBus: EventBus? = nil) {
        self.mode = mode
        self.eventBus = eventBus
    }

    @discardableResult
    public func setMode(_ newMode: InteractionMode) async -> Bool {
        guard newMode != mode else { return false }
        mode = newMode
        await eventBus?.publish(KaiEvent(kind: .modeChanged(newMode)))
        return true
    }

    public var isObserving: Bool { mode == .observe }
}
