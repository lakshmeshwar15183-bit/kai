import Foundation

/// Asked by the permission engine to obtain a user decision for guarded
/// (Yellow/Red) actions. The macOS app implements this with a dialog; tests and
/// the CLI provide scripted implementations.
public protocol PermissionPrompting: Sendable {
    /// Returns `true` if the user authorizes the action.
    func requestDecision(action: String, level: PermissionLevel) async -> Bool
}

/// A prompting strategy that denies everything that needs a decision. Useful as
/// a safe default and in tests where no human is present.
public struct DenyingPrompter: PermissionPrompting {
    public init() {}
    public func requestDecision(action: String, level: PermissionLevel) async -> Bool {
        false
    }
}

/// Evaluates and authorizes actions against the three-tier permission model.
///
/// The effective level for an action is the *most restrictive* of:
///  1. the level declared by the capability/plugin, and
///  2. the level inferred from scanning the action text for red/yellow signals.
///
/// This means a plugin can never accidentally under-classify a dangerous action:
/// if the text mentions "password" or "payment", it is treated as Red even if
/// the plugin declared Green.
public struct PermissionEngine: Sendable {
    private let redKeywords: [String]
    private let yellowKeywords: [String]

    public init() {
        self.redKeywords = [
            "bank", "banking", "password", "passwd", "otp", "one-time",
            "credit card", "debit card", "card number", "cvv", "payment",
            "pay ", "transfer money", "wire", "system settings",
            "system preferences", "sudo", "root", "keychain", "ssn",
            "social security", "pin code", "wallet", "crypto", "seed phrase"
        ]
        self.yellowKeywords = [
            "delete", "remove", "rename", "move ", "trash", "upload",
            "download", "send email", "archive", "compress", "overwrite",
            "replace", "empty trash"
        ]
    }

    /// Infers a level purely from the action text.
    public func inferLevel(forAction action: String) -> PermissionLevel {
        let lowered = action.lowercased()
        if redKeywords.contains(where: { lowered.contains($0) }) {
            return .red
        }
        if yellowKeywords.contains(where: { lowered.contains($0) }) {
            return .yellow
        }
        return .green
    }

    /// Computes the effective level: the more restrictive of declared and inferred.
    public func effectiveLevel(forAction action: String, declared: PermissionLevel) -> PermissionLevel {
        max(declared, inferLevel(forAction: action))
    }

    /// Returns the decision for an action without prompting.
    public func evaluate(action: String, declared: PermissionLevel = .green) -> PermissionDecision {
        PermissionDecision(level: effectiveLevel(forAction: action, declared: declared))
    }

    /// Authorizes an action, prompting the user when the effective level requires
    /// it. Green actions are allowed silently; Yellow/Red consult `prompter`.
    public func authorize(
        action: String,
        declared: PermissionLevel = .green,
        using prompter: PermissionPrompting
    ) async -> Bool {
        let level = effectiveLevel(forAction: action, declared: declared)
        switch PermissionDecision(level: level) {
        case .allowed:
            return true
        case .needsConfirmation, .needsApproval:
            return await prompter.requestDecision(action: action, level: level)
        case .denied:
            return false
        }
    }
}
