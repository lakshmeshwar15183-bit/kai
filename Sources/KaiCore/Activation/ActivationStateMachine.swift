import Foundation

/// Owns the single source of truth for ``ActivationState`` and enforces legal
/// transitions. All mutations publish a `.stateChanged` event so the UI stays
/// in sync without polling.
///
/// Kai starts `.sleeping`. It only leaves sleep via ``activate(trigger:)``. A
/// stop request can move it to `.stopped` from any active state, and `.stopped`
/// or `.completed` return to `.sleeping` via ``sleep()``.
public actor ActivationStateMachine {
    public private(set) var state: ActivationState = .sleeping

    private let eventBus: EventBus
    private let stopController: StopController

    public init(eventBus: EventBus, stopController: StopController) {
        self.eventBus = eventBus
        self.stopController = stopController
    }

    /// Legal forward transitions. Stop/sleep are handled by dedicated methods.
    private static let allowedTransitions: [ActivationState: Set<ActivationState>] = [
        .sleeping: [.listening],
        .listening: [.thinking, .sleeping, .stopped],
        .thinking: [.working, .waitingForApproval, .completed, .listening, .stopped],
        .working: [.working, .thinking, .waitingForApproval, .completed, .stopped],
        .waitingForApproval: [.working, .thinking, .stopped],
        .completed: [.sleeping, .listening],
        .stopped: [.sleeping, .listening]
    ]

    /// Wakes Kai from sleep. No-op-safe to call when already awake (it simply
    /// moves to `.listening` if the transition is legal).
    public func activate(trigger: ActivationTrigger) async throws {
        await stopController.reset()
        try await transition(to: .listening)
        await eventBus.publish(KaiEvent(kind: .activated(trigger: trigger)))
    }

    /// Performs a validated transition to `next`.
    public func transition(to next: ActivationState) async throws {
        guard Self.allowedTransitions[state]?.contains(next) == true else {
            throw KaiError.invalidStateTransition(from: state, to: next)
        }
        await apply(next)
    }

    /// Immediately halts and moves to `.stopped` from any active state. Also
    /// signals the ``StopController`` so in-flight work unwinds.
    public func stop(_ command: StopCommand = .stop) async {
        await stopController.requestStop(command)
        await eventBus.publish(KaiEvent(kind: .stopRequested(command)))
        if state.isActive {
            await apply(.stopped)
        }
    }

    /// Returns Kai to sleep after a task ends.
    public func sleep() async throws {
        guard state == .completed || state == .stopped || state == .listening else {
            throw KaiError.invalidStateTransition(from: state, to: .sleeping)
        }
        await apply(.sleeping)
    }

    private func apply(_ next: ActivationState) async {
        guard next != state else { return }
        let previous = state
        state = next
        await eventBus.publish(KaiEvent(kind: .stateChanged(from: previous, to: next)))
    }
}
