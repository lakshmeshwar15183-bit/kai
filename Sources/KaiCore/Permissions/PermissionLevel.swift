import Foundation

/// The three-tier permission model. Higher raw values are more restrictive.
public enum PermissionLevel: Int, Sendable, Codable, Comparable, CaseIterable {
    /// Safe, read-mostly actions (read files, open apps, search, summarize).
    case green = 0
    /// Reversible-but-impactful actions that require explicit confirmation
    /// (rename/move/delete files, send/delete emails, up/downloads).
    case yellow = 1
    /// High-risk actions that always require deliberate approval (banking,
    /// passwords/OTP, payments, system settings, privileged terminal commands).
    case red = 2

    public static func < (lhs: PermissionLevel, rhs: PermissionLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var displayName: String {
        switch self {
        case .green: return "Green (safe)"
        case .yellow: return "Yellow (confirm)"
        case .red: return "Red (approve)"
        }
    }
}

/// The decision the permission engine reaches for a specific action. The UI
/// uses this to decide whether to act silently, show a confirmation dialog, or
/// show a stronger approval dialog.
public enum PermissionDecision: Sendable, Equatable {
    case allowed
    case needsConfirmation
    case needsApproval
    case denied

    public init(level: PermissionLevel) {
        switch level {
        case .green: self = .allowed
        case .yellow: self = .needsConfirmation
        case .red: self = .needsApproval
        }
    }
}
