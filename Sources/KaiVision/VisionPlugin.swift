import Foundation
import KaiCore
import KaiAI
import KaiPlugins

/// Screen-understanding skill: OCRs the screen and reads PDFs, then analyses the
/// text. Every capability is **read-only** (`sideEffect == false`), so the whole
/// plugin is safe in Observe mode — it understands, it never acts.
public struct VisionPlugin: Plugin {
    private let capturer: any ScreenCapturer
    private let ocr: any OCREngine
    private let pdfReader: any PDFTextReader
    private let analyzer = DocumentAnalyzer()

    public init(capturer: any ScreenCapturer, ocr: any OCREngine, pdfReader: any PDFTextReader) {
        self.capturer = capturer
        self.ocr = ocr
        self.pdfReader = pdfReader
    }

    private enum Intent: Equatable {
        case observeScreen
        case readPDF(URL)
    }

    private func parse(_ text: String) -> Intent? {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if ["observe screen", "what's on my screen", "what is on my screen",
            "describe my screen", "read my screen", "understand my screen"].contains(lower) {
            return .observeScreen
        }
        for prefix in ["read pdf at ", "read the pdf ", "read pdf "] where lower.hasPrefix(prefix) {
            var path = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            if path.hasPrefix("~/") { path = NSHomeDirectory() + String(path.dropFirst(1)) }
            if !path.isEmpty { return .readPDF(URL(fileURLWithPath: path)) }
        }
        return nil
    }

    private enum Caps {
        static let screen = Capability(id: "vision.screen", name: "Understand screen",
            summary: "OCR and analyse the current screen.", defaultPermissionLevel: .green, sideEffect: false)
        static let pdf = Capability(id: "vision.pdf", name: "Read PDF",
            summary: "Extract and analyse the text of a PDF.", defaultPermissionLevel: .green, sideEffect: false)
    }

    public let manifest = PluginManifest(
        id: "skill.vision",
        name: "Vision",
        version: "1.0.0",
        author: "Kai",
        summary: "Understands the screen (OCR) and reads PDFs. Read-only and Observe-safe.",
        capabilities: [Caps.screen, Caps.pdf]
    )

    public func canHandle(_ command: KaiCommand) -> Bool { parse(command.text) != nil }

    public func capability(for command: KaiCommand) -> Capability? {
        switch parse(command.text) {
        case .observeScreen: return Caps.screen
        case .readPDF: return Caps.pdf
        case .none: return manifest.capabilities.first
        }
    }

    public func handle(_ command: KaiCommand, services: PluginServices) async throws -> CommandResult {
        try await services.stopController.checkpoint()
        guard let intent = parse(command.text) else { throw KaiError.noHandler(command: command.text) }

        let text: String
        switch intent {
        case .observeScreen:
            let image = try await capturer.captureActiveDisplay()
            text = try await ocr.recognizeText(in: image).fullText
        case let .readPDF(url):
            text = try await pdfReader.readText(at: url)
        }

        let insights = analyzer.analyze(text)
        let summary = try await summarize(text, insights: insights, services: services)
        return CommandResult(
            message: summary,
            metadata: [
                "lines": String(insights.lineCount),
                "words": String(insights.wordCount),
                "headings": String(insights.headings.count),
                "hasError": String(insights.hasError)
            ]
        )
    }

    private func summarize(_ text: String, insights: DocumentInsights, services: PluginServices) async throws -> String {
        // A deterministic structural summary, optionally enriched by the AI.
        var parts: [String] = []
        parts.append("\(insights.lineCount) lines, \(insights.wordCount) words.")
        if !insights.headings.isEmpty {
            parts.append("Headings: \(insights.headings.prefix(5).joined(separator: " | ")).")
        }
        if insights.hasError {
            parts.append("⚠️ Detected \(insights.errors.count) error line(s): \(insights.errors.first ?? "").")
        }
        let structural = parts.joined(separator: " ")

        // Best-effort AI summary; never fails the read if the provider errors.
        if let aiSummary = try? await services.ai.complete(AIRequest(messages: [
            .system("Summarize what the user is looking at in one or two sentences."),
            .user(String(text.prefix(4000)))
        ])).content, !aiSummary.isEmpty {
            return structural + "\n" + aiSummary
        }
        return structural
    }
}
