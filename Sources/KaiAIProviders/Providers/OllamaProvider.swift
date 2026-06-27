import Foundation
import KaiAI

/// Talks to a local Ollama server (`/api/chat`). No API key is required, which
/// makes it the privacy-preserving default for fully on-device inference.
public struct OllamaProvider: AIProvider {
    public let id = "ollama"
    public let model: String
    private let endpoint: URL
    private let transport: any HTTPTransport

    public init(
        model: String,
        endpoint: URL? = nil,
        transport: any HTTPTransport
    ) {
        self.model = model
        self.endpoint = endpoint ?? URL(string: "http://localhost:11434/api/chat")!
        self.transport = transport
    }

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        let body = RequestBody(
            model: model,
            messages: request.messages.map { Message(role: $0.role.rawValue, content: $0.content) },
            stream: false,
            options: Options(temperature: request.options.temperature)
        )
        let response: ResponseBody = try await ProviderHTTP.perform(
            transport: transport,
            url: endpoint,
            headers: [:],
            body: body,
            decode: ResponseBody.self
        )
        return AIResponse(content: response.message.content, usage: AIUsage(
            promptTokens: response.prompt_eval_count ?? 0,
            completionTokens: response.eval_count ?? 0
        ))
    }

    // MARK: Wire format
    private struct Message: Codable { let role: String; let content: String }
    private struct Options: Encodable { let temperature: Double }
    private struct RequestBody: Encodable {
        let model: String
        let messages: [Message]
        let stream: Bool
        let options: Options
    }
    private struct ResponseBody: Decodable {
        let message: Message
        let prompt_eval_count: Int?
        let eval_count: Int?
    }
}

/// Factory that builds an ``OllamaProvider`` from configuration. The API-key
/// reference is ignored (local inference needs no credentials).
public struct OllamaProviderFactory: AIProviderFactory {
    public let id = "ollama"
    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport) {
        self.transport = transport
    }

    public func makeProvider(config: AIProviderConfig) throws -> AIProvider {
        OllamaProvider(model: config.model, endpoint: config.endpoint, transport: transport)
    }
}
