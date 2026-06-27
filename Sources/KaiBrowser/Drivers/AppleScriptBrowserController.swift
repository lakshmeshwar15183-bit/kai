#if os(macOS)
import Foundation

/// macOS ``BrowserController`` driven through AppleScript + injected JavaScript.
///
/// Safari requires "Allow JavaScript from Apple Events" (Develop menu) and
/// Automation permission; Chrome/Edge require "Allow JavaScript from Apple
/// Events" too. This driver performs page reads and DOM-level interactions via
/// JavaScript. It deliberately refuses to type into password inputs.
///
/// NOTE: This is the macOS surface of the browser skill. It is compiled only on
/// macOS; the platform-agnostic logic (intents, login detection, the plugin) is
/// shared and unit-tested on every platform.
public actor AppleScriptBrowserController: BrowserController {
    public let kind: BrowserKind

    public init(kind: BrowserKind) {
        self.kind = kind
    }

    // MARK: - BrowserController

    public func open(_ url: URL) async throws {
        switch kind {
        case .safari:
            try runAppleScript(#"tell application "Safari" to open location "\#(url.absoluteString)""#)
        case .chrome, .edge:
            try runAppleScript("""
            tell application "\(appName)"
                activate
                if (count of windows) = 0 then
                    make new window
                end if
                set URL of active tab of front window to "\(url.absoluteString)"
            end tell
            """)
        }
    }

    public func navigate(_ action: NavigationAction) async throws {
        switch action {
        case .back: _ = try evaluateJavaScript("history.back();")
        case .forward: _ = try evaluateJavaScript("history.forward();")
        case .reload: _ = try evaluateJavaScript("location.reload();")
        }
    }

    public func snapshot() async throws -> PageSnapshot {
        let json = try evaluateJavaScript(Self.snapshotScript)
        return try Self.decodeSnapshot(json)
    }

    public func click(label: String) async throws {
        let escaped = Self.escapeForJS(label)
        let script = """
        (function(){
          var nodes = Array.from(document.querySelectorAll('a,button,[role=button],input[type=submit]'));
          var el = nodes.find(n => (n.innerText||n.value||'').trim().toLowerCase() === '\(escaped)');
          if (!el) return 'notfound';
          el.click(); return 'ok';
        })();
        """
        let result = try evaluateJavaScript(script)
        if result.contains("notfound") { throw BrowserError.elementNotFound(label: label) }
    }

    public func scroll(_ direction: ScrollDirection) async throws {
        let js: String
        switch direction {
        case .up: js = "window.scrollBy(0, -600);"
        case .down: js = "window.scrollBy(0, 600);"
        case .top: js = "window.scrollTo(0, 0);"
        case .bottom: js = "window.scrollTo(0, document.body.scrollHeight);"
        }
        _ = try evaluateJavaScript(js)
    }

    public func fill(field label: String, value: String) async throws {
        let escapedLabel = Self.escapeForJS(label)
        // Locate the field and refuse if it is a password/secure input.
        let probe = """
        (function(){
          var inputs = Array.from(document.querySelectorAll('input,textarea'));
          var el = inputs.find(n => (n.name||n.placeholder||n.getAttribute('aria-label')||'').trim().toLowerCase() === '\(escapedLabel)');
          if (!el) return 'notfound';
          return el.type === 'password' ? 'secure' : 'ok';
        })();
        """
        let probeResult = try evaluateJavaScript(probe)
        if probeResult.contains("notfound") { throw BrowserError.elementNotFound(label: label) }
        if probeResult.contains("secure") { throw BrowserError.refusedSecureField }

        let escapedValue = Self.escapeForJS(value)
        let setter = """
        (function(){
          var inputs = Array.from(document.querySelectorAll('input,textarea'));
          var el = inputs.find(n => (n.name||n.placeholder||n.getAttribute('aria-label')||'').trim().toLowerCase() === '\(escapedLabel)');
          if (!el) return 'notfound';
          el.value = '\(escapedValue)';
          el.dispatchEvent(new Event('input', {bubbles:true}));
          return 'ok';
        })();
        """
        _ = try evaluateJavaScript(setter)
    }

    public func extractText() async throws -> String {
        try evaluateJavaScript("document.body.innerText;")
    }

    // MARK: - AppleScript / JavaScript bridge

    private var appName: String {
        switch kind {
        case .safari: return "Safari"
        case .chrome: return "Google Chrome"
        case .edge: return "Microsoft Edge"
        }
    }

    @discardableResult
    private func evaluateJavaScript(_ js: String) throws -> String {
        let escaped = Self.escapeForAppleScriptString(js)
        let script: String
        switch kind {
        case .safari:
            script = """
            tell application "Safari" to do JavaScript "\(escaped)" in front document
            """
        case .chrome, .edge:
            script = """
            tell application "\(appName)" to execute active tab of front window javascript "\(escaped)"
            """
        }
        return try runAppleScript(script)
    }

    @discardableResult
    private func runAppleScript(_ source: String) throws -> String {
        var error: NSDictionary?
        guard let apple = NSAppleScript(source: source) else {
            throw BrowserError.navigationFailed(reason: "could not compile AppleScript")
        }
        let descriptor = apple.executeAndReturnError(&error)
        if let error {
            throw BrowserError.navigationFailed(reason: String(describing: error))
        }
        return descriptor.stringValue ?? ""
    }

    // MARK: - JS payloads & decoding

    private static let snapshotScript = """
    JSON.stringify({
      url: location.href,
      title: document.title,
      text: (document.body ? document.body.innerText : '').slice(0, 20000),
      elements: Array.from(document.querySelectorAll('a,button,input,textarea')).slice(0,200).map(function(n, i){
        var role = 'other';
        var tag = n.tagName.toLowerCase();
        if (tag === 'a') role = 'link';
        else if (tag === 'button' || n.type === 'submit') role = 'button';
        else if (n.type === 'password') role = 'secureField';
        else if (tag === 'input' || tag === 'textarea') role = 'textField';
        return {
          id: String(i),
          role: role,
          label: (n.innerText||n.value||n.placeholder||n.getAttribute('aria-label')||'').trim().slice(0,200),
          value: n.type === 'password' ? null : (n.value || null)
        };
      })
    });
    """

    private struct RawSnapshot: Decodable {
        let url: String
        let title: String
        let text: String
        let elements: [RawElement]
    }
    private struct RawElement: Decodable {
        let id: String
        let role: String
        let label: String
        let value: String?
    }

    private static func decodeSnapshot(_ json: String) throws -> PageSnapshot {
        guard let data = json.data(using: .utf8),
              let raw = try? JSONDecoder().decode(RawSnapshot.self, from: data),
              let url = URL(string: raw.url) else {
            throw BrowserError.navigationFailed(reason: "could not decode page snapshot")
        }
        let elements = raw.elements.map { e in
            PageElement(
                id: e.id,
                role: ElementRole(rawValue: e.role) ?? .other,
                label: e.label,
                value: e.value
            )
        }
        return PageSnapshot(url: url, title: raw.title, text: raw.text, elements: elements)
    }

    private static func escapeForJS(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "'", with: "\\'")
         .lowercased()
    }

    private static func escapeForAppleScriptString(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "\n", with: " ")
    }
}
#endif
