import Foundation

/// Information about an available application update.
public struct UpdateInfo: Sendable, Equatable {
    public let version: String
    public let notes: String
    public let downloadURL: URL

    public init(version: String, notes: String, downloadURL: URL) {
        self.version = version
        self.notes = notes
        self.downloadURL = downloadURL
    }
}

/// Checks whether a newer version of Kai is available. Implementations MUST NOT
/// download or install anything automatically — Kai never updates silently. The
/// UI surfaces the result and the user decides.
///
/// The production macOS implementation is expected to wrap an appcast-based
/// updater (e.g. Sparkle), injected here so the rest of the app depends only on
/// this protocol.
public protocol UpdateChecking: Sendable {
    /// Returns update info if a version newer than `current` exists, else nil.
    func checkForUpdate(current: String) async throws -> UpdateInfo?
}

/// Default no-op checker (used until an updater backend is configured).
public struct NoopUpdateChecker: UpdateChecking {
    public init() {}
    public func checkForUpdate(current: String) async throws -> UpdateInfo? { nil }
}

/// A fixed checker useful for tests and previews: reports `available` only when
/// it is strictly newer than the current version (dotted numeric comparison).
public struct StaticUpdateChecker: UpdateChecking {
    private let available: UpdateInfo
    public init(available: UpdateInfo) { self.available = available }

    public func checkForUpdate(current: String) async throws -> UpdateInfo? {
        Self.isNewer(available.version, than: current) ? available : nil
    }

    /// Compares dotted numeric versions, e.g. "1.2.0" vs "1.10.0".
    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        let lhs = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let rhs = current.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(lhs.count, rhs.count)
        for i in 0..<count {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
