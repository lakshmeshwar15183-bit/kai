import Foundation
import KaiCore

/// The catalogue of installed plugins. New capabilities are added purely by
/// registering here — the core and router need no modification.
public actor PluginRegistry {
    private var plugins: [String: any Plugin] = [:]
    private var order: [String] = []

    public init() {}

    /// Registers a plugin. Re-registering the same id replaces it.
    public func register(_ plugin: any Plugin) {
        let id = plugin.manifest.id
        if plugins[id] == nil {
            order.append(id)
        }
        plugins[id] = plugin
    }

    public func unregister(id: String) {
        plugins[id] = nil
        order.removeAll { $0 == id }
    }

    /// All plugins, in registration order.
    public func all() -> [any Plugin] {
        order.compactMap { plugins[$0] }
    }

    /// All manifests, for the plugin manager UI.
    public func manifests() -> [PluginManifest] {
        all().map { $0.manifest }
    }

    /// The first plugin (in registration order) that will handle `command`.
    public func handler(for command: KaiCommand) -> (any Plugin)? {
        all().first { $0.canHandle(command) }
    }

    /// Resolves a handler with Active Window Intelligence: among the plugins
    /// that can handle the command, one that specialises in the frontmost
    /// application wins; otherwise the first capable plugin (in registration
    /// order) is used.
    public func handler(for command: KaiCommand, in application: ApplicationContext?) -> (any Plugin)? {
        let capable = all().filter { $0.canHandle(command) }
        if let bundleID = application?.bundleIdentifier {
            if let appSpecific = capable.first(where: { $0.supportedApplications?.contains(bundleID) == true }) {
                return appSpecific
            }
        }
        return capable.first
    }
}
