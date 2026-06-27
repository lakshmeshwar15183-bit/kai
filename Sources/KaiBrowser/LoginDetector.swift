import Foundation

/// Decides whether the current page is asking the user to authenticate.
///
/// Kai never types credentials or bypasses login. Instead, when this detector
/// flags a page, the browser plugin pauses and hands control back to the user,
/// resuming only once the page is no longer a login screen.
public struct LoginDetector: Sendable {
    private let keywords: [String]

    public init() {
        self.keywords = [
            "sign in", "signin", "log in", "login", "logon",
            "password", "two-factor", "2fa", "verification code",
            "one-time", "otp", "authenticate", "create account"
        ]
    }

    /// A page is treated as a login page if it exposes a secure (password) field,
    /// or if its title/URL/visible text strongly signals authentication.
    public func isLoginPage(_ snapshot: PageSnapshot) -> Bool {
        if snapshot.hasSecureField {
            return true
        }
        let haystack = ([
            snapshot.title,
            snapshot.url.absoluteString,
            snapshot.text
        ].joined(separator: " ")).lowercased()

        // Require a reasonably specific signal to avoid false positives on pages
        // that merely link to a login.
        let strongSignals = ["sign in", "log in", "login", "verification code", "one-time", "two-factor"]
        return strongSignals.contains { haystack.contains($0) }
    }

    /// All keyword signals (exposed for diagnostics/tests).
    public var signals: [String] { keywords }
}
