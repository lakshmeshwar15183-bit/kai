import Foundation

/// The single seam through which Kai talks to any large language model.
///
/// Swapping providers (local model, OpenAI, Anthropic, Gemini, future vendors)
/// must require only configuration changes — never changes to application
/// logic. Every concrete provider conforms to this protocol and is selected at
/// runtime by ``AIProviderRegistry`` from an ``AIProviderConfig``.
public protocol AIProvider: Sendable {
    /// Stable identifier, e.g. "openai", "anthropic", "gemini", "local".
    var id: String { get }

    /// The model this instance is configured to use, for display/logging.
    var model: String { get }

    /// Produces a single completion for the given request.
    func complete(_ request: AIRequest) async throws -> AIResponse

    /// Produces a streamed completion as a sequence of text chunks. Providers
    /// that do not support streaming get a default implementation that yields
    /// the full completion as one chunk.
    func stream(_ request: AIRequest) -> AsyncThrowingStream<String, Error>
}

public extension AIProvider {
    func stream(_ request: AIRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let response = try await complete(request)
                    continuation.yield(response.content)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

/// Builds a concrete ``AIProvider`` from configuration. Each registered factory
/// owns one provider id. This is the extension point for adding new vendors.
public protocol AIProviderFactory: Sendable {
    var id: String { get }
    func makeProvider(config: AIProviderConfig) throws -> AIProvider
}
