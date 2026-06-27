import Foundation

/// The seam through which Kai touches the file system. Concrete implementations
/// are the real `FileManager`-backed controller and, in tests, the same real
/// controller pointed at a temporary directory (file operations are genuine —
/// no fake is needed because Foundation's file APIs are cross-platform).
///
/// Deletions are routed through a *managed trash* so they are reversible, which
/// satisfies Kai's "undo whenever possible" requirement.
public protocol FileSystemController: Sendable {
    func exists(_ url: URL) async -> Bool
    func list(at directory: URL) async throws -> [FileItem]
    func createDirectory(at url: URL) async throws
    func move(from source: URL, to destination: URL) async throws
    func copy(from source: URL, to destination: URL) async throws
    func rename(_ url: URL, to newName: String) async throws -> URL
    func contentsHash(of url: URL) async throws -> String

    /// Moves an item to Kai's managed trash and returns a restore token.
    func moveToTrash(_ url: URL) async throws -> TrashToken
    /// Restores a previously trashed item to its original location.
    func restore(_ token: TrashToken) async throws -> URL
}

/// An opaque receipt for a trashed item, used to restore it (undo).
public struct TrashToken: Sendable, Equatable {
    public let originalURL: URL
    public let trashedURL: URL
}
