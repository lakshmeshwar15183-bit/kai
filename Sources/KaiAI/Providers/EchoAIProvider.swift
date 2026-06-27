import Foundation

/// A deterministic, dependency-free provider used by the CLI demo and tests.
///
/// It does not call any network service; it echoes a transformed version of the
/// last user message. This lets the whole pipeline (commands → AI → response)
/// be exercised on Linux/CI without credentials, and serves as the reference
/// implementation of the ``AIProvider`` contract.
public struct EchoAIProvider: AIProvider {
    public let id = "echo"
    public let model: String

    public init(model: String = "echo-1") {
        self.model = model
    }

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        let lastUser = request.messages.last(where: { $0.role == .user })?.content ?? ""
        let content = "Kai (echo): \(lastUser)"
        let usage = AIUsage(
            promptTokens: request.messages.reduce(0) { $0 + $1.content.count },
            completionTokens: content.count
        )
        return AIResponse(content: content, usage: usage)
    }
}

/// Factory for the echo provider.
public struct EchoAIProviderFactory: AIProviderFactory {
    public let id = "echo"
    public init() {}
    public func makeProvider(config: AIProviderConfig) throws -> AIProvider {
        EchoAIProvider(model: config.model)
    }
}
