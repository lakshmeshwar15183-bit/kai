import XCTest
@testable import KaiCore

final class PermissionEngineTests: XCTestCase {
    private let engine = PermissionEngine()

    func testInfersGreenForSafeActions() {
        XCTAssertEqual(engine.inferLevel(forAction: "open Safari"), .green)
        XCTAssertEqual(engine.inferLevel(forAction: "summarize this page"), .green)
    }

    func testInfersYellowForReversibleActions() {
        XCTAssertEqual(engine.inferLevel(forAction: "delete the screenshots"), .yellow)
        XCTAssertEqual(engine.inferLevel(forAction: "rename report.pdf"), .yellow)
    }

    func testInfersRedForDangerousActions() {
        XCTAssertEqual(engine.inferLevel(forAction: "open my banking site"), .red)
        XCTAssertEqual(engine.inferLevel(forAction: "enter the OTP"), .red)
        XCTAssertEqual(engine.inferLevel(forAction: "make a payment"), .red)
    }

    func testEscalatesNeverDeescalates() {
        // Declared green, but text mentions password -> effective red.
        let level = engine.effectiveLevel(forAction: "type my password", declared: .green)
        XCTAssertEqual(level, .red)

        // Declared red, harmless text -> stays red.
        let stillRed = engine.effectiveLevel(forAction: "hello", declared: .red)
        XCTAssertEqual(stillRed, .red)
    }

    func testAuthorizeAllowsGreenSilently() async {
        let granted = await engine.authorize(action: "open Finder", declared: .green, using: DenyingPrompter())
        XCTAssertTrue(granted, "Green actions should not require prompting")
    }

    func testAuthorizeConsultsPrompterForGuardedActions() async {
        let approving = ApprovingPrompter()
        let granted = await engine.authorize(action: "delete files", declared: .green, using: approving)
        XCTAssertTrue(granted)

        let denied = await engine.authorize(action: "delete files", declared: .green, using: DenyingPrompter())
        XCTAssertFalse(denied)
    }
}

struct ApprovingPrompter: PermissionPrompting {
    func requestDecision(action: String, level: PermissionLevel) async -> Bool { true }
}
