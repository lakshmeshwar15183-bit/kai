import XCTest
@testable import KaiCore

final class StopControllerTests: XCTestCase {
    func testCheckpointThrowsAfterStop() async {
        let controller = StopController()
        await controller.requestStop(.abort)
        let requested = await controller.isStopRequested
        XCTAssertTrue(requested)

        do {
            try await controller.checkpoint()
            XCTFail("checkpoint should throw after stop")
        } catch let error as KaiError {
            XCTAssertEqual(error, .interrupted)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testResetClearsStopAndAdvancesGeneration() async {
        let controller = StopController()
        let g0 = await controller.currentGeneration
        await controller.requestStop()
        let g1 = await controller.reset()
        XCTAssertGreaterThan(g1, g0)
        let requested = await controller.isStopRequested
        XCTAssertFalse(requested)
        // No throw after reset.
        try? await controller.checkpoint()
    }

    func testStopCommandParsing() {
        XCTAssertEqual(StopCommand(utterance: "  Stop "), .stop)
        XCTAssertEqual(StopCommand(utterance: "ABORT"), .abort)
        XCTAssertNil(StopCommand(utterance: "open the door"))
    }
}
