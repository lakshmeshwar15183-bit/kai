import Foundation
import KaiCore

/// Holds the available provider factories and constructs the active provider
/// from configuration. Adding a new vendor means registering a factory — no
/// changes to call sites.
public actor AIProviderRegistry {
    private var factories: [String: any AIProviderFactory] = [:]

    public init(factories: [any AIProviderFactory] = []) {
        for factory in factories {
            self.factories[factory.id] = factory
        }
    }

    /// Registers (or replaces) a factory for its provider id.
    public func register(_ factory: any AIProviderFactory) {
        factories[factory.id] = factory
    }

    public var registeredIDs: [String] {
        factories.keys.sorted()
    }

    /// Builds the provider described by `config`.
    public func makeProvider(config: AIProviderConfig) throws -> AIProvider {
        guard let factory = factories[config.providerID] else {
            throw KaiError.providerUnavailable(id: config.providerID)
        }
        return try factory.makeProvider(config: config)
    }
}
