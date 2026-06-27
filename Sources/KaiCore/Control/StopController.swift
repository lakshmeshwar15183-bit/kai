import Foundation

/// The words that immediately halt all activity. They are treated identically:
/// any of them stops everything Kai is doing.
public enum StopCommand: String, Sendable, Codable, CaseIterable, Equatable {
    case stop
    case pause
    case cancel
    case abort

    /// Parses a free-form utterance into a stop command, if it is one.
    public init?(utterance: String) {
        let normalized = utterance.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let command = StopCommand(rawValue: normalized) else { return nil }
        self = command
    }
}

/// A cooperative cancellation signal shared across the activation state machine
/// and the automation engine. Long-running work must call ``checkpoint()`` (or
/// inspect ``isStopRequested``) between steps so the user can halt Kai at any
/// moment.
///
/// A monotonically increasing generation is used so that a `reset()` for a new
/// task cannot be confused with a stale stop from a previous one.
public actor StopController {
    private var stopRequested = false
    private var lastCommand: StopCommand?
    private var generation: Int = 0

    public init() {}

    /// Requests that all current activity halt. Idempotent within a generation.
    public func requestStop(_ command: StopCommand = .stop) {
        stopRequested = true
        lastCommand = command
    }

    /// Clears the stop flag and begins a new generation for the next task.
    /// Returns the new generation token.
    @discardableResult
    public func reset() -> Int {
        stopRequested = false
        lastCommand = nil
        generation += 1
        return generation
    }

    public var isStopRequested: Bool { stopRequested }
    public var lastStopCommand: StopCommand? { lastCommand }
    public var currentGeneration: Int { generation }

    /// Throws ``KaiError/interrupted`` if a stop has been requested. Call this
    /// at the boundaries of interruptible work.
    public func checkpoint() throws {
        if stopRequested {
            throw KaiError.interrupted
        }
    }
}
