import Foundation
import KaiCore
import KaiAI
import KaiMemory

/// A user instruction routed to plugins. For Milestone 1 this is the raw text
/// plus the active application context; later milestones enrich it with parsed
/// intent and structured entities.
public struct KaiCommand: Sendable, Equatable {
    public var text: String
    /// The frontmost application Kai should operate within, when known.
    public var activeApplication: String?

    public init(text: String, activeApplication: String? = nil) {
        self.text = text
        self.activeApplication = activeApplication
    }
}

/// The result of handling a command.
public struct CommandResult: Sendable, Equatable {
    public var message: String
    public var didSucceed: Bool
    public var metadata: [String: String]

    public init(message: String, didSucceed: Bool = true, metadata: [String: String] = [:]) {
        self.message = message
        self.didSucceed = didSucceed
        self.metadata = metadata
    }
}

/// The dependency-injection surface handed to a plugin when it runs. Plugins
/// never reach for globals; everything they need is provided here, which keeps
/// them testable and decoupled from the core.
public struct PluginServices: Sendable {
    public let ai: any AIProvider
    public let memory: any MemoryStore
    public let logger: KaiLogger
    public let stopController: StopController
    public let eventBus: EventBus

    public init(
        ai: any AIProvider,
        memory: any MemoryStore,
        logger: KaiLogger,
        stopController: StopController,
        eventBus: EventBus
    ) {
        self.ai = ai
        self.memory = memory
        self.logger = logger
        self.stopController = stopController
        self.eventBus = eventBus
    }
}

/// The contract every capability implements. Plugins are added without touching
/// the core: register a type conforming to `Plugin` and it becomes routable.
public protocol Plugin: Sendable {
    var manifest: PluginManifest { get }

    /// Bundle identifiers of the applications this plugin specialises in. When a
    /// command arrives while one of these apps is frontmost, the router prefers
    /// this plugin. `nil` means the plugin is application-agnostic.
    var supportedApplications: Set<String>? { get }

    /// Whether this plugin wants to handle the given command.
    func canHandle(_ command: KaiCommand) -> Bool

    /// The capability that `command` maps to, used to determine its permission
    /// level before execution. Return `nil` to fall back to the first capability.
    func capability(for command: KaiCommand) -> Capability?

    /// Performs the work. Implementations must respect `services.stopController`.
    func handle(_ command: KaiCommand, services: PluginServices) async throws -> CommandResult
}

public extension Plugin {
    var supportedApplications: Set<String>? { nil }

    func capability(for command: KaiCommand) -> Capability? {
        manifest.capabilities.first
    }
}
