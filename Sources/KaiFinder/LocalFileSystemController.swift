import Foundation

/// The production ``FileSystemController`` backed by `FileManager`. It is an
/// actor because it owns the managed-trash directory and must serialise access.
///
/// All operations are genuine file-system calls and work identically on macOS
/// and Linux, so this same type is used in tests against a temp directory.
public actor LocalFileSystemController: FileSystemController {
    private let fileManager: FileManager
    private let trashDirectory: URL

    /// - Parameter trashDirectory: where soft-deleted items are kept for undo.
    ///   Defaults to a `Kai/Trash` folder under the system temp directory.
    public init(
        fileManager: FileManager = .default,
        trashDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        self.trashDirectory = trashDirectory
            ?? fileManager.temporaryDirectory.appendingPathComponent("Kai/Trash", isDirectory: true)
    }

    public func exists(_ url: URL) async -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    public func list(at directory: URL) async throws -> [FileItem] {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDir) else {
            throw FinderError.notFound(path: directory.path)
        }
        guard isDir.boolValue else { throw FinderError.notADirectory(path: directory.path) }

        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        return try urls.map { try makeItem($0) }.sorted { $0.name < $1.name }
    }

    public func createDirectory(at url: URL) async throws {
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw FinderError.operationFailed(reason: error.localizedDescription)
        }
    }

    public func move(from source: URL, to destination: URL) async throws {
        guard fileManager.fileExists(atPath: source.path) else {
            throw FinderError.notFound(path: source.path)
        }
        if fileManager.fileExists(atPath: destination.path) {
            throw FinderError.alreadyExists(path: destination.path)
        }
        try ensureParent(of: destination)
        do {
            try fileManager.moveItem(at: source, to: destination)
        } catch {
            throw FinderError.operationFailed(reason: error.localizedDescription)
        }
    }

    public func copy(from source: URL, to destination: URL) async throws {
        guard fileManager.fileExists(atPath: source.path) else {
            throw FinderError.notFound(path: source.path)
        }
        if fileManager.fileExists(atPath: destination.path) {
            throw FinderError.alreadyExists(path: destination.path)
        }
        try ensureParent(of: destination)
        do {
            try fileManager.copyItem(at: source, to: destination)
        } catch {
            throw FinderError.operationFailed(reason: error.localizedDescription)
        }
    }

    public func rename(_ url: URL, to newName: String) async throws -> URL {
        let destination = url.deletingLastPathComponent().appendingPathComponent(newName)
        try await move(from: url, to: destination)
        return destination
    }

    public func contentsHash(of url: URL) async throws -> String {
        guard let data = fileManager.contents(atPath: url.path) else {
            throw FinderError.notFound(path: url.path)
        }
        return SHA256.hexDigest(data)
    }

    public func moveToTrash(_ url: URL) async throws -> TrashToken {
        guard fileManager.fileExists(atPath: url.path) else {
            throw FinderError.notFound(path: url.path)
        }
        let bucket = trashDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: bucket, withIntermediateDirectories: true)
        let trashedURL = bucket.appendingPathComponent(url.lastPathComponent)
        do {
            try fileManager.moveItem(at: url, to: trashedURL)
        } catch {
            throw FinderError.operationFailed(reason: error.localizedDescription)
        }
        return TrashToken(originalURL: url, trashedURL: trashedURL)
    }

    public func restore(_ token: TrashToken) async throws -> URL {
        guard fileManager.fileExists(atPath: token.trashedURL.path) else {
            throw FinderError.nothingToUndo
        }
        if fileManager.fileExists(atPath: token.originalURL.path) {
            throw FinderError.alreadyExists(path: token.originalURL.path)
        }
        try ensureParent(of: token.originalURL)
        try fileManager.moveItem(at: token.trashedURL, to: token.originalURL)
        return token.originalURL
    }

    // MARK: - Helpers

    private func ensureParent(of url: URL) throws {
        let parent = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parent.path) {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        }
    }

    private func makeItem(_ url: URL) throws -> FileItem {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
        return FileItem(
            url: url,
            isDirectory: values.isDirectory ?? false,
            size: values.fileSize ?? 0,
            modifiedAt: values.contentModificationDate
        )
    }
}
