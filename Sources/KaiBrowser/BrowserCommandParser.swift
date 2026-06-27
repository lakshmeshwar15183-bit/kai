import Foundation

/// A structured browser instruction parsed from natural language.
public enum BrowserIntent: Sendable, Equatable {
    case open(URL)
    case navigate(NavigationAction)
    case scroll(ScrollDirection)
    case click(label: String)
    case fill(field: String, value: String)
    /// Read-only: return the page's text.
    case readPage
    /// Read-only: AI summary of the page.
    case summarize
    /// Pause and wait for the user to finish authenticating.
    case waitForLogin
}

/// Turns free-form text into a ``BrowserIntent``. Deliberately rule-based and
/// deterministic so it is fully testable; an AI-backed parser can be layered on
/// later behind the same return type.
public struct BrowserCommandParser: Sendable {
    public init() {}

    public func parse(_ text: String) -> BrowserIntent? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        // Navigation.
        if lower == "go back" || lower == "back" { return .navigate(.back) }
        if lower == "go forward" || lower == "forward" { return .navigate(.forward) }
        if lower == "reload" || lower == "refresh" { return .navigate(.reload) }

        // Scrolling.
        if lower.hasPrefix("scroll") {
            if lower.contains("up") { return .scroll(.up) }
            if lower.contains("top") { return .scroll(.top) }
            if lower.contains("bottom") { return .scroll(.bottom) }
            return .scroll(.down)
        }

        // Authentication wait.
        if lower.contains("wait for login") || lower.contains("wait for authentication")
            || lower.contains("continue after login") {
            return .waitForLogin
        }

        // Reading / understanding (read-only).
        if lower.contains("summarize") || lower.contains("summary of") {
            return .summarize
        }
        if lower.contains("read page") || lower.contains("read the page")
            || lower.contains("extract text") || lower.contains("what's on")
            || lower.contains("what is on") || lower.contains("understand this page")
            || lower.contains("understand the page") {
            return .readPage
        }

        // Fill a field: "fill <field> with <value>" / "type <value> in <field>".
        if let fill = parseFill(trimmed) {
            return fill
        }

        // Click: "click <label>" / "press <label>" / "tap <label>".
        for verb in ["click", "press", "tap"] where lower.hasPrefix(verb + " ") {
            let label = String(trimmed.dropFirst(verb.count)).trimmingCharacters(in: .whitespaces)
            if !label.isEmpty { return .click(label: stripQuotes(label)) }
        }

        // Open / navigate to a URL.
        if let url = parseOpen(trimmed, lower: lower) {
            return .open(url)
        }

        return nil
    }

    // MARK: - Helpers

    private func parseFill(_ original: String) -> BrowserIntent? {
        let lower = original.lowercased()
        // Pattern A: "<verb> <field> with <value>".
        for verb in ["fill ", "enter ", "set "] where lower.hasPrefix(verb) {
            if let withRange = original.range(of: " with ", options: .caseInsensitive) {
                let fieldStart = original.index(original.startIndex, offsetBy: verb.count)
                let field = String(original[fieldStart..<withRange.lowerBound])
                let value = String(original[withRange.upperBound...])
                let f = stripQuotes(field.trimmingCharacters(in: .whitespaces))
                let v = stripQuotes(value.trimmingCharacters(in: .whitespaces))
                if !f.isEmpty && !v.isEmpty { return .fill(field: f, value: v) }
            }
        }
        // Pattern B: "type <value> in <field>".
        if lower.hasPrefix("type "), let inRange = original.range(of: " in ", options: .caseInsensitive) {
            let valueStart = original.index(original.startIndex, offsetBy: 5)
            let value = String(original[valueStart..<inRange.lowerBound])
            let field = String(original[inRange.upperBound...])
            let v = stripQuotes(value.trimmingCharacters(in: .whitespaces))
            let f = stripQuotes(field.trimmingCharacters(in: .whitespaces))
            if !f.isEmpty && !v.isEmpty { return .fill(field: f, value: v) }
        }
        return nil
    }

    private func parseOpen(_ original: String, lower: String) -> URL? {
        var candidate = original
        for prefix in ["open ", "go to ", "goto ", "navigate to ", "visit "] {
            if lower.hasPrefix(prefix) {
                candidate = String(original.dropFirst(prefix.count))
                break
            }
        }
        candidate = stripQuotes(candidate.trimmingCharacters(in: .whitespaces))
        guard !candidate.isEmpty, !candidate.contains(" ") else { return nil }

        if candidate.hasPrefix("http://") || candidate.hasPrefix("https://") {
            return URL(string: candidate)
        }
        // Treat a bare domain (contains a dot) as https.
        if candidate.contains(".") {
            return URL(string: "https://" + candidate)
        }
        return nil
    }

    private func stripQuotes(_ s: String) -> String {
        var result = s
        let quotes: [Character] = ["\"", "'", "“", "”", "‘", "’"]
        if let first = result.first, quotes.contains(first) { result.removeFirst() }
        if let last = result.last, quotes.contains(last) { result.removeLast() }
        return result
    }
}
