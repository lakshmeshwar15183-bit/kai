#if os(macOS)
import Foundation

/// macOS ``SecretResolver`` backed by the Keychain (via ``KeychainStore``). The
/// `reference` is the account name of a generic password item.
///
/// This is the production resolver on macOS: API keys live in the user's
/// Keychain, never in Kai's config files, memory store, or logs.
public struct KeychainSecretResolver: SecretResolver {
    private let store: KeychainStore

    public init(service: String = "com.kai.apikeys") {
        self.store = KeychainStore(service: service)
    }

    public func resolve(reference: String) async throws -> String {
        guard let secret = store.get(account: reference) else {
            throw AIProviderError.missingAPIKey(reference: reference)
        }
        return secret
    }
}
#endif
