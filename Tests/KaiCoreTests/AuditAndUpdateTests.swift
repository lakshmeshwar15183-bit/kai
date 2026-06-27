import XCTest
@testable import KaiCore

final class AuditTrailTests: XCTestCase {
    func testRecordsAndRedacts() async {
        let trail = AuditTrail(capacity: 10)
        await trail.record(category: "permission", "approved action with code 482913")
        let recent = await trail.recent()
        XCTAssertEqual(recent.count, 1)
        XCTAssertFalse(recent.first!.message.contains("482913"), "OTP-like value must be redacted")
        XCTAssertEqual(recent.first!.category, "permission")
    }

    func testCapacityTrims() async {
        let trail = AuditTrail(capacity: 3)
        for i in 0..<5 { await trail.record(category: "t", "event \(i)") }
        let count = await trail.count
        XCTAssertEqual(count, 3)
        let recent = await trail.recent()
        XCTAssertEqual(recent.last?.message, "event 4")
    }

    func testAppendsToFile() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("kai-audit-\(UUID().uuidString)").appendingPathComponent("audit.jsonl")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let trail = AuditTrail(fileURL: url)
        await trail.record(category: "t", "first")
        await trail.record(category: "t", "second")
        let contents = try String(contentsOf: url, encoding: .utf8)
        let lines = contents.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
    }
}

final class UpdateCheckerTests: XCTestCase {
    func testVersionComparison() {
        XCTAssertTrue(StaticUpdateChecker.isNewer("1.10.0", than: "1.2.0"))
        XCTAssertFalse(StaticUpdateChecker.isNewer("1.0.0", than: "1.0.0"))
        XCTAssertTrue(StaticUpdateChecker.isNewer("2.0.0", than: "1.9.9"))
    }

    func testStaticCheckerReportsOnlyNewer() async throws {
        let info = UpdateInfo(version: "1.5.0", notes: "n", downloadURL: URL(string: "https://example.com/k.dmg")!)
        let checker = StaticUpdateChecker(available: info)
        let whenOlder = try await checker.checkForUpdate(current: "1.4.0")
        XCTAssertEqual(whenOlder?.version, "1.5.0")
        let whenSame = try await checker.checkForUpdate(current: "1.5.0")
        XCTAssertNil(whenSame)
    }

    func testNoopCheckerReturnsNil() async throws {
        let result = try await NoopUpdateChecker().checkForUpdate(current: "1.0.0")
        XCTAssertNil(result)
    }
}
