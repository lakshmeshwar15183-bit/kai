import Foundation

/// Errors surfaced by the Kai core. Skills and plugins may define their own
/// error types; these cover cross-cutting failures the core itself produces.
public enum KaiError: Error, Sendable, Equatable, CustomStringConvertible {
    /// A state transition was requested that is not allowed from the current state.
    case invalidStateTransition(from: ActivationState, to: ActivationState)
    /// The user halted the operation (Stop/Pause/Cancel/Abort).
    case interrupted
    /// A guarded action was denied by the permission engine or the user.
    case permissionDenied(action: String, level: PermissionLevel)
    /// A side-effecting action was attempted while in Observe (read-only) mode.
    case blockedInObserveMode(action: String)
    /// An attempt was made to persist data that the privacy layer forbids.
    case sensitiveDataRejected(reason: String)
    /// No registered plugin could handle the command.
    case noHandler(command: String)
    /// A requested AI provider is not configured/registered.
    case providerUnavailable(id: String)
    /// A generic, message-bearing failure.
    case failed(reason: String)

    public var description: String {
        switch self {
        case let .invalidStateTransition(from, to):
            return "Invalid state transition from \(from.rawValue) to \(to.rawValue)."
        case .interrupted:
            return "Operation interrupted by the user."
        case let .permissionDenied(action, level):
            return "Permission denied for \(level.displayName) action: \(action)."
        case let .blockedInObserveMode(action):
            return "Blocked in Observe mode (read-only): \(action). Say \"Execute\" to allow actions."
        case let .sensitiveDataRejected(reason):
            return "Sensitive data rejected: \(reason)."
        case let .noHandler(command):
            return "No plugin can handle command: \(command)."
        case let .providerUnavailable(id):
            return "AI provider unavailable: \(id)."
        case let .failed(reason):
            return reason
        }
    }
}
