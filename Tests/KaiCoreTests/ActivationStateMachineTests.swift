import XCTest
@testable import KaiCore

final class ActivationStateMachineTests: XCTestCase {
    private func makeMachine() -> (ActivationStateMachine, EventBus, StopController) {
        let bus = EventBus()
        let stop = StopController()
        return (ActivationStateMachine(eventBus: bus, stopController: stop), bus, stop)
    }

    func testStartsSleeping() async {
        let (machine, _, _) = makeMachine()
        let state = await machine.state
        XCTAssertEqual(state, .sleeping)
    }

    func testActivationWakesToListening() async throws {
        let (machine, _, _) = makeMachine()
        try await machine.activate(trigger: .shortcut)
        let state = await machine.state
        XCTAssertEqual(state, .listening)
    }

    func testInvalidTransitionThrows() async {
        let (machine, _, _) = makeMachine()
        // sleeping -> working is not allowed.
        do {
            try await machine.transition(to: .working)
            XCTFail("expected invalid transition to throw")
        } catch let error as KaiError {
            if case .invalidStateTransition = error { /* ok */ } else {
                XCTFail("wrong error: \(error)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testStopMovesToStoppedAndSignalsController() async throws {
        let (machine, _, stop) = makeMachine()
        try await machine.activate(trigger: .microphone)
        try await machine.transition(to: .thinking)
        await machine.stop(.cancel)
        let state = await machine.state
        XCTAssertEqual(state, .stopped)
        let requested = await stop.isStopRequested
        XCTAssertTrue(requested)
    }

    func testSleepFromStopped() async throws {
        let (machine, _, _) = makeMachine()
        try await machine.activate(trigger: .typedCommand)
        await machine.stop()
        try await machine.sleep()
        let state = await machine.state
        XCTAssertEqual(state, .sleeping)
    }
}
