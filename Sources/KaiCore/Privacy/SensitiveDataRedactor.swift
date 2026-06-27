import Foundation

/// Central privacy primitive. Kai must *never* persist or log secrets such as
/// passwords, PINs, OTPs, banking credentials, card numbers, or auth tokens.
///
/// The redactor is used in two ways:
///  - `classify(key:value:)` lets the memory layer *reject* sensitive writes
///    outright rather than trusting callers.
///  - `redact(_:)` scrubs free-form text before it reaches logs.
public struct SensitiveDataRedactor: Sendable {
    /// Substrings that, when found in a *key/field name*, mark the value as secret.
    private let sensitiveKeyTokens: [String]
    /// Compiled regular expressions that match secret-looking *values*.
    private let valuePatterns: [NSRegularExpression]
    /// Replacement text used when redacting.
    public let mask: String

    public init(mask: String = "•••redacted•••") {
        self.mask = mask
        self.sensitiveKeyTokens = [
            "password", "passwd", "pwd", "secret", "pin",
            "otp", "mfa", "2fa", "token", "apikey", "api_key",
            "access_key", "private_key", "credential", "cvv", "cvc",
            "card", "ssn", "iban", "routing", "account_number",
            "auth", "bearer", "session", "cookie"
        ]
        let patterns = [
            // Credit-card-like sequences (13–16 digits, optional separators).
            #"\b(?:\d[ -]*?){13,16}\b"#,
            // Standalone 4–8 digit OTP / PIN codes.
            #"\b\d{4,8}\b"#,
            // Bearer tokens.
            #"(?i)bearer\s+[A-Za-z0-9._\-]+"#,
            // Long opaque token strings (JWT-ish / API keys).
            #"\b[A-Za-z0-9_\-]{32,}\b"#
        ]
        self.valuePatterns = patterns.compactMap {
            try? NSRegularExpression(pattern: $0)
        }
    }

    /// Classification of a candidate key/value pair.
    public enum Classification: Sendable, Equatable {
        case safe
        /// The data looks sensitive and must not be persisted. The associated
        /// string explains which rule matched (for diagnostics, never the value).
        case sensitive(reason: String)
    }

    /// Determines whether a key/value pair may be persisted to memory.
    public func classify(key: String, value: String) -> Classification {
        let loweredKey = key.lowercased()
        for token in sensitiveKeyTokens where loweredKey.contains(token) {
            return .sensitive(reason: "key contains '\(token)'")
        }
        if matchesSensitiveValue(value) {
            return .sensitive(reason: "value matches a secret pattern")
        }
        return .safe
    }

    /// Returns true if a free-form value resembles a secret.
    public func matchesSensitiveValue(_ value: String) -> Bool {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        for pattern in valuePatterns {
            if pattern.firstMatch(in: value, range: range) != nil {
                return true
            }
        }
        return false
    }

    /// Returns a copy of `text` with secret-looking substrings masked. Safe to
    /// apply to anything heading for a log.
    public func redact(_ text: String) -> String {
        var result = text
        for pattern in valuePatterns {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = pattern.stringByReplacingMatches(
                in: result,
                range: range,
                withTemplate: mask
            )
        }
        return result
    }
}
