import Foundation
import KaiCore

/// High-level Finder operations composed on top of a ``FileSystemController``.
/// All logic here is platform-agnostic and exercised by real tests against a
/// temporary directory.
public struct FinderService: Sendable {
    private let controller: any FileSystemController

    public init(controller: any FileSystemController) {
        self.controller = controller
    }

    /// Moves the loose files in `directory` into per-category subfolders.
    /// Existing subfolders are left untouched. Returns a per-category count.
    @discardableResult
    public func organizeByType(in directory: URL, stop: StopController? = nil) async throws -> [String: Int] {
        let items = try await controller.list(at: directory)
        var counts: [String: Int] = [:]
        for item in items where !item.isDirectory {
            try await stop?.checkpoint()
            let category = FileCategory.forExtension(item.pathExtension)
            let folder = directory.appendingPathComponent(category.rawValue, isDirectory: true)
            try await controller.createDirectory(at: folder)
            let destination = folder.appendingPathComponent(item.name)
            // Skip if a same-named file already sits in the target folder.
            if await controller.exists(destination) { continue }
            try await controller.move(from: item.url, to: destination)
            counts[category.rawValue, default: 0] += 1
        }
        return counts
    }

    /// Finds groups of byte-identical files (recursively) under `directory`.
    public func findDuplicates(in directory: URL, stop: StopController? = nil) async throws -> [DuplicateGroup] {
        let files = try await allFiles(under: directory, stop: stop)
        // Group by size first (cheap), then hash within same-size buckets.
        let bySize = Dictionary(grouping: files, by: { $0.size })
        var groups: [DuplicateGroup] = []
        for (_, sameSize) in bySize where sameSize.count > 1 {
            var byHash: [String: [FileItem]] = [:]
            for file in sameSize {
                try await stop?.checkpoint()
                let hash = try await controller.contentsHash(of: file.url)
                byHash[hash, default: []].append(file)
            }
            for (hash, items) in byHash where items.count > 1 {
                let ordered = items.sorted { $0.url.path < $1.url.path }
                groups.append(DuplicateGroup(contentHash: hash, items: ordered))
            }
        }
        return groups.sorted { $0.contentHash < $1.contentHash }
    }

    /// Recursively lists files (not directories) whose name contains `query`.
    public func search(in directory: URL, matching query: String, stop: StopController? = nil) async throws -> [FileItem] {
        let needle = query.lowercased()
        let files = try await allFiles(under: directory, stop: stop)
        return files.filter { $0.name.lowercased().contains(needle) }
    }

    // MARK: - Helpers

    private func allFiles(under directory: URL, stop: StopController?) async throws -> [FileItem] {
        var results: [FileItem] = []
        var stack = [directory]
        while let current = stack.popLast() {
            try await stop?.checkpoint()
            let items = try await controller.list(at: current)
            for item in items {
                if item.isDirectory { stack.append(item.url) }
                else { results.append(item) }
            }
        }
        return results
    }
}
