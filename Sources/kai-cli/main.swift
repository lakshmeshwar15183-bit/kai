import Foundation
import KaiCore
import KaiAI
import KaiMemory
import KaiAutomation
import KaiPlugins
import KaiBrowser

// A non-interactive demonstration that wires the platform-agnostic core
// together and exercises it on any platform (including Linux/CI). It is NOT the
// macOS app — it exists to prove the architecture end to end and to serve as
// living documentation of how the pieces compose.

/// A prompter for the demo: approves Yellow (reversible) actions and denies Red
/// (high-risk) ones, illustrating the permission gate without a human present.
struct DemoPrompter: PermissionPrompting {
    func requestDecision(action: String, level: PermissionLevel) async -> Bool {
        level <= .yellow
    }
}

func printEvent(_ event: KaiEvent) {
    switch event.kind {
    case let .stateChanged(from, to):
        print("  · state: \(from.displayName) -> \(to.displayName)")
    case let .activated(trigger):
        print("  · activated via \(trigger.rawValue)")
    case let .modeChanged(mode):
        print("  · mode -> \(mode.displayName)")
    case let .stopRequested(command):
        print("  · STOP requested (\(command.rawValue))")
    case let .permissionRequested(action, level):
        print("  · permission requested [\(level.displayName)]: \(action)")
    case let .permissionResolved(action, granted):
        print("  · permission \(granted ? "GRANTED" : "DENIED"): \(action)")
    case let .workflow(workflowEvent):
        print("  · workflow: \(workflowEvent)")
    case let .log(level, message):
        print("  · log [\(level.label)]: \(message)")
    }
}

// MARK: - Compose the core

let eventBus = EventBus()
let stopController = StopController()
let logger = KaiLogger(minimumLevel: .info)
let stateMachine = ActivationStateMachine(eventBus: eventBus, stopController: stopController)
let permissionEngine = PermissionEngine()
let modeController = ModeController(mode: .execute, eventBus: eventBus)
let appProvider = StubActiveApplicationProvider()

// A scripted browser: a webmail login page that "resolves" after the user
// signs in, leading to an inbox with a Compose button.
let loginPage = PageSnapshot(
    url: URL(string: "https://mail.example.com/login")!,
    title: "Sign in to ExampleMail",
    text: "Please sign in to continue.",
    elements: [PageElement(id: "pw", role: .secureField, label: "Password")]
)
let inboxPage = PageSnapshot(
    url: URL(string: "https://mail.example.com/inbox")!,
    title: "ExampleMail — Inbox",
    text: "You have 3 unread messages about your study schedule.",
    elements: [PageElement(id: "compose", role: .button, label: "Compose")]
)
let browser = InMemoryBrowserController(kind: .safari, pages: [loginPage, inboxPage])

let registry = PluginRegistry()
// Specific skills first, conversation last (it is the catch-all fallback).
await registry.register(BrowserPlugin(controller: browser, pollInterval: .milliseconds(20)))
await registry.register(ConversationPlugin())

let services = PluginServices(
    ai: EchoAIProvider(),
    memory: InMemoryStore(),
    logger: logger,
    stopController: stopController,
    eventBus: eventBus
)

let router = CommandRouter(
    registry: registry,
    permissionEngine: permissionEngine,
    prompter: DemoPrompter(),
    services: services,
    eventBus: eventBus,
    modeController: modeController,
    activeApplicationProvider: appProvider
)

// Stream events to the console.
let eventStream = await eventBus.subscribe()
let printer = Task {
    for await event in eventStream {
        printEvent(event)
    }
}

func run(_ text: String) async {
    print("\n> \(text)")
    do {
        let result = try await router.route(KaiCommand(text: text))
        print("  = \(result.message)")
    } catch {
        print("  ! \(error)")
    }
}

// MARK: - Drive the scenario

print("Kai core demo\n=============")

print("\n[1] Wake up (typed command):")
try await stateMachine.activate(trigger: .typedCommand)
try await stateMachine.transition(to: .thinking)

await run("What is the capital of France?")   // Green: runs
await run("Delete the old screenshots")        // Yellow: prompter approves
await run("Transfer money to my bank account") // Red: prompter denies

print("\n[2] Run an interruptible workflow:")
let engine = WorkflowEngine(eventBus: eventBus)
let context = WorkflowContext(stopController: stopController, logger: logger)
await stopController.reset()
let workflow = Workflow(name: "demo", steps: [
    ClosureStep(name: "prepare") { await $0.set("status", "prepared") },
    ClosureStep(name: "process") { await $0.set("status", "processed") },
    ClosureStep(name: "finish") { _ in }
])
let outcome = await engine.run(workflow, context: context)
print("  workflow outcome: \(outcome)")

print("\n[3] Browser automation (Safari is frontmost):")
await appProvider.set(ApplicationContext(
    bundleIdentifier: KnownApplication.safari,
    localizedName: "Safari",
    windowTitle: "ExampleMail"
))
await browser.scheduleLoginResolution(after: 2, to: inboxPage)
await run("open https://mail.example.com/login") // detects login, pauses
await run("continue after login")                 // waits for auth, resumes
await run("summarize this page")                   // read-only, uses AI

print("\n[4] Observe mode (read-only):")
await run("observe")
await run("read the page")    // read-only: allowed
await run("click Compose")    // side effect: blocked in Observe
await run("execute")
await run("click Compose")    // now allowed (Yellow, prompter approves)

print("\n[5] Say a stop word:")
await run("stop")

print("\n[6] Return to sleep:")
await stateMachine.stop()
try? await stateMachine.sleep()
let finalState = await stateMachine.state
print("  final state: \(finalState.displayName)")

// Allow the event printer to flush, then exit.
try? await Task.sleep(nanoseconds: 50_000_000)
printer.cancel()
print("\nDone.")
