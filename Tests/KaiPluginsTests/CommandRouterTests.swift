import XCTest
@testable import KaiPlugins
import KaiCore
import KaiAI
import KaiMemory

private struct ApprovingPrompter: PermissionPrompting {
    func requestDecision(action: String, level: PermissionLevel) async -> Bool { true }
}

final class CommandRouterTests: XCTestCase {
    private func makeRouter(prompter: any PermissionPrompting) async -> (CommandRouter, StopController) {
        let bus = EventBus()
        let stop = StopController()
        let registry = PluginRegistry()
        await registry.register(ConversationPlugin())
        let services = PluginServices(
            ai: EchoAIProvider(),
            memory: InMemoryStore(),
            logger: KaiLogger(minimumLevel: .error),
            stopController: stop,
            eventBus: bus
        )
        let router = CommandRouter(
            registry: registry,
            permissionEngine: PermissionEngine(),
            prompter: prompter,
            services: services,
            eventBus: bus
        )
        return (router, stop)
    }

    func testRoutesGreenCommandToConversationPlugin() async throws {
        let (router, _) = await makeRouter(prompter: DenyingPrompter())
        let result = try await router.route(KaiCommand(text: "hello Kai"))
        XCTAssertTrue(result.didSucceed)
        XCTAssertTrue(result.message.contains("hello Kai"))
    }

    func testStopWordHaltsImmediately() async throws {
        let (router, stop) = await makeRouter(prompter: DenyingPrompter())
        let result = try await router.route(KaiCommand(text: "stop"))
        XCTAssertTrue(result.didSucceed)
        let requested = await stop.isStopRequested
        XCTAssertTrue(requested)
    }

    func testRedActionDeniedWithoutApproval() async {
        let (router, _) = await makeRouter(prompter: DenyingPrompter())
        do {
            _ = try await router.route(KaiCommand(text: "open my banking password page"))
            XCTFail("expected permission denial")
        } catch let error as KaiError {
            if case .permissionDenied = error { /* ok */ } else {
                XCTFail("wrong error: \(error)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testYellowActionRunsWhenApproved() async throws {
        let (router, _) = await makeRouter(prompter: ApprovingPrompter())
        let result = try await router.route(KaiCommand(text: "delete the old notes"))
        XCTAssertTrue(result.didSucceed)
    }
}
