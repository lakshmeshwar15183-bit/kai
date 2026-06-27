import Foundation
import KaiCore

/// A non-persistent ``MemoryStore`` backed by a dictionary. Used in tests and
/// as the in-process cache layer. Still enforces the privacy guard.
public actor InMemoryStore: MemoryStore {
    private var records: [String: MemoryRecord] = [:]
    private let redactor: SensitiveDataRedactor

    public init(redactor: SensitiveDataRedactor = SensitiveDataRedactor()) {
        self.redactor = redactor
    }

    public func set(_ key: String, _ value: String) async throws {
        if case let .sensitive(reason) = redactor.classify(key: key, value: value) {
            throw KaiError.sensitiveDataRejected(reason: reason)
        }
        records[key] = MemoryRecord(key: key, value: value)
    }

    public func value(forKey key: String) async -> String? {
        records[key]?.value
    }

    public func record(forKey key: String) async -> MemoryRecord? {
        records[key]
    }

    public func delete(_ key: String) async {
        records[key] = nil
    }

    public func allRecords() async -> [MemoryRecord] {
        records.values.sorted { $0.key < $1.key }
    }

    public func removeAll() async {
        records.removeAll()
    }
}
