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

    public init(id: String, name: String, summary: String, defaultPermissionLevel: PermissionLevel) {
        self.id = id
        self.name = name
        self.summary = summary
        self.defaultPermissionLevel = defaultPermissionLevel
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
