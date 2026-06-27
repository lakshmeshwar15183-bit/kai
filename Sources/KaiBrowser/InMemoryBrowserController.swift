import Foundation

/// A fully in-memory ``BrowserController`` used by tests and the CLI demo.
///
/// It simulates pages, navigation history, clicking links, filling fields, and
/// — importantly — authentication: a login page can be scheduled to "resolve"
/// after a number of snapshots, mimicking the user signing in while Kai waits.
/// It never stores credentials and refuses to fill secure fields, exactly like
/// the real drivers.
public actor InMemoryBrowserController: BrowserController {
    public let kind: BrowserKind

    private var pages: [String: PageSnapshot]
    private var current: PageSnapshot?
    private var backStack: [PageSnapshot] = []
    private var forwardStack: [PageSnapshot] = []
    private var loginAutoResolve: (remaining: Int, target: PageSnapshot)?

    /// Observable side effects, for test assertions.
    public private(set) var clicks: [String] = []
    public private(set) var lastScroll: ScrollDirection?

    public init(kind: BrowserKind = .safari, pages: [PageSnapshot] = []) {
        self.kind = kind
        self.pages = Dictionary(pages.map { ($0.url.absoluteString, $0) }, uniquingKeysWith: { _, new in new })
    }

    /// Adds or replaces a scripted page.
    public func register(_ page: PageSnapshot) {
        pages[page.url.absoluteString] = page
    }

    /// Simulates the user authenticating: after `snapshots` further snapshots of
    /// a login page, the controller swaps in `page`.
    public func scheduleLoginResolution(after snapshots: Int, to page: PageSnapshot) {
        loginAutoResolve = (max(1, snapshots), page)
    }

    // MARK: - BrowserController

    public func open(_ url: URL) async throws {
        if let cur = current { backStack.append(cur) }
        forwardStack.removeAll()
        current = pages[url.absoluteString]
            ?? PageSnapshot(url: url, title: url.host ?? url.absoluteString, text: "")
    }

    public func navigate(_ action: NavigationAction) async throws {
        switch action {
        case .back:
            guard let prev = backStack.popLast() else {
                throw BrowserError.navigationFailed(reason: "no back history")
            }
            if let cur = current { forwardStack.append(cur) }
            current = prev
        case .forward:
            guard let next = forwardStack.popLast() else {
                throw BrowserError.navigationFailed(reason: "no forward history")
            }
            if let cur = current { backStack.append(cur) }
            current = next
        case .reload:
            guard current != nil else { throw BrowserError.noActivePage }
        }
    }

    public func snapshot() async throws -> PageSnapshot {
        guard var cur = current else { throw BrowserError.noActivePage }
        if var resolve = loginAutoResolve, cur.hasSecureField {
            resolve.remaining -= 1
            if resolve.remaining <= 0 {
                current = resolve.target
                loginAutoResolve = nil
                cur = resolve.target
            } else {
                loginAutoResolve = resolve
            }
        }
        return cur
    }

    public func click(label: String) async throws {
        guard let cur = current else { throw BrowserError.noActivePage }
        guard let element = cur.elements.first(where: {
            $0.label.caseInsensitiveCompare(label) == .orderedSame
        }) else {
            throw BrowserError.elementNotFound(label: label)
        }
        clicks.append(label)
        // Clicking a link that carries a destination navigates to it.
        if element.role == .link, let value = element.value, let url = URL(string: value) {
            try await open(url)
        }
    }

    public func scroll(_ direction: ScrollDirection) async throws {
        guard current != nil else { throw BrowserError.noActivePage }
        lastScroll = direction
    }

    public func fill(field label: String, value: String) async throws {
        guard var cur = current else { throw BrowserError.noActivePage }
        guard let index = cur.elements.firstIndex(where: {
            $0.label.caseInsensitiveCompare(label) == .orderedSame
        }) else {
            throw BrowserError.elementNotFound(label: label)
        }
        // Never type into a password/secure field.
        if cur.elements[index].role == .secureField {
            throw BrowserError.refusedSecureField
        }
        cur.elements[index].value = value
        current = cur
    }

    public func extractText() async throws -> String {
        guard let cur = current else { throw BrowserError.noActivePage }
        return cur.text
    }
}
