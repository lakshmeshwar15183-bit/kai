import Foundation

/// A normalised bounding box (0...1 coordinates), kept dependency-free so the
/// model compiles on Linux (CoreGraphics is Apple-only).
public struct BoundingBox: Sendable, Equatable, Codable {
    public var x: Double, y: Double, width: Double, height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

/// A single recognised line of text and where it sits on screen/page.
public struct RecognizedLine: Sendable, Equatable, Codable {
    public let text: String
    public let box: BoundingBox?
    public init(text: String, box: BoundingBox? = nil) {
        self.text = text
        self.box = box
    }
}

/// The result of OCR / text extraction.
public struct RecognizedText: Sendable, Equatable, Codable {
    public let lines: [RecognizedLine]
    public init(lines: [RecognizedLine]) { self.lines = lines }

    public var fullText: String { lines.map(\.text).joined(separator: "\n") }
    public var isEmpty: Bool { lines.isEmpty }
}

/// Structured understanding of a document/screen derived by ``DocumentAnalyzer``.
public struct DocumentInsights: Sendable, Equatable {
    public let wordCount: Int
    public let lineCount: Int
    public let headings: [String]
    public let errors: [String]

    public var hasError: Bool { !errors.isEmpty }
}
