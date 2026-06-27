import Foundation

/// Turns raw recognised/extracted text into structured ``DocumentInsights``:
/// headings, error lines, and counts. Pure, deterministic, and fully tested —
/// this is the platform-agnostic heart of Kai's screen understanding.
public struct DocumentAnalyzer: Sendable {
    private let errorSignals: [String]

    public init() {
        self.errorSignals = ["error", "exception", "failed", "failure", "fatal", "traceback", "panic", "cannot", "unable to"]
    }

    public func analyze(_ text: String) -> DocumentInsights {
        let rawLines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let nonEmpty = rawLines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        let wordCount = nonEmpty.reduce(0) { $0 + $1.split(separator: " ").count }
        let headings = nonEmpty.filter(isHeading)
        let errors = nonEmpty.filter(isError)

        return DocumentInsights(
            wordCount: wordCount,
            lineCount: nonEmpty.count,
            headings: headings,
            errors: errors
        )
    }

    // MARK: - Heuristics

    private func isHeading(_ line: String) -> Bool {
        if line.hasPrefix("#") { return true }                       // markdown
        if line.count <= 60, line.hasSuffix(":") { return true }     // section label
        // Short, no terminal punctuation, mostly uppercase letters.
        guard line.count <= 60, !line.hasSuffix("."), !line.hasSuffix(",") else { return false }
        let letters = line.filter { $0.isLetter }
        guard !letters.isEmpty else { return false }
        let uppercase = letters.filter { $0.isUppercase }.count
        return Double(uppercase) / Double(letters.count) >= 0.7
    }

    private func isError(_ line: String) -> Bool {
        let lowered = line.lowercased()
        return errorSignals.contains { lowered.contains($0) }
    }
}
