import XCTest
@testable import KaiBrowser

final class InMemoryBrowserControllerTests: XCTestCase {
    private func url(_ s: String) -> URL { URL(string: s)! }

    func testOpenAndSnapshot() async throws {
        let home = PageSnapshot(url: url("https://example.com"), title: "Example Home", text: "hello")
        let controller = InMemoryBrowserController(pages: [home])
        try await controller.open(url("https://example.com"))
        let snap = try await controller.snapshot()
        XCTAssertEqual(snap.title, "Example Home")
        XCTAssertEqual(snap.text, "hello")
    }

    func testClickLinkNavigates() async throws {
        let link = PageElement(id: "1", role: .link, label: "Docs", value: "https://example.com/docs")
        let home = PageSnapshot(url: url("https://example.com"), title: "Home", text: "", elements: [link])
        let docs = PageSnapshot(url: url("https://example.com/docs"), title: "Docs Page", text: "documentation")
        let controller = InMemoryBrowserController(pages: [home, docs])
        try await controller.open(url("https://example.com"))
        try await controller.click(label: "Docs")
        let snap = try await controller.snapshot()
        XCTAssertEqual(snap.title, "Docs Page")
    }

    func testFillNonSecureUpdatesValueButRefusesSecure() async throws {
        let email = PageElement(id: "1", role: .textField, label: "email")
        let password = PageElement(id: "2", role: .secureField, label: "password")
        let page = PageSnapshot(url: url("https://example.com/login"), title: "Login", text: "", elements: [email, password])
        let controller = InMemoryBrowserController(pages: [page])
        try await controller.open(url("https://example.com/login"))

        try await controller.fill(field: "email", value: "me@example.com")
        let snap = try await controller.snapshot()
        XCTAssertEqual(snap.elements.first(where: { $0.label == "email" })?.value, "me@example.com")

        do {
            try await controller.fill(field: "password", value: "secret")
            XCTFail("should refuse secure field")
        } catch let error as BrowserError {
            XCTAssertEqual(error, .refusedSecureField)
        }
    }

    func testBackAndForward() async throws {
        let a = PageSnapshot(url: url("https://a.com"), title: "A", text: "")
        let b = PageSnapshot(url: url("https://b.com"), title: "B", text: "")
        let controller = InMemoryBrowserController(pages: [a, b])
        try await controller.open(url("https://a.com"))
        try await controller.open(url("https://b.com"))
        try await controller.navigate(.back)
        var snap = try await controller.snapshot()
        XCTAssertEqual(snap.title, "A")
        try await controller.navigate(.forward)
        snap = try await controller.snapshot()
        XCTAssertEqual(snap.title, "B")
    }

    func testLoginAutoResolution() async throws {
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

        let first = try await controller.snapshot()
        XCTAssertTrue(first.hasSecureField, "still on login after first snapshot")
        let second = try await controller.snapshot()
        XCTAssertEqual(second.title, "Dashboard", "resolves after the scheduled count")
    }
}
