import Foundation
import KaiCore

/// A discrete capability a plugin offers, with the default permission level the
/// permission engine should start from. The engine may escalate (never
/// de-escalate) this based on the actual command text.
public struct Capability: Sendable, Codable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var summary: String
    public var defaultPermissionLevel: PermissionLevel
    /// Whether invoking this capability changes state in the world (clicks,
    /// typing, file/email/network mutations). Read-only capabilities
    /// (summarize, extract, answer) set this to `false` and remain available in
    /// Observe mode. Defaults to `true` so an undeclared capability is treated
    /// as mutating — fail safe.
    public var sideEffect: Bool

    public init(
        id: String,
        name: String,
        summary: String,
        defaultPermissionLevel: PermissionLevel,
        sideEffect: Bool = true
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.defaultPermissionLevel = defaultPermissionLevel
        self.sideEffect = sideEffect
    }
}

/// Self-describing metadata for a plugin. The plugin manager UI renders this,
/// and the router uses the declared capabilities for permission decisions.
public struct PluginManifest: Sendable, Codable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var version: String
    public var author: String
    public var summary: String
    public var capabilities: [Capability]

    public init(
        id: String,
        name: String,
        version: String,
        author: String,
        summary: String,
        capabilities: [Capability]
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.author = author
        self.summary = summary
        self.capabilities = capabilities
    }
}
