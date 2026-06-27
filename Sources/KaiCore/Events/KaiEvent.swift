import Foundation

/// A timestamped, structured event emitted by the core. The UI subscribes to
/// these to reactively render the status indicator, activity log, and approval
/// prompts without polling.
public struct KaiEvent: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let kind: Kind

    public init(id: UUID = UUID(), timestamp: Date = Date(), kind: Kind) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
    }

    public enum Kind: Sendable, Equatable {
        /// The activation state changed.
        case stateChanged(from: ActivationState, to: ActivationState)
        /// Kai woke up due to a trigger.
        case activated(trigger: ActivationTrigger)
        /// The user requested a halt.
        case stopRequested(StopCommand)
        /// A guarded action is awaiting user decision.
        case permissionRequested(action: String, level: PermissionLevel)
        /// A guarded action decision was resolved.
        case permissionResolved(action: String, granted: Bool)
        /// A workflow/step lifecycle update.
        case workflow(WorkflowEvent)
        /// A structured log line.
        case log(level: LogLevel, message: String)
    }

    /// Workflow lifecycle signals carried over the event bus.
    public enum WorkflowEvent: Sendable, Equatable {
        case started(workflow: String)
        case stepStarted(workflow: String, step: String, index: Int, total: Int)
        case stepFinished(workflow: String, step: String, index: Int, total: Int)
        case finished(workflow: String)
        case failed(workflow: String, reason: String)
        case interrupted(workflow: String)
    }
}
