import XCTest
@testable import KaiVision
import KaiCore
import KaiPlugins
import KaiAI
import KaiMemory

final class DocumentAnalyzerTests: XCTestCase {
    private let analyzer = DocumentAnalyzer()

    func testDetectsErrorsAndHeadings() {
        let text = """
        # Build Report
        Summary:
        The compile step ran.
        ERROR: undefined symbol _main
        all good otherwise
        """
        let insights = analyzer.analyze(text)
        XCTAssertTrue(insights.hasError)
        XCTAssertEqual(insights.errors.count, 1)
        XCTAssertTrue(insights.headings.contains("# Build Report"))
        XCTAssertTrue(insights.headings.contains("Summary:"))
        XCTAssertGreaterThan(insights.wordCount, 0)
    }

    func testCleanDocumentHasNoErrors() {
        let insights = analyzer.analyze("Just a calm paragraph about gardening.")
        XCTAssertFalse(insights.hasError)
    }
}

final class VisionPluginTests: XCTestCase {
    private func services() -> PluginServices {
        PluginServices(ai: EchoAIProvider(), memory: InMemoryStore(),
                       logger: KaiLogger(minimumLevel: .error), stopController: StopController(), eventBus: EventBus())
    }

    func testObserveScreenIsReadOnlyAndReportsErrors() async throws {
        let ocr = StubOCREngine(plain: "Console output\nERROR: crash detected\nline three")
        let plugin = VisionPlugin(capturer: StubScreenCapturer(), ocr: ocr, pdfReader: StubPDFTextReader())

        XCTAssertEqual(plugin.capability(for: KaiCommand(text: "observe screen"))?.sideEffect, false)

        let result = try await plugin.handle(KaiCommand(text: "observe screen"), services: services())
        XCTAssertEqual(result.metadata["hasError"], "true")
        XCTAssertEqual(result.metadata["lines"], "3")
    }

    func testReadPDFExtractsText() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("kai-\(UUID().uuidString).txt")
        try "Chapter One\nThe story begins.".data(using: .utf8)!.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let plugin = VisionPlugin(capturer: StubScreenCapturer(), ocr: StubOCREngine(plain: ""), pdfReader: StubPDFTextReader())
        let result = try await plugin.handle(KaiCommand(text: "read pdf \(tmp.path)"), services: services())
        XCTAssertEqual(result.metadata["lines"], "2")
    }
}
