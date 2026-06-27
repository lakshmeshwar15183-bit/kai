import Foundation

/// A structured Finder instruction parsed from natural language.
public enum FinderIntent: Sendable, Equatable {
    case organize(URL)
    case findDuplicates(URL)
    case search(query: String, in: URL)
    case rename(URL, newName: String)
    case move(from: URL, to: URL)
    case trash(URL)
    case undo
}

/// Deterministic, rule-based parser for Finder commands. Paths may use `~`.
public struct FinderCommandParser: Sendable {
    public init() {}

    public func parse(_ text: String) -> FinderIntent? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        if lower == "undo" { return .undo }

        // Duplicates (check before generic "find").
        if lower.contains("duplicate") {
            if let path = pathAfter(" in ", in: trimmed) ?? remainderAfterAnyPrefix(trimmed, ["find duplicates", "find duplicate files", "duplicates"]) {
                if let url = fileURL(path) { return .findDuplicates(url) }
            }
            return nil
        }

        // Organize.
        for prefix in ["organize folder ", "organise folder ", "organize ", "organise ", "clean up ", "tidy "] where lower.hasPrefix(prefix) {
            if let url = fileURL(String(trimmed.dropFirst(prefix.count))) { return .organize(url) }
        }

        // Rename: "rename <path> to <newName>".
        if lower.hasPrefix("rename "), let toRange = trimmed.range(of: " to ", options: .caseInsensitive) {
            let path = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 7)..<toRange.lowerBound])
            let newName = String(trimmed[toRange.upperBound...])
            if let url = fileURL(path) { return .rename(url, newName: stripQuotes(newName.trimmingCharacters(in: .whitespaces))) }
        }

        // Move: "move <path> to <path>".
        if lower.hasPrefix("move "), let toRange = trimmed.range(of: " to ", options: .caseInsensitive) {
            let from = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 5)..<toRange.lowerBound])
            let to = String(trimmed[toRange.upperBound...])
            if let s = fileURL(from), let d = fileURL(to) { return .move(from: s, to: d) }
        }

        // Trash / delete.
        for prefix in ["delete ", "trash ", "remove "] where lower.hasPrefix(prefix) {
            if let url = fileURL(String(trimmed.dropFirst(prefix.count))) { return .trash(url) }
        }

        // Search: "search <query> in <path>" / "find <query> in <path>".
        for prefix in ["search ", "find "] where lower.hasPrefix(prefix) {
            if let inRange = trimmed.range(of: " in ", options: .caseInsensitive) {
                let query = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: prefix.count)..<inRange.lowerBound])
                let path = String(trimmed[inRange.upperBound...])
                if let url = fileURL(path), !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    return .search(query: stripQuotes(query.trimmingCharacters(in: .whitespaces)), in: url)
                }
            }
        }

        return nil
    }

    // MARK: - Helpers

    private func pathAfter(_ separator: String, in text: String) -> String? {
        guard let range = text.range(of: separator, options: .caseInsensitive) else { return nil }
        return String(text[range.upperBound...])
    }

    private func remainderAfterAnyPrefix(_ text: String, _ prefixes: [String]) -> String? {
        let lower = text.lowercased()
        for prefix in prefixes where lower.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count))
        }
        return nil
    }

    private func fileURL(_ raw: String) -> URL? {
        var path = stripQuotes(raw.trimmingCharacters(in: .whitespaces))
        guard !path.isEmpty else { return nil }
        if path == "~" {
            path = NSHomeDirectory()
        } else if path.hasPrefix("~/") {
            path = NSHomeDirectory() + String(path.dropFirst(1))
        }
        return URL(fileURLWithPath: path)
    }

    private func stripQuotes(_ s: String) -> String {
        var result = s
        let quotes: [Character] = ["\"", "'", "“", "”", "‘", "’"]
        if let first = result.first, quotes.contains(first) { result.removeFirst() }
        if let last = result.last, quotes.contains(last) { result.removeLast() }
        return result
    }
}
