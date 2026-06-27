import XCTest
@testable import KaiPlugins
import KaiCore
import KaiAI
import KaiMemory

/// A minimal plugin used to exercise routing/mode/permission behaviour.
private struct FakePlugin: Plugin {
    let manifest: PluginManifest
    let apps: Set<String>?
    let handles: @Sendable (String) -> Bool

    init(id: String, sideEffect: Bool, level: PermissionLevel = .green, apps: Set<String>? = nil,
         handles: @escaping @Sendable (String) -> Bool) {
        self.manifest = PluginManifest(
            id: id, name: id, version: "1.0.0", author: "test", summary: "",
            capabilities: [Capability(id: "\(id).cap", name: "cap", summary: "",
                                      defaultPermissionLevel: level, sideEffect: sideEffect)]
        )
        self.apps = apps
        self.handles = handles
    }

    var supportedApplications: Set<String>? { apps }
    func canHandle(_ command: KaiCommand) -> Bool { handles(command.text) }
    func handle(_ command: KaiCommand, services: PluginServices) async throws -> CommandResult {
        CommandResult(message: "handled by \(manifest.id)")
    }
}

private struct AllowAll: PermissionPrompting {
    func requestDecision(action: String, level: PermissionLevel) async -> Bool { true }
}

final class ObserveModeAndRoutingTests: XCTestCase {
    private func services(_ stop: StopController) -> PluginServices {
        PluginServices(ai: EchoAIProvider(), memory: InMemoryStore(),
                       logger: KaiLogger(minimumLevel: .error), stopController: stop, eventBus: EventBus())
    }

    func testObserveModeBlocksSideEffectingPlugin() async throws {
        let registry = PluginRegistry()
        await registry.register(FakePlugin(id: "actuator", sideEffect: true) { _ in true })
        let stop = StopController()
        let mode = ModeController(mode: .observe)
        let router = CommandRouter(
            registry: registry, permissionEngine: PermissionEngine(), prompter: AllowAll(),
            services: services(stop), eventBus: EventBus(), modeController: mode
        )

        do {
            _ = try await router.route(KaiCommand(text: "do an action"))
            XCTFail("expected observe-mode block")
        } catch let error as KaiError {
            if case .blockedInObserveMode = error { /* ok */ } else { XCTFail("wrong error: \(error)") }
        }
    }

    func testObserveModeAllowsReadOnlyPlugin() async throws {
        let registry = PluginRegistry()
        await registry.register(FakePlugin(id: "reader", sideEffect: false) { _ in true })
        let stop = StopController()
        let mode = ModeController(mode: .observe)
        let router = CommandRouter(
            registry: registry, permissionEngine: PermissionEngine(), prompter: AllowAll(),
            services: services(stop), eventBus: EventBus(), modeController: mode
        )
        let result = try await router.route(KaiCommand(text: "read something"))
        XCTAssertTrue(result.didSucceed)
    }

    func testModeSwitchWords() async throws {
        let registry = PluginRegistry()
        let stop = StopController()
        let mode = ModeController(mode: .execute)
        let router = CommandRouter(
            registry: registry, permissionEngine: PermissionEngine(), prompter: AllowAll(),
            services: services(stop), eventBus: EventBus(), modeController: mode
        )
        _ = try await router.route(KaiCommand(text: "observe"))
        let observing = await mode.isObserving
        XCTAssertTrue(observing)
        _ = try await router.route(KaiCommand(text: "execute"))
        let executing = await mode.isObserving
        XCTAssertFalse(executing)
    }

    func testActiveWindowPrefersAppSpecificPlugin() async {
        let registry = PluginRegistry()
        await registry.register(FakePlugin(id: "generic", sideEffect: false) { _ in true })
        await registry.register(FakePlugin(id: "safari", sideEffect: false, apps: [KnownApplication.safari]) { _ in true })

        let safariContext = ApplicationContext(bundleIdentifier: KnownApplication.safari, localizedName: "Safari")
        let chosen = await registry.handler(for: KaiCommand(text: "anything"), in: safariContext)
        XCTAssertEqual(chosen?.manifest.id, "safari")

        // With no app context, the first-registered (generic) wins.
        let fallback = await registry.handler(for: KaiCommand(text: "anything"), in: nil)
        XCTAssertEqual(fallback?.manifest.id, "generic")
    }
}
