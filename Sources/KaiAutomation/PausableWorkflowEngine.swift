import Foundation
import KaiCore

/// A workflow step that knows how to reverse itself, enabling rollback/undo.
public protocol UndoableStep: WorkflowStep {
    func undo(context: WorkflowContext) async
}

/// An executor that adds pause/resume/cancel, per-step retry, progress
/// reporting, and automatic rollback of completed undoable steps on failure.
///
/// It complements (does not replace) ``WorkflowEngine``: use the simple engine
/// for fire-and-forget flows, and this one for long-running, controllable work.
public actor PausableWorkflowEngine {
    public enum ControlState: Sendable, Equatable {
        case idle, running, paused, cancelling, finished
    }

    private let eventBus: EventBus
    private let retryPolicy: RetryPolicy
    private let rollbackOnFailure: Bool
    private let pausePollInterval: Duration

    public private(set) var controlState: ControlState = .idle

    public init(
        eventBus: EventBus,
        retryPolicy: RetryPolicy = .none,
        rollbackOnFailure: Bool = true,
        pausePollInterval: Duration = .milliseconds(20)
    ) {
        self.eventBus = eventBus
        self.retryPolicy = retryPolicy
        self.rollbackOnFailure = rollbackOnFailure
        self.pausePollInterval = pausePollInterval
    }

    // MARK: - Controls (callable while a run is in flight via actor reentrancy)

    public func pause() { if controlState == .running { controlState = .paused } }
    public func resume() { if controlState == .paused { controlState = .running } }
    public func cancel() { controlState = .cancelling }

    // MARK: - Execution

    @discardableResult
    public func run(_ workflow: Workflow, context: WorkflowContext) async -> WorkflowEngine.Outcome {
        // A cancel requested before the run starts is honoured immediately.
        if controlState == .cancelling {
            controlState = .idle
            await emit(.interrupted(workflow: workflow.name))
            return .interrupted
        }
        controlState = .running
        await eventBus.publish(KaiEvent(kind: .workflow(.started(workflow: workflow.name))))
        let total = workflow.steps.count
        var completedUndoables: [any UndoableStep] = []

        for (index, step) in workflow.steps.enumerated() {
            // Honour pause, cancel, and external stop before each step.
            do {
                try await waitWhilePausedOrThrow(context: context)
            } catch {
                await rollbackIfNeeded(&completedUndoables, context: context)
                await emit(.interrupted(workflow: workflow.name))
                return .interrupted
            }

            await eventBus.publish(KaiEvent(kind: .workflow(
                .stepStarted(workflow: workflow.name, step: step.name, index: index, total: total)
            )))

            do {
                try await runWithRetry(step, context: context)
            } catch is CancellationError {
                await rollbackIfNeeded(&completedUndoables, context: context)
                await emit(.interrupted(workflow: workflow.name))
                return .interrupted
            } catch KaiError.interrupted {
                await rollbackIfNeeded(&completedUndoables, context: context)
                await emit(.interrupted(workflow: workflow.name))
                return .interrupted
            } catch {
                await rollbackIfNeeded(&completedUndoables, context: context)
                let reason = String(describing: error)
                await emit(.failed(workflow: workflow.name, reason: reason))
                controlState = .finished
                return .failed(reason: reason)
            }

            if let undoable = step as? any UndoableStep { completedUndoables.append(undoable) }
            await eventBus.publish(KaiEvent(kind: .workflow(
                .stepFinished(workflow: workflow.name, step: step.name, index: index, total: total)
            )))
        }

        await emit(.finished(workflow: workflow.name))
        controlState = .finished
        return .completed
    }

    // MARK: - Helpers

    private func runWithRetry(_ step: WorkflowStep, context: WorkflowContext) async throws {
        var attempt = 0
        while true {
            attempt += 1
            do {
                try await context.stopController.checkpoint()
                try await step.run(context: context)
                return
            } catch let error as KaiError where error == .interrupted {
                throw error
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if attempt >= retryPolicy.maxAttempts { throw error }
                await context.logger.warning("Step \"\(step.name)\" failed (attempt \(attempt)); retrying.")
                if retryPolicy.delay > .zero { try? await Task.sleep(for: retryPolicy.delay) }
            }
        }
    }

    private func waitWhilePausedOrThrow(context: WorkflowContext) async throws {
        while true {
            if controlState == .cancelling { throw KaiError.interrupted }
            try await context.stopController.checkpoint()
            try Task.checkCancellation()
            if controlState != .paused { return }
            try await Task.sleep(for: pausePollInterval)
        }
    }

    private func rollbackIfNeeded(_ completed: inout [any UndoableStep], context: WorkflowContext) async {
        guard rollbackOnFailure else { return }
        for step in completed.reversed() {
            await step.undo(context: context)
        }
        completed.removeAll()
    }

    private func emit(_ event: KaiEvent.WorkflowEvent) async {
        await eventBus.publish(KaiEvent(kind: .workflow(event)))
    }
}
