import Foundation

/// The lifecycle states Kai can be in. These map directly to the status
/// indicator shown in the UI (Sleeping, Listening, Thinking, Working,
/// Waiting for approval, Completed, Stopped).
///
/// Kai is asleep by default and only leaves `.sleeping` in response to an
/// explicit ``ActivationTrigger``.
public enum ActivationState: String, Sendable, Codable, CaseIterable, Equatable {
    /// Default state. No background activity, not listening.
    case sleeping
    /// Actively capturing user input (voice or text).
    case listening
    /// Planning / reasoning about a request.
    case thinking
    /// Executing one or more actions.
    case working
    /// Halted mid-flow, awaiting user confirmation/approval for a guarded action.
    case waitingForApproval
    /// A request finished successfully.
    case completed
    /// A request was explicitly halted by the user (Stop/Pause/Cancel/Abort).
    case stopped

    /// Human-readable label for the UI status indicator.
    public var displayName: String {
        switch self {
        case .sleeping: return "Sleeping"
        case .listening: return "Listening"
        case .thinking: return "Thinking"
        case .working: return "Working"
        case .waitingForApproval: return "Waiting for approval"
        case .completed: return "Completed"
        case .stopped: return "Stopped"
        }
    }

    /// Whether Kai is doing anything other than sleeping. Useful for the UI to
    /// decide if a "stop" affordance should be shown.
    public var isActive: Bool {
        self != .sleeping
    }
}

/// The only ways Kai is permitted to wake from `.sleeping`. There is deliberately
/// no programmatic "auto-wake" — activation is always user-initiated.
public enum ActivationTrigger: String, Sendable, Codable, Equatable {
    /// A configured global keyboard shortcut.
    case shortcut
    /// The microphone button was clicked.
    case microphone
    /// A command was typed into the chat interface.
    case typedCommand
    /// The wake phrase was detected.
    case wakePhrase
}
