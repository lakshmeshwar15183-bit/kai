import XCTest
@testable import KaiAutomation
import KaiCore

final class WorkflowEngineTests: XCTestCase {
    func testWorkflowCompletesAndPassesData() async {
        let bus = EventBus()
        let stop = StopController()
        let logger = KaiLogger(minimumLevel: .error)
        let engine = WorkflowEngine(eventBus: bus)
        let context = WorkflowContext(stopController: stop, logger: logger)

        let workflow = Workflow(name: "wf", steps: [
            ClosureStep(name: "a") { await $0.set("x", "1") },
            ClosureStep(name: "b") { ctx in
                let x = await ctx.value(forKey: "x")
                await ctx.set("y", (x ?? "") + "2")
            }
        ])

        let outcome = await engine.run(workflow, context: context)
        XCTAssertEqual(outcome, .completed)
        let y = await context.value(forKey: "y")
        XCTAssertEqual(y, "12")
    }

    func testWorkflowInterruptedWhenStopRequested() async {
        let bus = EventBus()
        let stop = StopController()
        let logger = KaiLogger(minimumLevel: .error)
        let engine = WorkflowEngine(eventBus: bus)
        let context = WorkflowContext(stopController: stop, logger: logger)

        // Stop before running; engine should bail at the first checkpoint.
        await stop.requestStop(.stop)

        let workflow = Workflow(name: "wf", steps: [
            ClosureStep(name: "should-not-run") { await $0.set("ran", "true") }
        ])

        let outcome = await engine.run(workflow, context: context)
        XCTAssertEqual(outcome, .interrupted)
        let ran = await context.value(forKey: "ran")
        XCTAssertNil(ran, "no step should run after a stop request")
    }

    func testWorkflowReportsFailure() async {
        let bus = EventBus()
        let stop = StopController()
        let logger = KaiLogger(minimumLevel: .error)
        let engine = WorkflowEngine(eventBus: bus)
        let context = WorkflowContext(stopController: stop, logger: logger)

        let workflow = Workflow(name: "wf", steps: [
            ClosureStep(name: "boom") { _ in throw KaiError.failed(reason: "kaboom") }
        ])

        let outcome = await engine.run(workflow, context: context)
        if case .failed = outcome { /* ok */ } else {
            XCTFail("expected failure outcome, got \(outcome)")
        }
    }
}
