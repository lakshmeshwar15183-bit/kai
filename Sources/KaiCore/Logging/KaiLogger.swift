import Foundation

/// Severity of a log line.
public enum LogLevel: Int, Sendable, Codable, Comparable, CaseIterable {
    case debug = 0
    case info
    case notice
    case warning
    case error

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var label: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .notice: return "NOTICE"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        }
    }
}

/// A destination for log lines. The default implementation prints to stderr,
/// but the macOS app can install a sink that forwards to the activity log UI.
public protocol LogSink: Sendable {
    func write(level: LogLevel, message: String, timestamp: Date)
}

/// Writes redacted log lines to standard error.
public struct ConsoleLogSink: LogSink {
    public init() {}
    public func write(level: LogLevel, message: String, timestamp: Date) {
        FileHandle.standardError.write(Data("[\(level.label)] \(message)\n".utf8))
    }
}

/// The logger every component should use. It enforces the minimum level and
/// runs every message through the ``SensitiveDataRedactor`` so secrets can
/// never leak into logs, regardless of caller behaviour.
public actor KaiLogger {
    private var minimumLevel: LogLevel
    private let redactor: SensitiveDataRedactor
    private let sink: LogSink

    public init(
        minimumLevel: LogLevel = .info,
        redactor: SensitiveDataRedactor = SensitiveDataRedactor(),
        sink: LogSink = ConsoleLogSink()
    ) {
        self.minimumLevel = minimumLevel
        self.redactor = redactor
        self.sink = sink
    }

    public func setMinimumLevel(_ level: LogLevel) {
        minimumLevel = level
    }

    public func log(_ level: LogLevel, _ message: String) {
        guard level >= minimumLevel else { return }
        sink.write(level: level, message: redactor.redact(message), timestamp: Date())
    }

    public func debug(_ message: String) { log(.debug, message) }
    public func info(_ message: String) { log(.info, message) }
    public func notice(_ message: String) { log(.notice, message) }
    public func warning(_ message: String) { log(.warning, message) }
    public func error(_ message: String) { log(.error, message) }
}
