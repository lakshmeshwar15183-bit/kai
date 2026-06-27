import Foundation

/// Lightweight persistence for the user's provider choice (not secrets — those
/// go to the Keychain). Backed by `UserDefaults` so the selection survives
/// relaunches.
public enum AppSettings {
    private static let providerIDKey = "kai.provider.id"
    private static let providerModelKey = "kai.provider.model"

    public static func saveProvider(id: String, model: String) {
        let defaults = UserDefaults.standard
        defaults.set(id, forKey: providerIDKey)
        defaults.set(model, forKey: providerModelKey)
    }

    public static func savedProviderID() -> String? {
        UserDefaults.standard.string(forKey: providerIDKey)
    }

    public static func savedModel() -> String? {
        UserDefaults.standard.string(forKey: providerModelKey)
    }

    public static func clearProvider() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: providerIDKey)
        defaults.removeObject(forKey: providerModelKey)
    }
}
