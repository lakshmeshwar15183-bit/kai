import Foundation
import KaiCore
import KaiPlugins

/// Finder automation skill: organise, deduplicate, search, rename, move, trash
/// (reversible), and undo. Search and duplicate-listing are read-only (Green,
/// available in Observe mode); mutations are Yellow and reversible via the undo
/// stack — honouring Kai's "undo whenever possible" rule.
public struct FinderPlugin: Plugin {
    private let controller: any FileSystemController
    private let service: FinderService
    private let parser = FinderCommandParser()
    private let undoStack: FinderUndoStack

    public init(controller: any FileSystemController, undoStack: FinderUndoStack = FinderUndoStack()) {
        self.controller = controller
        self.service = FinderService(controller: controller)
        self.undoStack = undoStack
    }

    private enum Caps {
        static let search = Capability(id: "finder.search", name: "Search files",
            summary: "Find files by name.", defaultPermissionLevel: .green, sideEffect: false)
        static let duplicates = Capability(id: "finder.duplicates", name: "Find duplicates",
            summary: "List byte-identical files.", defaultPermissionLevel: .green, sideEffect: false)
        static let organize = Capability(id: "finder.organize", name: "Organize folder",
            summary: "Sort files into category folders.", defaultPermissionLevel: .yellow, sideEffect: true)
        static let rename = Capability(id: "finder.rename", name: "Rename",
            summary: "Rename a file or folder.", defaultPermissionLevel: .yellow, sideEffect: true)
        static let move = Capability(id: "finder.move", name: "Move",
            summary: "Move a file or folder.", defaultPermissionLevel: .yellow, sideEffect: true)
        static let trash = Capability(id: "finder.trash", name: "Move to trash",
            summary: "Move an item to the managed trash (reversible).", defaultPermissionLevel: .yellow, sideEffect: true)
        static let undo = Capability(id: "finder.undo", name: "Undo",
            summary: "Reverse the last Finder action.", defaultPermissionLevel: .green, sideEffect: true)
    }

    public let manifest = PluginManifest(
        id: "skill.finder",
        name: "Finder",
        version: "1.0.0",
        author: "Kai",
        summary: "Organise, search, deduplicate, rename, move, and safely trash files (with undo).",
        capabilities: [Caps.search, Caps.duplicates, Caps.organize, Caps.rename, Caps.move, Caps.trash, Caps.undo]
    )

    public var supportedApplications: Set<String>? { [KnownApplication.finder] }

    public func canHandle(_ command: KaiCommand) -> Bool {
        parser.parse(command.text) != nil
    }

    public func capability(for command: KaiCommand) -> Capability? {
        guard let intent = parser.parse(command.text) else { return manifest.capabilities.first }
        switch intent {
        case .search: return Caps.search
        case .findDuplicates: return Caps.duplicates
        case .organize: return Caps.organize
        case .rename: return Caps.rename
        case .move: return Caps.move
        case .trash: return Caps.trash
        case .undo: return Caps.undo
        }
    }

    public func handle(_ command: KaiCommand, services: PluginServices) async throws -> CommandResult {
        try await services.stopController.checkpoint()
        guard let intent = parser.parse(command.text) else {
            throw KaiError.noHandler(command: command.text)
        }

        switch intent {
        case let .search(query, directory):
            let results = try await service.search(in: directory, matching: query, stop: services.stopController)
            let names = results.prefix(50).map { $0.name }.joined(separator: ", ")
            return CommandResult(
                message: results.isEmpty ? "No files matching \"\(query)\"." : "Found \(results.count): \(names)",
                metadata: ["count": String(results.count)]
            )

        case let .findDuplicates(directory):
            let groups = try await service.findDuplicates(in: directory, stop: services.stopController)
            let redundant = groups.reduce(0) { $0 + $1.redundant.count }
            await services.logger.info("Found \(groups.count) duplicate group(s), \(redundant) redundant file(s).")
            return CommandResult(
                message: groups.isEmpty
                    ? "No duplicates found."
                    : "Found \(groups.count) duplicate group(s) with \(redundant) redundant file(s). Say \"delete <path>\" to remove any.",
                metadata: ["groups": String(groups.count), "redundant": String(redundant)]
            )

        case let .organize(directory):
            let counts = try await service.organizeByType(in: directory, stop: services.stopController)
            let total = counts.values.reduce(0, +)
            let summary = counts.sorted { $0.key < $1.key }.map { "\($0.value) → \($0.key)" }.joined(separator: ", ")
            return CommandResult(
                message: total == 0 ? "Nothing to organise." : "Organised \(total) file(s): \(summary).",
                metadata: ["moved": String(total)]
            )

        case let .rename(url, newName):
            let newURL = try await controller.rename(url, to: newName)
            await undoStack.push(.reverseMove(original: url, moved: newURL))
            return CommandResult(message: "Renamed to \(newName). Say \"undo\" to revert.", metadata: ["path": newURL.path])

        case let .move(from, to):
            try await controller.move(from: from, to: to)
            await undoStack.push(.reverseMove(original: from, moved: to))
            return CommandResult(message: "Moved to \(to.path). Say \"undo\" to revert.", metadata: ["path": to.path])

        case let .trash(url):
            let token = try await controller.moveToTrash(url)
            await undoStack.push(.restore(token))
            return CommandResult(message: "Moved \(url.lastPathComponent) to trash. Say \"undo\" to restore.", metadata: ["path": url.path])

        case .undo:
            guard let action = await undoStack.pop() else {
                return CommandResult(message: "Nothing to undo.", didSucceed: false)
            }
            switch action {
            case let .restore(token):
                let restored = try await controller.restore(token)
                return CommandResult(message: "Restored \(restored.lastPathComponent).", metadata: ["path": restored.path])
            case let .reverseMove(original, moved):
                try await controller.move(from: moved, to: original)
                return CommandResult(message: "Reverted to \(original.path).", metadata: ["path": original.path])
            }
        }
    }
}
