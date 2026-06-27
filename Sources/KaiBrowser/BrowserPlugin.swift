import Foundation
import KaiCore
import KaiAI
import KaiPlugins

/// Production browser-automation skill, delivered as a ``Plugin``.
///
/// It drives any ``BrowserController`` (Safari/Chrome/Edge on macOS, the
/// in-memory fake in tests). Key safety properties:
///  - Read-only capabilities (read/summarize) carry `sideEffect == false`, so
///    they remain available in Observe mode; everything else is blocked there.
///  - Click/fill are Yellow (confirmation required); the permission engine
///    escalates anything mentioning passwords/OTP to Red automatically.
///  - On a detected login page Kai pauses and asks the user to authenticate; it
///    never types credentials and never bypasses authentication.
public struct BrowserPlugin: Plugin {
    private let controller: any BrowserController
    private let detector = LoginDetector()
    private let parser = BrowserCommandParser()
    private let pollInterval: Duration
    private let maxLoginAttempts: Int

    public init(
        controller: any BrowserController,
        pollInterval: Duration = .milliseconds(250),
        maxLoginAttempts: Int = 240
    ) {
        self.controller = controller
        self.pollInterval = pollInterval
        self.maxLoginAttempts = maxLoginAttempts
    }

    // MARK: - Capabilities

    private enum Caps {
        static let open = Capability(id: "browser.open", name: "Open URL",
            summary: "Open a website.", defaultPermissionLevel: .green, sideEffect: true)
        static let navigate = Capability(id: "browser.navigate", name: "Navigate",
            summary: "Back, forward, reload.", defaultPermissionLevel: .green, sideEffect: true)
        static let scroll = Capability(id: "browser.scroll", name: "Scroll",
            summary: "Scroll the page.", defaultPermissionLevel: .green, sideEffect: true)
        static let click = Capability(id: "browser.click", name: "Click",
            summary: "Click a button or link.", defaultPermissionLevel: .yellow, sideEffect: true)
        static let fill = Capability(id: "browser.fill", name: "Fill field",
            summary: "Type into a non-secure form field.", defaultPermissionLevel: .yellow, sideEffect: true)
        static let read = Capability(id: "browser.read", name: "Read page",
            summary: "Extract the page's text.", defaultPermissionLevel: .green, sideEffect: false)
        static let summarize = Capability(id: "browser.summarize", name: "Summarize page",
            summary: "AI summary of the page.", defaultPermissionLevel: .green, sideEffect: false)
        static let waitLogin = Capability(id: "browser.waitLogin", name: "Wait for login",
            summary: "Pause for the user to authenticate.", defaultPermissionLevel: .green, sideEffect: true)
    }

    public let manifest = PluginManifest(
        id: "skill.browser",
        name: "Browser",
        version: "1.0.0",
        author: "Kai",
        summary: "Open, navigate, read, and operate web pages in Safari, Chrome, or Edge.",
        capabilities: [
            Caps.open, Caps.navigate, Caps.scroll, Caps.click,
            Caps.fill, Caps.read, Caps.summarize, Caps.waitLogin
        ]
    )

    public var supportedApplications: Set<String>? { KnownApplication.browsers }

    public func canHandle(_ command: KaiCommand) -> Bool {
        parser.parse(command.text) != nil
    }

    public func capability(for command: KaiCommand) -> Capability? {
        guard let intent = parser.parse(command.text) else { return manifest.capabilities.first }
        switch intent {
        case .open: return Caps.open
        case .navigate: return Caps.navigate
        case .scroll: return Caps.scroll
        case .click: return Caps.click
        case .fill: return Caps.fill
        case .readPage: return Caps.read
        case .summarize: return Caps.summarize
        case .waitForLogin: return Caps.waitLogin
        }
    }

    // MARK: - Execution

    public func handle(_ command: KaiCommand, services: PluginServices) async throws -> CommandResult {
        try await services.stopController.checkpoint()
        guard let intent = parser.parse(command.text) else {
            throw KaiError.noHandler(command: command.text)
        }

        switch intent {
        case let .open(url):
            try await controller.open(url)
            let snap = try await controller.snapshot()
            if detector.isLoginPage(snap) {
                await services.logger.notice("Login page detected at \(url.host ?? url.absoluteString); pausing for the user.")
                return CommandResult(
                    message: "Opened \(snap.title). This looks like a sign-in page — please log in yourself, then say \"continue after login\". Kai will not enter credentials.",
                    didSucceed: true,
                    metadata: ["url": snap.url.absoluteString, "authRequired": "true"]
                )
            }
            return CommandResult(message: "Opened \(snap.title).", metadata: ["url": snap.url.absoluteString])

        case let .navigate(action):
            try await controller.navigate(action)
            let snap = try await controller.snapshot()
            return CommandResult(message: "\(action.rawValue.capitalized) → \(snap.title).", metadata: ["url": snap.url.absoluteString])

        case let .scroll(direction):
            try await controller.scroll(direction)
            return CommandResult(message: "Scrolled \(direction.rawValue).")

        case let .click(label):
            try await controller.click(label: label)
            let snap = try await controller.snapshot()
            return CommandResult(message: "Clicked \"\(label)\". Now on \(snap.title).", metadata: ["url": snap.url.absoluteString])

        case let .fill(field, value):
            try await controller.fill(field: field, value: value)
            return CommandResult(message: "Filled \"\(field)\".")

        case .readPage:
            let text = try await controller.extractText()
            return CommandResult(message: text, metadata: ["length": String(text.count)])

        case .summarize:
            let text = try await controller.extractText()
            let response = try await services.ai.complete(AIRequest(messages: [
                .system("Summarize the following web page concisely for the user."),
                .user(text)
            ]))
            return CommandResult(message: response.content, metadata: ["tokens": String(response.usage.totalTokens)])

        case .waitForLogin:
            return try await waitForAuthentication(services: services)
        }
    }

    /// Polls the current page until it is no longer a login page, honouring the
    /// stop controller so the user can cancel the wait at any time.
    private func waitForAuthentication(services: PluginServices) async throws -> CommandResult {
        for _ in 0..<maxLoginAttempts {
            try await services.stopController.checkpoint()
            let snap = try await controller.snapshot()
            if !detector.isLoginPage(snap) {
                await services.logger.info("Authentication detected; resuming.")
                return CommandResult(
                    message: "Authenticated. Continuing on \(snap.title).",
                    metadata: ["url": snap.url.absoluteString]
                )
            }
            if pollInterval > .zero {
                try await Task.sleep(for: pollInterval)
            }
        }
        throw BrowserError.authenticationTimedOut
    }
}
