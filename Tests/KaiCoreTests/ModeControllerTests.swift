import XCTest
@testable import KaiCore

final class ModeControllerTests: XCTestCase {
    func testDefaultsToExecute() async {
        let controller = ModeController()
        let mode = await controller.mode
        XCTAssertEqual(mode, .execute)
        let observing = await controller.isObserving
        XCTAssertFalse(observing)
    }

    func testSwitchingModesPublishesEvent() async {
        let bus = EventBus()
        let stream = await bus.subscribe()
        let controller = ModeController(mode: .execute, eventBus: bus)

        let received = Task { () -> InteractionMode? in
            for await event in stream {
                if case let .modeChanged(mode) = event.kind { return mode }
            }
            return nil
        }

        await controller.setMode(.observe)
        let observing = await controller.isObserving
        XCTAssertTrue(observing)
        let mode = await received.value
        XCTAssertEqual(mode, .observe)
    }

    func testModeUtteranceParsing() {
        XCTAssertEqual(InteractionMode(modeUtterance: " Observe "), .observe)
        XCTAssertEqual(InteractionMode(modeUtterance: "EXECUTE"), .execute)
        XCTAssertNil(InteractionMode(modeUtterance: "do something"))
    }
}
