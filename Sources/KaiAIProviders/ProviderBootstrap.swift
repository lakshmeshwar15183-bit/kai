import Foundation
import KaiAI

/// One-call registration of every built-in provider factory into an
/// ``AIProviderRegistry``. Adding a future vendor means adding its factory here
/// (or registering it separately) — no call site that *uses* a provider changes.
public enum ProviderBootstrap {
    /// Builds the standard set of factories sharing one transport and resolver.
    ///
    /// - Parameters:
    ///   - transport: HTTP transport (defaults to `URLSessionTransport`).
    ///   - resolver: Secret resolver for API keys (defaults to environment).
    public static func defaultFactories(
        transport: any HTTPTransport = URLSessionTransport(),
        resolver: any SecretResolver = EnvironmentSecretResolver()
    ) -> [any AIProviderFactory] {
        [
            OpenAIProviderFactory(transport: transport, resolver: resolver),
            AnthropicProviderFactory(transport: transport, resolver: resolver),
            GeminiProviderFactory(transport: transport, resolver: resolver),
            OllamaProviderFactory(transport: transport)
        ]
    }

    /// Registers all default factories into `registry`.
    public static func registerDefaults(
        into registry: AIProviderRegistry,
        transport: any HTTPTransport = URLSessionTransport(),
        resolver: any SecretResolver = EnvironmentSecretResolver()
    ) async {
        for factory in defaultFactories(transport: transport, resolver: resolver) {
            await registry.register(factory)
        }
    }
}
