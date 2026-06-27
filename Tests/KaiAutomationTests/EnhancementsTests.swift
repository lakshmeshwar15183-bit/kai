import XCTest
@testable import KaiAutomation
import KaiCore

final class DependencyGraphTests: XCTestCase {
    func testTopologicalOrderRespectsDependencies() throws {
        var graph = DependencyGraph<String>()
        graph.addDependency("download", dependsOn: "open")
        graph.addDependency("rename", dependsOn: "download")
        graph.addNode("notify")
        let order = try graph.topologicallySorted()
        XCTAssertLessThan(order.firstIndex(of: "open")!, order.firstIndex(of: "download")!)
        XCTAssertLessThan(order.firstIndex(of: "download")!, order.firstIndex(of: "rename")!)
    }

    func testCycleDetection() {
        var graph = DependencyGraph<String>()
        graph.addDependency("a", dependsOn: "b")
        graph.addDependency("b", dependsOn: "a")
        XCTAssertThrowsError(try graph.topologicallySorted()) { error in
            XCTAssertEqual(error as? DependencyError, .cycleDetected)
        }
    }
}

private actor Counter {
    private(set) var value = 0
    func increment() -> Int { value += 1; return value }
}

private struct RecordingUndoable: UndoableStep {
    let name: String
    let onUndo: @Sendable () async -> Void
    func run(context: WorkflowContext) async throws {}
    func undo(context: WorkflowContext) async { await onUndo() }
}

final class PausableWorkflowEngineTests: XCTestCase {
    private func context() -> WorkflowContext {
        WorkflowContext(stopController: StopController(), logger: KaiLogger(minimumLevel: .error))
    }

    func testRetrySucceedsAfterTransientFailures() async {
        let counter = Counter()
        let engine = PausableWorkflowEngine(eventBus: EventBus(), retryPolicy: RetryPolicy(maxAttempts: 3))
        let workflow = Workflow(name: "retry", steps: [
            ClosureStep(name: "flaky") { _ in
                let attempt = await counter.increment()
                if attempt < 3 { throw KaiError.failed(reason: "transient") }
            }
        ])
        let outcome = await engine.run(workflow, context: context())
        XCTAssertEqual(outcome, .completed)
    }

    func testRollbackUndoesCompletedStepsOnFailure() async {
        let undone = Counter()
        let engine = PausableWorkflowEngine(eventBus: EventBus(), rollbackOnFailure: true)
        let workflow = Workflow(name: "rollback", steps: [
            RecordingUndoable(name: "first") { _ = await undone.increment() },
            ClosureStep(name: "boom") { _ in throw KaiError.failed(reason: "fail") }
        ])
        let outcome = await engine.run(workflow, context: context())
        if case .failed = outcome {} else { XCTFail("expected failure") }
        let undoCount = await undone.value
        XCTAssertEqual(undoCount, 1, "completed undoable step should be rolled back")
    }

    func testCancelBeforeRunInterrupts() async {
        let engine = PausableWorkflowEngine(eventBus: EventBus())
        await engine.cancel()
        let workflow = Workflow(name: "c", steps: [ClosureStep(name: "x") { _ in }])
        let outcome = await engine.run(workflow, context: context())
        XCTAssertEqual(outcome, .interrupted)
    }
}
