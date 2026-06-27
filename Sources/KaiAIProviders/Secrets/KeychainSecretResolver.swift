#if os(macOS)
import Foundation
import Security

/// macOS ``SecretResolver`` backed by the Keychain. The `reference` is the
/// account name of a generic password item stored under a fixed service.
///
/// This is the production resolver on macOS: API keys live in the user's
/// Keychain, never in Kai's config files, memory store, or logs.
public struct KeychainSecretResolver: SecretResolver {
    private let service: String

    public init(service: String = "com.kai.apikeys") {
        self.service = service
    }

    public func resolve(reference: String) async throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: reference,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let secret = String(data: data, encoding: .utf8),
              !secret.isEmpty else {
            throw AIProviderError.missingAPIKey(reference: reference)
        }
        return secret
    }
}
#endif
