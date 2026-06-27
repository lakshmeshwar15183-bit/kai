#if os(macOS)
import Foundation
import KaiCore
import KaiAI
import KaiAIProviders
import KaiMemory
import KaiAutomation
import KaiPlugins
import KaiBrowser
import KaiFinder
import KaiVision
import KaiVoice

/// An `AIProvider` whose backing provider can be swapped at runtime, so the
/// Settings screen can change vendor without rebuilding the command pipeline.
public final class SwitchableAIProvider: AIProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var backing: any AIProvider

    public init(_ initial: any AIProvider) { self.backing = initial }

    public func setProvider(_ provider: any AIProvider) {
        lock.lock(); backing = provider; lock.unlock()
    }

    public var id: String { lock.lock(); defer { lock.unlock() }; return backing.id }
    public var model: String { lock.lock(); defer { lock.unlock() }; return backing.model }

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        lock.lock(); let provider = backing; lock.unlock()
        return try await provider.complete(request)
    }
}

/// The composition root. Builds and wires every Kai subsystem for the macOS app:
/// core lifecycle, audit, AI providers, memory, all skill plugins, the router
/// (with Observe/Execute mode + Active Window Intelligence), and voice.
///
/// Out of the box it uses the offline echo provider so the app runs with zero
/// configuration; Settings can switch to OpenAI/Anthropic/Gemini/Ollama, whose
/// API keys are read from the Keychain.
@MainActor
public final class KaiAssembly {
    public let eventBus = EventBus()
    public let stopController = StopController()
    public let logger: KaiLogger
    public let audit: AuditTrail
    public let modeController: ModeController
    public let stateMachine: ActivationStateMachine
    public let registry = PluginRegistry()
    public let permissions = SystemPermissionService()
    public let providerRegistry = AIProviderRegistry()
    public let updateChecker: any UpdateChecking = NoopUpdateChecker()
    public let voice: VoiceSession
    public let recognizer: any SpeechRecognizer = AppleSpeechRecognizer()
    public let synthesizer: any SpeechSynthesizer = AppleSpeechSynthesizer()
    public let prompter = UIApprovalPrompter()

    private let switchableProvider: SwitchableAIProvider
    public private(set) var router: CommandRouter!

    public init() {
        self.logger = KaiLogger(minimumLevel: .info)
        self.audit = AuditTrail(fileURL: Self.appSupportFile("audit.jsonl"))
        self.modeController = ModeController(mode: .execute, eventBus: eventBus)
        self.stateMachine = ActivationStateMachine(eventBus: eventBus, stopController: stopController)
        self.switchableProvider = SwitchableAIProvider(EchoAIProvider())
        self.voice = VoiceSession(stopController: stopController)
    }

    /// Finishes asynchronous wiring (registering providers and plugins).
    public func bootstrap() async {
        await ProviderBootstrap.registerDefaults(
            into: providerRegistry,
            transport: URLSessionTransport(),
            resolver: KeychainSecretResolver()
        )

        let memory = JSONFileStore(url: Self.appSupportFile("memory.json"))
        let services = PluginServices(
            ai: switchableProvider,
            memory: memory,
            logger: logger,
            stopController: stopController,
            eventBus: eventBus
        )

        // Register skills (specific first, conversation last as the fallback).
        await registry.register(BrowserPlugin(controller: AppleScriptBrowserController(kind: .safari)))
        await registry.register(FinderPlugin(controller: LocalFileSystemController()))
        await registry.register(VisionPlugin(
            capturer: ScreenCaptureKitCapturer(),
            ocr: VisionOCREngine(),
            pdfReader: PDFKitTextReader()
        ))
        await registry.register(ConversationPlugin())

        router = CommandRouter(
            registry: registry,
            permissionEngine: PermissionEngine(),
            prompter: prompter,
            services: services,
            eventBus: eventBus,
            modeController: modeController,
            activeApplicationProvider: NSWorkspaceActiveApplicationProvider()
        )
    }

    /// Switches the active AI provider from a configuration (Settings action).
    public func selectProvider(_ config: AIProviderConfig) async throws {
        let provider = try await providerRegistry.makeProvider(config: config)
        switchableProvider.setProvider(provider)
        await audit.record(category: "settings", "AI provider switched to \(config.providerID)/\(config.model).")
    }

    /// Reverts to the offline echo provider.
    public func useOfflineProvider() {
        switchableProvider.setProvider(EchoAIProvider())
    }

    // MARK: - Paths

    private static func appSupportFile(_ name: String) -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Kai", isDirectory: true).appendingPathComponent(name)
    }
}
#endif
