import Foundation
import KaiCore

/// Routes a user command to the right plugin, but only after enforcing the
/// permission model. This is the choke point that guarantees no guarded action
/// runs without the appropriate Green/Yellow/Red handling.
///
/// Responsibilities, in order:
///  1. Intercept Stop/Pause/Cancel/Abort and halt immediately.
///  2. Honour any pending stop request.
///  3. Find a plugin that can handle the command.
///  4. Determine the effective permission level and authorize (prompting if
///     Yellow/Red), emitting permission events for the activity log.
///  5. Execute the plugin with injected services.
public struct CommandRouter: Sendable {
    private let registry: PluginRegistry
    private let permissionEngine: PermissionEngine
    private let prompter: any PermissionPrompting
    private let services: PluginServices
    private let eventBus: EventBus

    public init(
        registry: PluginRegistry,
        permissionEngine: PermissionEngine,
        prompter: any PermissionPrompting,
        services: PluginServices,
        eventBus: EventBus
    ) {
        self.registry = registry
        self.permissionEngine = permissionEngine
        self.prompter = prompter
        self.services = services
        self.eventBus = eventBus
    }

    public func route(_ command: KaiCommand) async throws -> CommandResult {
        // 1. Stop words halt everything immediately.
        if let stop = StopCommand(utterance: command.text) {
            await services.stopController.requestStop(stop)
            await eventBus.publish(KaiEvent(kind: .stopRequested(stop)))
            return CommandResult(message: "Halted (\(stop.rawValue)).", didSucceed: true)
        }

        // 2. Respect a stop that is already pending.
        try await services.stopController.checkpoint()

        // 3. Resolve a handler.
        guard let plugin = await registry.handler(for: command) else {
            throw KaiError.noHandler(command: command.text)
        }

        // 4. Permission gate.
        let declared = plugin.capability(for: command)?.defaultPermissionLevel ?? .green
        let level = permissionEngine.effectiveLevel(forAction: command.text, declared: declared)
        if PermissionDecision(level: level) != .allowed {
            await eventBus.publish(KaiEvent(kind: .permissionRequested(action: command.text, level: level)))
        }
        let granted = await permissionEngine.authorize(
            action: command.text,
            declared: declared,
            using: prompter
        )
        if PermissionDecision(level: level) != .allowed {
            await eventBus.publish(KaiEvent(kind: .permissionResolved(action: command.text, granted: granted)))
        }
        guard granted else {
            throw KaiError.permissionDenied(action: command.text, level: level)
        }

        // 5. Execute.
        return try await plugin.handle(command, services: services)
    }
}
