import XCTest
@testable import KaiMemory
import KaiCore

final class MemoryStoreTests: XCTestCase {
    func testInMemoryStoreRoundTrips() async throws {
        let store = InMemoryStore()
        try await store.set("preferredBrowser", "Safari")
        let value = await store.value(forKey: "preferredBrowser")
        XCTAssertEqual(value, "Safari")
    }

    func testInMemoryStoreRejectsSensitiveKey() async {
        let store = InMemoryStore()
        do {
            try await store.set("accountPassword", "hunter2value")
            XCTFail("should reject sensitive key")
        } catch let error as KaiError {
            if case .sensitiveDataRejected = error { /* ok */ } else {
                XCTFail("wrong error: \(error)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
        let stored = await store.value(forKey: "accountPassword")
        XCTAssertNil(stored, "nothing should be persisted")
    }

    func testJSONFileStorePersistsAcrossInstances() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("kai-test-\(UUID().uuidString)")
            .appendingPathComponent("memory.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = JSONFileStore(url: url)
        try await store.set("preferredEditor", "VS Code")

        // New instance loads from disk.
        let reopened = JSONFileStore(url: url)
        let value = await reopened.value(forKey: "preferredEditor")
        XCTAssertEqual(value, "VS Code")
    }

    func testJSONFileStoreRejectsSensitiveValue() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("kai-test-\(UUID().uuidString)")
            .appendingPathComponent("memory.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = JSONFileStore(url: url)
        do {
            try await store.set("note", "my otp is 738291")
            XCTFail("should reject sensitive value")
        } catch let error as KaiError {
            if case .sensitiveDataRejected = error { /* ok */ } else {
                XCTFail("wrong error: \(error)")
            }
        }
    }
}
