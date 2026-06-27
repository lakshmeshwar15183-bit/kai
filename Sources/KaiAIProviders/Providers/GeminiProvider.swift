import Foundation
import KaiAI

/// Talks to the Google Gemini `generateContent` API. The API key is passed as a
/// query parameter; system prompts use `systemInstruction`; assistant turns are
/// mapped to the `model` role.
public struct GeminiProvider: AIProvider {
    public let id = "gemini"
    public let model: String
    private let baseEndpoint: URL
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
        self.baseEndpoint = endpoint ?? URL(string: "https://generativelanguage.googleapis.com/v1beta")!
        self.apiKeyReference = apiKeyReference
        self.transport = transport
        self.resolver = resolver
    }

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        let key = try await resolver.resolve(reference: apiKeyReference)

        let contents = request.messages
            .filter { $0.role != .system }
            .map { RequestContent(role: $0.role == .assistant ? "model" : "user", parts: [RequestPart(text: $0.content)]) }
        let systemText = request.messages.filter { $0.role == .system }.map(\.content).joined(separator: "\n")

        let body = RequestBody(
            contents: contents,
            systemInstruction: systemText.isEmpty ? nil : RequestContent(role: "user", parts: [RequestPart(text: systemText)]),
            generationConfig: GenerationConfig(
                temperature: request.options.temperature,
                maxOutputTokens: request.options.maxTokens
            )
        )

        guard let url = URL(string: "\(baseEndpoint.absoluteString)/models/\(model):generateContent?key=\(key)") else {
            throw AIProviderError.invalidConfiguration(reason: "could not build Gemini URL")
        }

        let response: ResponseBody = try await ProviderHTTP.perform(
            transport: transport,
            url: url,
            headers: [:],
            body: body,
            decode: ResponseBody.self
        )

        // Current Gemini responses (gemini-1.5/2.x/3.x) may omit `role` on the
        // candidate content, and occasionally `parts`/`candidates`. Decode
        // leniently and take the first candidate that yields text.
        let text = response.candidates?
            .compactMap { $0.content?.parts?.compactMap(\.text).joined() }
            .first(where: { !$0.isEmpty }) ?? ""
        guard !text.isEmpty else {
            throw AIProviderError.decodingFailed(reason: "no candidate text in response")
        }
        return AIResponse(content: text, usage: AIUsage(
            promptTokens: response.usageMetadata?.promptTokenCount ?? 0,
            completionTokens: response.usageMetadata?.candidatesTokenCount ?? 0
        ))
    }

    // MARK: Wire format

    // Request (strict: Kai always supplies role + parts).
    private struct RequestPart: Encodable { let text: String }
    private struct RequestContent: Encodable { let role: String; let parts: [RequestPart] }
    private struct GenerationConfig: Encodable { let temperature: Double; let maxOutputTokens: Int? }
    private struct RequestBody: Encodable {
        let contents: [RequestContent]
        let systemInstruction: RequestContent?
        let generationConfig: GenerationConfig
    }

    // Response (lenient: `role`, `parts`, and `candidates` may be absent).
    private struct ResponsePart: Decodable { let text: String? }
    private struct ResponseContent: Decodable { let parts: [ResponsePart]?; let role: String? }
    private struct ResponseCandidate: Decodable { let content: ResponseContent? }
    private struct UsageMetadata: Decodable { let promptTokenCount: Int?; let candidatesTokenCount: Int? }
    private struct ResponseBody: Decodable {
        let candidates: [ResponseCandidate]?
        let usageMetadata: UsageMetadata?
    }
}

/// Factory that builds a ``GeminiProvider`` from configuration.
public struct GeminiProviderFactory: AIProviderFactory {
    public let id = "gemini"
    private let transport: any HTTPTransport
    private let resolver: any SecretResolver

    public init(transport: any HTTPTransport, resolver: any SecretResolver) {
        self.transport = transport
        self.resolver = resolver
    }

    public func makeProvider(config: AIProviderConfig) throws -> AIProvider {
        GeminiProvider(
            model: config.model,
            endpoint: config.endpoint,
            apiKeyReference: config.apiKeyReference ?? "GEMINI_API_KEY",
            transport: transport,
            resolver: resolver
        )
    }
}
