import Foundation

/// Errors raised by the vision engines.
public enum VisionError: Error, Sendable, Equatable, CustomStringConvertible {
    case captureUnavailable
    case recognitionFailed(reason: String)
    case unreadableDocument(path: String)

    public var description: String {
        switch self {
        case .captureUnavailable: return "Screen capture is unavailable."
        case let .recognitionFailed(reason): return "Text recognition failed: \(reason)."
        case let .unreadableDocument(path): return "Could not read document: \(path)."
        }
    }
}

/// Captures the current screen (or active window) as image data (PNG).
/// macOS implementation uses ScreenCaptureKit; tests inject a stub.
public protocol ScreenCapturer: Sendable {
    func captureActiveDisplay() async throws -> Data
}

/// Recognises text in image data. macOS implementation uses the Vision
/// framework (`VNRecognizeTextRequest`); tests inject a stub.
public protocol OCREngine: Sendable {
    func recognizeText(in imageData: Data) async throws -> RecognizedText
}

/// Extracts the text of a PDF. macOS implementation uses PDFKit; tests inject a
/// stub.
public protocol PDFTextReader: Sendable {
    func readText(at url: URL) async throws -> String
}

// MARK: - Test/CLI stubs (deterministic, no OS dependency)

/// A capturer that returns fixed bytes — used where no display exists.
public struct StubScreenCapturer: ScreenCapturer {
    private let data: Data
    public init(data: Data = Data([0x89, 0x50, 0x4e, 0x47])) { self.data = data }
    public func captureActiveDisplay() async throws -> Data { data }
}

/// An OCR engine that returns pre-scripted text.
public struct StubOCREngine: OCREngine {
    private let text: RecognizedText
    public init(_ text: RecognizedText) { self.text = text }
    public init(plain: String) {
        self.text = RecognizedText(lines: plain.split(separator: "\n", omittingEmptySubsequences: false).map {
            RecognizedLine(text: String($0))
        })
    }
    public func recognizeText(in imageData: Data) async throws -> RecognizedText { text }
}

/// A PDF reader that reads a UTF-8 text file as a stand-in, so the pipeline can
/// be exercised without PDFKit.
public struct StubPDFTextReader: PDFTextReader {
    public init() {}
    public func readText(at url: URL) async throws -> String {
        guard let data = FileManager.default.contents(atPath: url.path),
              let text = String(data: data, encoding: .utf8) else {
            throw VisionError.unreadableDocument(path: url.path)
        }
        return text
    }
}
