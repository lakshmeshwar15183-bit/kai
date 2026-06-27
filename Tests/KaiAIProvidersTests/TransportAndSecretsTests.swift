import XCTest
@testable import KaiAIProviders

final class MockTransportTests: XCTestCase {
    func testReturnsQueuedThenDefault() async throws {
        let transport = MockTransport(
            responses: [HTTPResponse(statusCode: 201, body: Data("a".utf8))],
            defaultResponse: HTTPResponse(statusCode: 200, body: Data("b".utf8))
        )
        let first = try await transport.send(HTTPRequest(url: URL(string: "https://x.com")!))
        let second = try await transport.send(HTTPRequest(url: URL(string: "https://x.com")!))
        XCTAssertEqual(first.statusCode, 201)
        XCTAssertEqual(second.statusCode, 200)
        let count = await transport.requests.count
        XCTAssertEqual(count, 2)
    }
}

final class SecretResolverTests: XCTestCase {
    func testEnvironmentResolverResolvesAndThrows() async throws {
        let resolver = EnvironmentSecretResolver(environment: ["OPENAI_API_KEY": "sk-test"])
        let value = try await resolver.resolve(reference: "OPENAI_API_KEY")
        XCTAssertEqual(value, "sk-test")

        do {
            _ = try await resolver.resolve(reference: "MISSING")
            XCTFail("expected missingAPIKey")
        } catch let error as AIProviderError {
            XCTAssertEqual(error, .missingAPIKey(reference: "MISSING"))
        }
    }

    func testStaticResolver() async throws {
        let resolver = StaticSecretResolver(["k": "v"])
        let value = try await resolver.resolve(reference: "k")
        XCTAssertEqual(value, "v")
    }
}
