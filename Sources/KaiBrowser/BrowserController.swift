import Foundation

/// Errors specific to browser automation.
public enum BrowserError: Error, Sendable, Equatable, CustomStringConvertible {
    case noActivePage
    case elementNotFound(label: String)
    case navigationFailed(reason: String)
    case authenticationTimedOut
    /// A driver refused to type into a password/secure field — Kai never enters
    /// credentials on the user's behalf.
    case refusedSecureField

    public var description: String {
        switch self {
        case .noActivePage: return "No active page."
        case let .elementNotFound(label): return "Element not found: \(label)."
        case let .navigationFailed(reason): return "Navigation failed: \(reason)."
        case .authenticationTimedOut: return "Timed out waiting for authentication."
        case .refusedSecureField: return "Refused to fill a secure (password) field."
        }
    }
}

/// The single contract through which Kai drives any browser. Concrete drivers
/// (Safari/Chrome/Edge via AppleScript & the accessibility tree on macOS, or the
/// in-memory fake used for tests) implement this.
///
/// Every method is async and throwing. Implementations must perform exactly one
/// observable action so the workflow engine can interrupt between calls. None of
/// these methods ever capture or persist credentials.
public protocol BrowserController: Sendable {
    /// Which browser this controller drives.
    var kind: BrowserKind { get }

    /// Opens a URL in a (new or current) tab.
    func open(_ url: URL) async throws

    /// Performs a back/forward/reload navigation.
    func navigate(_ action: NavigationAction) async throws

    /// Returns a snapshot of the current page.
    func snapshot() async throws -> PageSnapshot

    /// Clicks the first element whose label matches `label` (case-insensitive).
    func click(label: String) async throws

    /// Scrolls the viewport.
    func scroll(_ direction: ScrollDirection) async throws

    /// Types `value` into a non-secure field identified by `label`.
    ///
    /// Implementations MUST refuse to fill secure (password) fields — Kai never
    /// types credentials. See ``fill(field:value:)`` default behaviour.
    func fill(field label: String, value: String) async throws

    /// Extracts the readable text of the current page.
    func extractText() async throws -> String
}

public extension BrowserController {
    /// Convenience: the page's URL, or throws if there is none.
    func currentURL() async throws -> URL {
        try await snapshot().url
    }
}
