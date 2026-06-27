import XCTest
@testable import KaiBrowser

final class BrowserCommandParserTests: XCTestCase {
    private let parser = BrowserCommandParser()

    func testParsesOpenWithScheme() {
        XCTAssertEqual(parser.parse("open https://apple.com"), .open(URL(string: "https://apple.com")!))
    }

    func testParsesBareDomainAsHTTPS() {
        XCTAssertEqual(parser.parse("go to example.com"), .open(URL(string: "https://example.com")!))
    }

    func testParsesNavigation() {
        XCTAssertEqual(parser.parse("go back"), .navigate(.back))
        XCTAssertEqual(parser.parse("reload"), .navigate(.reload))
        XCTAssertEqual(parser.parse("forward"), .navigate(.forward))
    }

    func testParsesScroll() {
        XCTAssertEqual(parser.parse("scroll down"), .scroll(.down))
        XCTAssertEqual(parser.parse("scroll to top"), .scroll(.top))
        XCTAssertEqual(parser.parse("scroll"), .scroll(.down))
    }

    func testParsesClick() {
        XCTAssertEqual(parser.parse("click Submit"), .click(label: "Submit"))
        XCTAssertEqual(parser.parse("press \"Log in\""), .click(label: "Log in"))
    }

    func testParsesFillBothPatterns() {
        XCTAssertEqual(parser.parse("fill email with me@example.com"), .fill(field: "email", value: "me@example.com"))
        XCTAssertEqual(parser.parse("type hello in search"), .fill(field: "search", value: "hello"))
    }

    func testParsesReadAndSummarize() {
        XCTAssertEqual(parser.parse("read the page"), .readPage)
        XCTAssertEqual(parser.parse("summarize this page"), .summarize)
        XCTAssertEqual(parser.parse("what's on this page"), .readPage)
    }

    func testParsesWaitForLogin() {
        XCTAssertEqual(parser.parse("continue after login"), .waitForLogin)
        XCTAssertEqual(parser.parse("wait for authentication"), .waitForLogin)
    }

    func testReturnsNilForPlainConversation() {
        XCTAssertNil(parser.parse("what is the capital of France?"))
        XCTAssertNil(parser.parse("hello there"))
    }
}
