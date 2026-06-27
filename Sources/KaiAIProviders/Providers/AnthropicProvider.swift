import Foundation
import KaiAI

/// Talks to the Anthropic Messages API. System prompts are hoisted to the
/// top-level `system` field; only user/assistant turns go in `messages`.
public struct AnthropicProvider: AIProvider {
    public let id = "anthropic"
    public let model: String
    private let endpoint: URL
    private let apiKeyReference: String
    private let transport: any HTTPTransport
    private let resolver: any SecretResolver
    private let apiVersion: String
    /// Anthropic requires an explicit max_tokens; used when the request omits one.
    private let defaultMaxTokens: Int

    public init(
        model: String,
        endpoint: URL? = nil,
        apiKeyReference: String,
        transport: any HTTPTransport,
        resolver: any SecretResolver,
        apiVersion: String = "2023-06-01",
        defaultMaxTokens: Int = 1024
    ) {
        self.model = model
        self.endpoint = endpoint ?? URL(string: "https://api.anthropic.com/v1/messages")!
        self.apiKeyReference = apiKeyReference
        self.transport = transport
        self.resolver = resolver
        self.apiVersion = apiVersion
        self.defaultMaxTokens = defaultMaxTokens
    }

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        let key = try await resolver.resolve(reference: apiKeyReference)

        let systemText = request.messages
            .filter { $0.role == .system }
            .map(\.content)
            .joined(separator: "\n")
        let turns = request.messages
            .filter { $0.role != .system }
            .map { Message(role: $0.role.rawValue, content: $0.content) }

        let body = RequestBody(
            model: model,
            messages: turns,
            system: systemText.isEmpty ? nil : systemText,
            max_tokens: request.options.maxTokens ?? defaultMaxTokens,
            temperature: request.options.temperature
        )
        let response: ResponseBody = try await ProviderHTTP.perform(
            transport: transport,
            url: endpoint,
            headers: ["x-api-key": key, "anthropic-version": apiVersion],
            body: body,
            decode: ResponseBody.self
        )
        let content = response.content.compactMap { $0.text }.joined()
        guard !content.isEmpty else {
            throw AIProviderError.decodingFailed(reason: "no text content in response")
        }
        return AIResponse(content: content, usage: AIUsage(
            promptTokens: response.usage?.input_tokens ?? 0,
            completionTokens: response.usage?.output_tokens ?? 0
        ))
    }

    // MARK: Wire format
    private struct Message: Codable { let role: String; let content: String }
    private struct RequestBody: Encodable {
        let model: String
        let messages: [Message]
        let system: String?
        let max_tokens: Int
        let temperature: Double
    }
    private struct ResponseBody: Decodable {
        struct Block: Decodable { let type: String; let text: String? }
        struct Usage: Decodable { let input_tokens: Int?; let output_tokens: Int? }
        let content: [Block]
        let usage: Usage?
    }
}

/// Factory that builds an ``AnthropicProvider`` from configuration.
public struct AnthropicProviderFactory: AIProviderFactory {
    public let id = "anthropic"
    private let transport: any HTTPTransport
    private let resolver: any SecretResolver

    public init(transport: any HTTPTransport, resolver: any SecretResolver) {
        self.transport = transport
        self.resolver = resolver
    }

    public func makeProvider(config: AIProviderConfig) throws -> AIProvider {
        AnthropicProvider(
            model: config.model,
            endpoint: config.endpoint,
            apiKeyReference: config.apiKeyReference ?? "ANTHROPIC_API_KEY",
            transport: transport,
            resolver: resolver
        )
    }
}
