import Foundation
import KaiAI

/// Talks to the OpenAI Chat Completions API.
public struct OpenAIProvider: AIProvider {
    public let id = "openai"
    public let model: String
    private let endpoint: URL
    private let apiKeyReference: String
    private let transport: any HTTPTransport
    private let resolver: any SecretResolver

    public init(
        model: String,
        endpoint: URL? = nil,
        apiKeyReference: String,
        transport: any HTTPTransport,
        resolver: any SecretResolver
    ) {
        self.model = model
        self.endpoint = endpoint ?? URL(string: "https://api.openai.com/v1/chat/completions")!
        self.apiKeyReference = apiKeyReference
        self.transport = transport
        self.resolver = resolver
    }

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        let key = try await resolver.resolve(reference: apiKeyReference)
        let body = RequestBody(
            model: model,
            messages: request.messages.map { Message(role: $0.role.rawValue, content: $0.content) },
            temperature: request.options.temperature,
            max_tokens: request.options.maxTokens
        )
        let response: ResponseBody = try await ProviderHTTP.perform(
            transport: transport,
            url: endpoint,
            headers: ["Authorization": "Bearer \(key)"],
            body: body,
            decode: ResponseBody.self
        )
        guard let content = response.choices.first?.message.content else {
            throw AIProviderError.decodingFailed(reason: "no choices in response")
        }
        return AIResponse(content: content, usage: AIUsage(
            promptTokens: response.usage?.prompt_tokens ?? 0,
            completionTokens: response.usage?.completion_tokens ?? 0
        ))
    }

    // MARK: Wire format
    private struct Message: Codable { let role: String; let content: String }
    private struct RequestBody: Encodable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int?
    }
    private struct ResponseBody: Decodable {
        struct Choice: Decodable { let message: Message }
        struct Usage: Decodable { let prompt_tokens: Int?; let completion_tokens: Int? }
        let choices: [Choice]
        let usage: Usage?
    }
}

/// Factory that builds an ``OpenAIProvider`` from configuration.
public struct OpenAIProviderFactory: AIProviderFactory {
    public let id = "openai"
    private let transport: any HTTPTransport
    private let resolver: any SecretResolver

    public init(transport: any HTTPTransport, resolver: any SecretResolver) {
        self.transport = transport
        self.resolver = resolver
    }

    public func makeProvider(config: AIProviderConfig) throws -> AIProvider {
        OpenAIProvider(
            model: config.model,
            endpoint: config.endpoint,
            apiKeyReference: config.apiKeyReference ?? "OPENAI_API_KEY",
            transport: transport,
            resolver: resolver
        )
    }
}
