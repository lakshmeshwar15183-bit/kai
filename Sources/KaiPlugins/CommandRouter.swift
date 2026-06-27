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
    private let modeController: ModeController?
    private let activeApplicationProvider: (any ActiveApplicationProvider)?

    public init(
        registry: PluginRegistry,
        permissionEngine: PermissionEngine,
        prompter: any PermissionPrompting,
        services: PluginServices,
        eventBus: EventBus,
        modeController: ModeController? = nil,
        activeApplicationProvider: (any ActiveApplicationProvider)? = nil
    ) {
        self.registry = registry
        self.permissionEngine = permissionEngine
        self.prompter = prompter
        self.services = services
        self.eventBus = eventBus
        self.modeController = modeController
        self.activeApplicationProvider = activeApplicationProvider
    }

    public func route(_ command: KaiCommand) async throws -> CommandResult {
        // 1. Stop words halt everything immediately.
        if let stop = StopCommand(utterance: command.text) {
            await services.stopController.requestStop(stop)
            await eventBus.publish(KaiEvent(kind: .stopRequested(stop)))
            return CommandResult(message: "Halted (\(stop.rawValue)).", didSucceed: true)
        }

        // 2. Mode-switch words ("Observe" / "Execute") toggle interaction mode.
        if let mode = InteractionMode(modeUtterance: command.text), let modeController {
            await modeController.setMode(mode)
            return CommandResult(message: "\(mode.displayName) mode.", didSucceed: true)
        }

        // 3. Respect a stop that is already pending.
        try await services.stopController.checkpoint()

        // 4. Resolve the active application (Active Window Intelligence).
        let appContext = await resolveActiveApplication(command)

        // 5. Resolve a handler, preferring one that specialises in the active app.
        guard let plugin = await registry.handler(for: command, in: appContext) else {
            throw KaiError.noHandler(command: command.text)
        }

        // 6. Observe mode is read-only: block any side-effecting capability.
        let capability = plugin.capability(for: command)
        if let modeController, await modeController.isObserving, capability?.sideEffect ?? true {
            throw KaiError.blockedInObserveMode(action: command.text)
        }

        // 7. Permission gate.
        let declared = capability?.defaultPermissionLevel ?? .green
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

        // 8. Execute.
        return try await plugin.handle(command, services: services)
    }

    private func resolveActiveApplication(_ command: KaiCommand) async -> ApplicationContext? {
        if let provider = activeApplicationProvider {
            return await provider.current()
        }
        if let bundle = command.activeApplication {
            return ApplicationContext(bundleIdentifier: bundle, localizedName: bundle)
        }
        return nil
    }
}
