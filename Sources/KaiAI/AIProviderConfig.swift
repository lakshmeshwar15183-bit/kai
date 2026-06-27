import Foundation

/// Configuration that selects and parameterizes an AI provider. This is the
/// *only* thing that changes when switching vendors.
///
/// Note: API keys are intentionally NOT stored here as plain values that get
/// persisted. The `apiKeyReference` names a secret to be resolved from the
/// macOS Keychain at runtime, so credentials never live in config files or logs.
public struct AIProviderConfig: Sendable, Codable, Equatable {
    /// Which provider to instantiate, e.g. "openai", "anthropic", "local".
    public var providerID: String
    /// Model identifier understood by the provider.
    public var model: String
    /// Name of the Keychain entry that holds the API key (resolved at runtime).
    public var apiKeyReference: String?
    /// Optional base URL override (self-hosted / proxy / local server).
    public var endpoint: URL?
    /// Default generation options for this provider.
    public var defaultOptions: AIGenerationOptions

    public init(
        providerID: String,
        model: String,
        apiKeyReference: String? = nil,
        endpoint: URL? = nil,
        defaultOptions: AIGenerationOptions = .default
    ) {
        self.providerID = providerID
        self.model = model
        self.apiKeyReference = apiKeyReference
        self.endpoint = endpoint
        self.defaultOptions = defaultOptions
    }
}
