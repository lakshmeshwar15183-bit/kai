import XCTest
@testable import KaiBrowser
import KaiCore
import KaiAI
import KaiMemory
import KaiPlugins

final class BrowserPluginTests: XCTestCase {
    private func url(_ s: String) -> URL { URL(string: s)! }

    private func makeServices() -> PluginServices {
        PluginServices(
            ai: EchoAIProvider(),
            memory: InMemoryStore(),
            logger: KaiLogger(minimumLevel: .error),
            stopController: StopController(),
            eventBus: EventBus()
        )
    }

    func testOpenNormalPage() async throws {
        let home = PageSnapshot(url: url("https://example.com"), title: "Example", text: "content")
        let plugin = BrowserPlugin(controller: InMemoryBrowserController(pages: [home]))
        let result = try await plugin.handle(KaiCommand(text: "open https://example.com"), services: makeServices())
        XCTAssertTrue(result.didSucceed)
        XCTAssertTrue(result.message.contains("Example"))
        XCTAssertNil(result.metadata["authRequired"])
    }

    func testOpenLoginPageRequestsAuthentication() async throws {
        let login = PageSnapshot(
            url: url("https://example.com/login"),
            title: "Sign in",
            text: "",
            elements: [PageElement(id: "1", role: .secureField, label: "password")]
        )
        let plugin = BrowserPlugin(controller: InMemoryBrowserController(pages: [login]))
        let result = try await plugin.handle(KaiCommand(text: "open https://example.com/login"), services: makeServices())
        XCTAssertEqual(result.metadata["authRequired"], "true")
        XCTAssertTrue(result.message.lowercased().contains("credentials") || result.message.lowercased().contains("log in"))
    }

    func testWaitForLoginResolves() async throws {
        let login = PageSnapshot(
            url: url("https://example.com/login"),
            title: "Sign in",
            text: "",
            elements: [PageElement(id: "1", role: .secureField, label: "password")]
        )
        let dashboard = PageSnapshot(url: url("https://example.com/home"), title: "Dashboard", text: "welcome")
        let controller = InMemoryBrowserController(pages: [login])
        try await controller.open(url("https://example.com/login"))
        await controller.scheduleLoginResolution(after: 2, to: dashboard)

        // pollInterval .zero keeps the test fast.
        let plugin = BrowserPlugin(controller: controller, pollInterval: .zero, maxLoginAttempts: 10)
        let result = try await plugin.handle(KaiCommand(text: "continue after login"), services: makeServices())
        XCTAssertTrue(result.message.contains("Dashboard"))
    }

    func testSummarizeUsesAIProvider() async throws {
        let page = PageSnapshot(url: url("https://example.com"), title: "T", text: "important article body")
        let controller = InMemoryBrowserController(pages: [page])
        try await controller.open(url("https://example.com"))
        let plugin = BrowserPlugin(controller: controller)
        let result = try await plugin.handle(KaiCommand(text: "summarize this page"), services: makeServices())
        // EchoAIProvider echoes the user content (the page text).
        XCTAssertTrue(result.message.contains("important article body"))
    }

    func testReadPageCapabilityIsReadOnly() {
        let plugin = BrowserPlugin(controller: InMemoryBrowserController())
        let readCap = plugin.capability(for: KaiCommand(text: "read the page"))
        XCTAssertEqual(readCap?.sideEffect, false)
        let clickCap = plugin.capability(for: KaiCommand(text: "click Submit"))
        XCTAssertEqual(clickCap?.sideEffect, true)
        XCTAssertEqual(clickCap?.defaultPermissionLevel, .yellow)
    }
}
