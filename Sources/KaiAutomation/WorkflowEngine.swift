import Foundation
import KaiCore

/// Executes a ``Workflow`` step by step, enforcing interruptibility and emitting
/// lifecycle events.
///
/// Before every step the engine asks the ``StopController`` whether a halt was
/// requested; if so it stops cleanly and reports `.interrupted`. Task
/// cancellation is honoured too, so the engine unwinds whether the user said
/// "Stop" or the surrounding task was cancelled.
public struct WorkflowEngine: Sendable {
    private let eventBus: EventBus

    public init(eventBus: EventBus) {
        self.eventBus = eventBus
    }

    /// The terminal outcome of running a workflow.
    public enum Outcome: Sendable, Equatable {
        case completed
        case interrupted
        case failed(reason: String)
    }

    @discardableResult
    public func run(_ workflow: Workflow, context: WorkflowContext) async -> Outcome {
        await eventBus.publish(KaiEvent(kind: .workflow(.started(workflow: workflow.name))))
        let total = workflow.steps.count

        for (index, step) in workflow.steps.enumerated() {
            // Interruption boundary before each step.
            do {
                try Task.checkCancellation()
                try await context.stopController.checkpoint()
            } catch {
                await emitInterrupted(workflow.name)
                return .interrupted
            }

            await eventBus.publish(KaiEvent(kind: .workflow(
                .stepStarted(workflow: workflow.name, step: step.name, index: index, total: total)
            )))

            do {
                try await step.run(context: context)
            } catch is CancellationError {
                await emitInterrupted(workflow.name)
                return .interrupted
            } catch KaiError.interrupted {
                await emitInterrupted(workflow.name)
                return .interrupted
            } catch {
                let reason = String(describing: error)
                await eventBus.publish(KaiEvent(kind: .workflow(
                    .failed(workflow: workflow.name, reason: reason)
                )))
                return .failed(reason: reason)
            }

            await eventBus.publish(KaiEvent(kind: .workflow(
                .stepFinished(workflow: workflow.name, step: step.name, index: index, total: total)
            )))
        }

        await eventBus.publish(KaiEvent(kind: .workflow(.finished(workflow: workflow.name))))
        return .completed
    }

    private func emitInterrupted(_ name: String) async {
        await eventBus.publish(KaiEvent(kind: .workflow(.interrupted(workflow: name))))
    }
}
