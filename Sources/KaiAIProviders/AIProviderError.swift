import Foundation

/// Errors raised by the concrete AI providers. This type is intentionally local
/// to `KaiAIProviders` rather than added to `KaiCore.KaiError`: keeping it here
/// avoids coupling the core to provider concerns and avoids modifying a shared
/// enum that crosses module boundaries.
public enum AIProviderError: Error, Sendable, Equatable, CustomStringConvertible {
    /// No API key could be resolved for the given reference.
    case missingAPIKey(reference: String)
    /// The provider returned a non-2xx HTTP status.
    case httpError(status: Int, message: String)
    /// The response body could not be decoded into the expected shape.
    case decodingFailed(reason: String)
    /// The transport itself failed (connectivity, timeout, etc.).
    case transportFailed(reason: String)
    /// The provider configuration was invalid (e.g. bad endpoint).
    case invalidConfiguration(reason: String)

    public var description: String {
        switch self {
        case let .missingAPIKey(reference):
            return "No API key found for reference '\(reference)'."
        case let .httpError(status, message):
            return "Provider HTTP \(status): \(message)"
        case let .decodingFailed(reason):
            return "Failed to decode provider response: \(reason)"
        case let .transportFailed(reason):
            return "Transport failed: \(reason)"
        case let .invalidConfiguration(reason):
            return "Invalid provider configuration: \(reason)"
        }
    }
}
