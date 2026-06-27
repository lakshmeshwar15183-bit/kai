import Foundation

/// Resolves a secret (such as an API key) from a *reference* rather than a
/// literal value. Providers hold only the reference; the real secret is fetched
/// at call time and never persisted in config or logs.
///
/// On macOS the production resolver reads the Keychain; elsewhere (CI, the CLI)
/// an environment-variable resolver is used.
public protocol SecretResolver: Sendable {
    /// Returns the secret for `reference`, or throws if it cannot be found.
    func resolve(reference: String) async throws -> String
}

/// Resolves secrets from environment variables. The `reference` is the
/// environment variable name (e.g. "OPENAI_API_KEY").
public struct EnvironmentSecretResolver: SecretResolver {
    private let environment: [String: String]

    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
    }

    public func resolve(reference: String) async throws -> String {
        guard let value = environment[reference], !value.isEmpty else {
            throw AIProviderError.missingAPIKey(reference: reference)
        }
        return value
    }
}

/// An explicit, in-memory resolver — handy for tests and for wiring a key that
/// was already obtained securely elsewhere.
public struct StaticSecretResolver: SecretResolver {
    private let secrets: [String: String]

    public init(_ secrets: [String: String]) {
        self.secrets = secrets
    }

    public func resolve(reference: String) async throws -> String {
        guard let value = secrets[reference], !value.isEmpty else {
            throw AIProviderError.missingAPIKey(reference: reference)
        }
        return value
    }
}
