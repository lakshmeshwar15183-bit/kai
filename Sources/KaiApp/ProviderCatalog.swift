import Foundation

/// A selectable AI provider option shown in Settings.
public struct ProviderOption: Identifiable, Sendable, Equatable {
    public let id: String          // matches AIProviderConfig.providerID
    public let name: String        // display name
    public let defaultModel: String
    /// Keychain account name for the API key, or nil if no key is required.
    public let keychainAccount: String?

    public var requiresKey: Bool { keychainAccount != nil }
}

/// The built-in providers the Settings screen offers. The `keychainAccount`
/// values match each provider factory's default `apiKeyReference`, so a key
/// saved here is found automatically at call time.
public enum ProviderCatalog {
    public static let all: [ProviderOption] = [
        ProviderOption(id: "openai", name: "OpenAI", defaultModel: "gpt-4o", keychainAccount: "OPENAI_API_KEY"),
        ProviderOption(id: "anthropic", name: "Anthropic", defaultModel: "claude-3-5-sonnet-latest", keychainAccount: "ANTHROPIC_API_KEY"),
        ProviderOption(id: "gemini", name: "Google Gemini", defaultModel: "gemini-1.5-flash", keychainAccount: "GEMINI_API_KEY"),
        ProviderOption(id: "ollama", name: "Ollama (local)", defaultModel: "llama3", keychainAccount: nil)
    ]

    public static func option(_ id: String) -> ProviderOption? {
        all.first { $0.id == id }
    }
}
