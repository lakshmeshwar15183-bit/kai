#if os(macOS)
import Foundation
import Security

/// Errors from Keychain access.
public enum KeychainError: Error, Sendable, Equatable, CustomStringConvertible {
    case unexpectedStatus(OSStatus)

    public var description: String {
        switch self {
        case let .unexpectedStatus(status):
            return "Keychain error (OSStatus \(status))."
        }
    }
}

/// Reads and writes secrets (API keys) in the macOS Keychain as generic-password
/// items under a single service. The `account` is the reference name used by the
/// provider config (e.g. "OPENAI_API_KEY"). Secrets live only here — never in
/// config files, the memory store, or logs.
public struct KeychainStore: Sendable {
    public let service: String

    public init(service: String = "com.kai.apikeys") {
        self.service = service
    }

    /// Stores (or replaces) the secret for `account`.
    public func set(_ value: String, account: String) throws {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary) // idempotent replace
        var attributes = base
        attributes[kSecValueData as String] = Data(value.utf8)
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    /// Returns the secret for `account`, or nil if absent.
    public func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    /// Deletes the secret for `account` (no-op if absent).
    public func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Whether a non-empty secret exists for `account`.
    public func hasValue(account: String) -> Bool {
        get(account: account) != nil
    }
}
#endif
