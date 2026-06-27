import Foundation

/// One entry in Kai's audit trail.
public struct AuditRecord: Sendable, Codable, Equatable {
    public let timestamp: Date
    public let category: String
    public let message: String

    public init(timestamp: Date = Date(), category: String, message: String) {
        self.timestamp = timestamp
        self.category = category
        self.message = message
    }
}

/// An append-only, privacy-redacted audit trail of everything Kai does:
/// activations, permission decisions, executed actions, workflow steps, errors.
///
/// Records are kept in a bounded in-memory ring (for the Activity UI) and, when
/// a file URL is provided, appended as JSON Lines for a durable trail. Every
/// message is run through the ``SensitiveDataRedactor`` so secrets never land in
/// the log — satisfying the "log every action, never store secrets" mandate.
public actor AuditTrail {
    private let fileURL: URL?
    private let redactor: SensitiveDataRedactor
    private let capacity: Int
    private var buffer: [AuditRecord] = []
    private let encoder: JSONEncoder

    public init(
        fileURL: URL? = nil,
        redactor: SensitiveDataRedactor = SensitiveDataRedactor(),
        capacity: Int = 1000
    ) {
        self.fileURL = fileURL
        self.redactor = redactor
        self.capacity = max(1, capacity)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    /// Appends a redacted record under `category`.
    public func record(category: String, _ message: String) {
        let record = AuditRecord(category: category, message: redactor.redact(message))
        buffer.append(record)
        if buffer.count > capacity { buffer.removeFirst(buffer.count - capacity) }
        appendToFile(record)
    }

    /// The most recent `limit` records (newest last).
    public func recent(_ limit: Int = 100) -> [AuditRecord] {
        Array(buffer.suffix(limit))
    }

    public var count: Int { buffer.count }

    private func appendToFile(_ record: AuditRecord) {
        guard let fileURL, let data = try? encoder.encode(record) else { return }
        var line = data
        line.append(0x0a) // newline
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: fileURL, options: .atomic)
        }
    }
}
