import XCTest
@testable import KaiCore

final class SensitiveDataRedactorTests: XCTestCase {
    private let redactor = SensitiveDataRedactor()

    func testClassifiesSensitiveKeys() {
        if case .safe = redactor.classify(key: "userPassword", value: "anything") {
            XCTFail("password key should be sensitive")
        }
        if case .sensitive = redactor.classify(key: "preferredBrowser", value: "Safari") {
            XCTFail("preferredBrowser should be safe")
        }
    }

    func testClassifiesSensitiveValues() {
        // OTP-like value.
        if case .safe = redactor.classify(key: "note", value: "482913") {
            XCTFail("OTP-like value should be sensitive")
        }
    }

    func testRedactScrubsSecrets() {
        let scrubbed = redactor.redact("the code is 482913 ok")
        XCTAssertFalse(scrubbed.contains("482913"))
        XCTAssertTrue(scrubbed.contains(redactor.mask))
    }
}

final class EventBusTests: XCTestCase {
    func testSubscriberReceivesPublishedEvent() async {
        let bus = EventBus()
        let stream = await bus.subscribe()

        let received = Task { () -> KaiEvent? in
            for await event in stream { return event }
            return nil
        }

        await bus.publish(KaiEvent(kind: .log(level: .info, message: "hello")))

        let event = await received.value
        guard case let .log(level, message)? = event?.kind else {
            return XCTFail("expected a log event")
        }
        XCTAssertEqual(level, .info)
        XCTAssertEqual(message, "hello")
    }
}
