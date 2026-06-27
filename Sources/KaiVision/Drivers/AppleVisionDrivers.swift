#if os(macOS)
import Foundation
import Vision
import PDFKit
import AppKit
import ScreenCaptureKit
import CoreGraphics

/// macOS OCR via the Vision framework.
public struct VisionOCREngine: OCREngine {
    private let recognitionLevel: VNRequestTextRecognitionLevel

    public init(accurate: Bool = true) {
        self.recognitionLevel = accurate ? .accurate : .fast
    }

    public func recognizeText(in imageData: Data) async throws -> RecognizedText {
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw VisionError.recognitionFailed(reason: "invalid image data")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: VisionError.recognitionFailed(reason: error.localizedDescription))
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines: [RecognizedLine] = observations.compactMap { observation in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    let bb = observation.boundingBox
                    return RecognizedLine(
                        text: candidate.string,
                        box: BoundingBox(x: bb.origin.x, y: bb.origin.y, width: bb.size.width, height: bb.size.height)
                    )
                }
                continuation.resume(returning: RecognizedText(lines: lines))
            }
            request.recognitionLevel = recognitionLevel
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do { try handler.perform([request]) }
            catch { continuation.resume(throwing: VisionError.recognitionFailed(reason: error.localizedDescription)) }
        }
    }
}

/// macOS PDF text extraction via PDFKit.
public struct PDFKitTextReader: PDFTextReader {
    public init() {}
    public func readText(at url: URL) async throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw VisionError.unreadableDocument(path: url.path)
        }
        return document.string ?? ""
    }
}

/// macOS screen capture via ScreenCaptureKit. Requires Screen Recording
/// permission, which the app requests during onboarding.
public struct ScreenCaptureKitCapturer: ScreenCapturer {
    public init() {}

    public func captureActiveDisplay() async throws -> Data {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else { throw VisionError.captureUnavailable }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height

        let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw VisionError.captureUnavailable
        }
        return data
    }
}
#endif
