import Foundation

/// A file or directory entry surfaced by the file-system controller.
public struct FileItem: Sendable, Equatable, Identifiable {
    public var id: String { url.path }
    public let url: URL
    public let isDirectory: Bool
    public let size: Int
    public let modifiedAt: Date?

    public init(url: URL, isDirectory: Bool, size: Int, modifiedAt: Date?) {
        self.url = url
        self.isDirectory = isDirectory
        self.size = size
        self.modifiedAt = modifiedAt
    }

    public var name: String { url.lastPathComponent }
    public var pathExtension: String { url.pathExtension.lowercased() }
}

/// A set of files with identical content (size + hash), as found by the
/// duplicate detector. The first element is treated as the original to keep.
public struct DuplicateGroup: Sendable, Equatable {
    public let contentHash: String
    public let items: [FileItem]

    public init(contentHash: String, items: [FileItem]) {
        self.contentHash = contentHash
        self.items = items
    }

    /// Duplicates beyond the first (kept) item.
    public var redundant: [FileItem] { Array(items.dropFirst()) }
}

/// Errors raised by Finder operations.
public enum FinderError: Error, Sendable, Equatable, CustomStringConvertible {
    case notFound(path: String)
    case notADirectory(path: String)
    case alreadyExists(path: String)
    case nothingToUndo
    case operationFailed(reason: String)

    public var description: String {
        switch self {
        case let .notFound(path): return "Not found: \(path)."
        case let .notADirectory(path): return "Not a directory: \(path)."
        case let .alreadyExists(path): return "Already exists: \(path)."
        case .nothingToUndo: return "Nothing to undo."
        case let .operationFailed(reason): return "Operation failed: \(reason)."
        }
    }
}
