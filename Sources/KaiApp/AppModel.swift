#if os(macOS)
import Foundation
import SwiftUI
import KaiCore
import KaiAI
import KaiMemory
import KaiPlugins

/// The bridge between the actor-based core and SwiftUI. It owns the composed
/// core services, subscribes to the ``EventBus``, and republishes state on the
/// main actor so views update reactively.
@MainActor
public final class AppModel: ObservableObject {
    @Published public private(set) var state: ActivationState = .sleeping
    @Published public private(set) var logLines: [String] = []
    @Published public private(set) var manifests: [PluginManifest] = []
    @Published public var pendingApproval: PendingApproval?
    @Published public var transcript: [TranscriptEntry] = []

    public struct TranscriptEntry: Identifiable {
        public let id = UUID()
        public let isUser: Bool
        public let text: String
    }

    public struct PendingApproval: Identifiable {
        public let id = UUID()
        public let action: String
        public let level: PermissionLevel
        public let respond: @Sendable (Bool) -> Void
    }

    private let eventBus = EventBus()
    private let stopController = StopController()
    private let logger: KaiLogger
    private let stateMachine: ActivationStateMachine
    private let registry = PluginRegistry()
    private let permissionEngine = PermissionEngine()
    private var router: CommandRouter?

    public init() {
        self.logger = KaiLogger(minimumLevel: .info)
        self.stateMachine = ActivationStateMachine(eventBus: eventBus, stopController: stopController)
        Task { await bootstrap() }
    }

    private func bootstrap() async {
        await registry.register(ConversationPlugin())
        manifests = await registry.manifests()

        let services = PluginServices(
            ai: EchoAIProvider(),
            memory: InMemoryStore(),
            logger: logger,
            stopController: stopController,
            eventBus: eventBus
        )
        router = CommandRouter(
            registry: registry,
            permissionEngine: permissionEngine,
            prompter: UIPrompter(model: self),
            services: services,
            eventBus: eventBus
        )

        let stream = await eventBus.subscribe()
        Task { @MainActor in
            for await event in stream {
                self.apply(event)
            }
        }
    }

    private func apply(_ event: KaiEvent) {
        switch event.kind {
        case let .stateChanged(_, to):
            state = to
        case let .log(level, message):
            logLines.append("[\(level.label)] \(message)")
        default:
            break
        }
    }

    // MARK: - Intents from the UI

    public func wake(trigger: ActivationTrigger) {
        Task {
            try? await stateMachine.activate(trigger: trigger)
            try? await stateMachine.transition(to: .thinking)
        }
    }

    public func send(_ text: String) {
        transcript.append(.init(isUser: true, text: text))
        Task {
            guard let router else { return }
            do {
                let result = try await router.route(KaiCommand(text: text))
                await MainActor.run { self.transcript.append(.init(isUser: false, text: result.message)) }
            } catch {
                await MainActor.run { self.transcript.append(.init(isUser: false, text: "⚠️ \(error)")) }
            }
        }
    }

    public func stop() {
        Task { await stateMachine.stop() }
    }

    func resolveApproval(_ approval: PendingApproval, granted: Bool) {
        approval.respond(granted)
        pendingApproval = nil
    }
}

/// Prompter that surfaces Yellow/Red decisions as a SwiftUI sheet.
private struct UIPrompter: PermissionPrompting {
    weak var model: AppModel?

    func requestDecision(action: String, level: PermissionLevel) async -> Bool {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                guard let model else { return continuation.resume(returning: false) }
                model.pendingApproval = AppModel.PendingApproval(
                    action: action,
                    level: level,
                    respond: { continuation.resume(returning: $0) }
                )
            }
        }
    }
}
#endif
