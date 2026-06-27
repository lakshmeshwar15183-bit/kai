import Foundation

/// Decodes request-body `Data` (which is Sendable and safe to move across actor
/// boundaries) into a JSON dictionary for assertions in tests.
func decodeJSONObject(_ data: Data?) -> [String: Any]? {
    guard let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
    }
    return object
}
