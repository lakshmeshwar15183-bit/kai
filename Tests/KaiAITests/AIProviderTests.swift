import XCTest
@testable import KaiAI
import KaiCore

final class AIProviderTests: XCTestCase {
    func testEchoProviderEchoesLastUserMessage() async throws {
        let provider = EchoAIProvider()
        let request = AIRequest(messages: [.system("sys"), .user("hello world")])
        let response = try await provider.complete(request)
        XCTAssertTrue(response.content.contains("hello world"))
        XCTAssertGreaterThan(response.usage.totalTokens, 0)
    }

    func testStreamYieldsFullCompletion() async throws {
        let provider = EchoAIProvider()
        let request = AIRequest(messages: [.user("stream me")])
        var chunks: [String] = []
        for try await chunk in provider.stream(request) {
            chunks.append(chunk)
        }
        XCTAssertEqual(chunks.joined().contains("stream me"), true)
    }

    func testRegistryBuildsRegisteredProvider() async throws {
        let registry = AIProviderRegistry(factories: [EchoAIProviderFactory()])
        let config = AIProviderConfig(providerID: "echo", model: "echo-test")
        let provider = try await registry.makeProvider(config: config)
        XCTAssertEqual(provider.id, "echo")
        XCTAssertEqual(provider.model, "echo-test")
    }

    func testRegistryThrowsForUnknownProvider() async {
        let registry = AIProviderRegistry()
        let config = AIProviderConfig(providerID: "missing", model: "x")
        do {
            _ = try await registry.makeProvider(config: config)
            XCTFail("expected providerUnavailable")
        } catch let error as KaiError {
            XCTAssertEqual(error, .providerUnavailable(id: "missing"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
