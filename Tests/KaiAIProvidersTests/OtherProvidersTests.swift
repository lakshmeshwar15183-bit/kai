import XCTest
@testable import KaiAIProviders
import KaiAI

final class AnthropicProviderTests: XCTestCase {
    func testHoistsSystemAndParsesContent() async throws {
        let json = """
        {"content":[{"type":"text","text":"Hi there"}],
         "usage":{"input_tokens":3,"output_tokens":4}}
        """
        let transport = MockTransport(json: json)
        let provider = AnthropicProvider(model: "claude-3-5-sonnet", apiKeyReference: "ANTHROPIC_API_KEY",
                                         transport: transport, resolver: StaticSecretResolver(["ANTHROPIC_API_KEY": "k"]))
        let response = try await provider.complete(AIRequest(messages: [.system("be brief"), .user("hi"), .assistant("ok"), .user("again")]))
        XCTAssertEqual(response.content, "Hi there")
        XCTAssertEqual(response.usage.totalTokens, 7)

        let last = await transport.lastRequest
        XCTAssertEqual(last?.headers["x-api-key"], "k")
        XCTAssertEqual(last?.headers["anthropic-version"], "2023-06-01")
        let body = decodeJSONObject(await transport.lastRequest?.body)
        XCTAssertEqual(body?["system"] as? String, "be brief")
        // System message must NOT appear in messages (only user/assistant turns).
        XCTAssertEqual((body?["messages"] as? [[String: Any]])?.count, 3)
        XCTAssertNotNil(body?["max_tokens"])
    }
}

final class GeminiProviderTests: XCTestCase {
    func testURLContainsModelAndKeyAndParses() async throws {
        let json = """
        {"candidates":[{"content":{"role":"model","parts":[{"text":"Gem"}]}}],
         "usageMetadata":{"promptTokenCount":1,"candidatesTokenCount":1}}
        """
        let transport = MockTransport(json: json)
        let provider = GeminiProvider(model: "gemini-1.5", apiKeyReference: "GEMINI_API_KEY",
                                      transport: transport, resolver: StaticSecretResolver(["GEMINI_API_KEY": "gkey"]))
        let response = try await provider.complete(AIRequest(messages: [.user("hi")]))
        XCTAssertEqual(response.content, "Gem")

        let last = await transport.lastRequest
        let urlString = last?.url.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("models/gemini-1.5:generateContent"))
        XCTAssertTrue(urlString.contains("key=gkey"))
    }
}

final class OllamaProviderTests: XCTestCase {
    func testNoKeyRequiredAndParses() async throws {
        let json = """
        {"message":{"role":"assistant","content":"local reply"},"prompt_eval_count":2,"eval_count":3}
        """
        let transport = MockTransport(json: json)
        let provider = OllamaProvider(model: "llama3", transport: transport)
        let response = try await provider.complete(AIRequest(messages: [.user("hi")]))
        XCTAssertEqual(response.content, "local reply")
        XCTAssertEqual(response.usage.totalTokens, 5)

        let last = await transport.lastRequest
        XCTAssertEqual(last?.url.absoluteString, "http://localhost:11434/api/chat")
    }
}
