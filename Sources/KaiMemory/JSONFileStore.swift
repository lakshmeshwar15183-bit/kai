import Foundation
import KaiCore

/// A ``MemoryStore`` that persists records as a JSON file on disk (e.g. under
/// Application Support). Writes are atomic. The same privacy guard applies, so
/// secrets never reach the file.
public actor JSONFileStore: MemoryStore {
    private let url: URL
    private let redactor: SensitiveDataRedactor
    private var records: [String: MemoryRecord]

    /// - Parameters:
    ///   - url: Destination file. Parent directory is created if needed.
    ///   - redactor: Privacy guard.
    public init(url: URL, redactor: SensitiveDataRedactor = SensitiveDataRedactor()) {
        self.url = url
        self.redactor = redactor
        self.records = Self.load(from: url)
    }

    public func set(_ key: String, _ value: String) async throws {
        if case let .sensitive(reason) = redactor.classify(key: key, value: value) {
            throw KaiError.sensitiveDataRejected(reason: reason)
        }
        records[key] = MemoryRecord(key: key, value: value)
        try persist()
    }

    public func value(forKey key: String) async -> String? {
        records[key]?.value
    }

    public func record(forKey key: String) async -> MemoryRecord? {
        records[key]
    }

    public func delete(_ key: String) async {
        records[key] = nil
        try? persist()
    }

    public func allRecords() async -> [MemoryRecord] {
        records.values.sorted { $0.key < $1.key }
    }

    public func removeAll() async {
        records.removeAll()
        try? persist()
    }

    // MARK: - Persistence

    private func persist() throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(Array(records.values).sorted { $0.key < $1.key })
        try data.write(to: url, options: .atomic)
    }

    private static func load(from url: URL) -> [String: MemoryRecord] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let list = try? decoder.decode([MemoryRecord].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: list.map { ($0.key, $0) })
    }
}
