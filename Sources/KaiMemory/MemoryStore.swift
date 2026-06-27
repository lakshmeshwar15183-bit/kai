import Foundation
import KaiCore

/// A durable record of a user preference Kai is allowed to remember (preferred
/// folders, browsers, editors, download locations, repeated workflows, etc.).
public struct MemoryRecord: Sendable, Codable, Equatable {
    public let key: String
    public var value: String
    public var updatedAt: Date

    public init(key: String, value: String, updatedAt: Date = Date()) {
        self.key = key
        self.value = value
        self.updatedAt = updatedAt
    }
}

/// The contract for Kai's long-term memory.
///
/// Every implementation MUST refuse to persist sensitive data (passwords, PINs,
/// OTPs, banking credentials, tokens). Enforcement lives in the store itself —
/// via ``SensitiveDataRedactor`` — so a careless caller cannot leak secrets.
public protocol MemoryStore: Sendable {
    /// Persists a preference. Throws ``KaiError/sensitiveDataRejected`` if the
    /// key or value looks like a secret.
    func set(_ key: String, _ value: String) async throws

    func value(forKey key: String) async -> String?
    func record(forKey key: String) async -> MemoryRecord?
    func delete(_ key: String) async
    func allRecords() async -> [MemoryRecord]
    func removeAll() async
}
