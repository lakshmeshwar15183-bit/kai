import XCTest
@testable import KaiAIProviders
import KaiAI

final class OpenAIProviderTests: XCTestCase {
    private let resolver = StaticSecretResolver(["OPENAI_API_KEY": "sk-test"])

    func testCompleteParsesContentAndUsage() async throws {
        let json = """
        {"choices":[{"message":{"role":"assistant","content":"Hello!"}}],
         "usage":{"prompt_tokens":5,"completion_tokens":2}}
        """
        let transport = MockTransport(json: json)
        let provider = OpenAIProvider(model: "gpt-4o", apiKeyReference: "OPENAI_API_KEY",
                                      transport: transport, resolver: resolver)

        let response = try await provider.complete(AIRequest(messages: [.system("s"), .user("hi")]))
        XCTAssertEqual(response.content, "Hello!")
        XCTAssertEqual(response.usage.totalTokens, 7)

        // Request shaping.
        let last = await transport.lastRequest
        XCTAssertEqual(last?.url.absoluteString, "https://api.openai.com/v1/chat/completions")
        XCTAssertEqual(last?.headers["Authorization"], "Bearer sk-test")
        let bodyJSON = decodeJSONObject(await transport.lastRequest?.body)
        XCTAssertEqual(bodyJSON?["model"] as? String, "gpt-4o")
        XCTAssertEqual((bodyJSON?["messages"] as? [[String: Any]])?.count, 2)
    }

    func testMissingKeyThrows() async {
        let transport = MockTransport(json: "{}")
        let provider = OpenAIProvider(model: "gpt-4o", apiKeyReference: "OPENAI_API_KEY",
                                      transport: transport, resolver: StaticSecretResolver([:]))
        do {
            _ = try await provider.complete(AIRequest(messages: [.user("hi")]))
            XCTFail("expected missingAPIKey")
        } catch let error as AIProviderError {
            XCTAssertEqual(error, .missingAPIKey(reference: "OPENAI_API_KEY"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testHTTPErrorIsMapped() async {
        let transport = MockTransport(json: "rate limited", status: 429)
        let provider = OpenAIProvider(model: "gpt-4o", apiKeyReference: "OPENAI_API_KEY",
                                      transport: transport, resolver: resolver)
        do {
            _ = try await provider.complete(AIRequest(messages: [.user("hi")]))
            XCTFail("expected httpError")
        } catch let error as AIProviderError {
            guard case let .httpError(status, _) = error else { return XCTFail("wrong error: \(error)") }
            XCTAssertEqual(status, 429)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
