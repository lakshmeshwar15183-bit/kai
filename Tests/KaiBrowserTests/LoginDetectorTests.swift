import XCTest
@testable import KaiBrowser

final class LoginDetectorTests: XCTestCase {
    private let detector = LoginDetector()

    private func page(title: String = "Page", text: String = "", elements: [PageElement] = []) -> PageSnapshot {
        PageSnapshot(url: URL(string: "https://example.com")!, title: title, text: text, elements: elements)
    }

    func testDetectsSecureFieldAsLogin() {
        let snap = page(elements: [PageElement(id: "1", role: .secureField, label: "Password")])
        XCTAssertTrue(detector.isLoginPage(snap))
    }

    func testDetectsLoginByTitle() {
        XCTAssertTrue(detector.isLoginPage(page(title: "Sign in to Example")))
        XCTAssertTrue(detector.isLoginPage(page(title: "Log in")))
    }

    func testOrdinaryPageIsNotLogin() {
        let snap = page(title: "Welcome", text: "Read our latest articles and news.")
        XCTAssertFalse(detector.isLoginPage(snap))
    }
}
