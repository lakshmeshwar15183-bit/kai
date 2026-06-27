import Foundation

/// The browsers Kai can drive. The same ``BrowserController`` contract backs all
/// of them; only the concrete driver differs.
public enum BrowserKind: String, Sendable, Codable, CaseIterable, Equatable {
    case safari
    case chrome
    case edge

    /// The bundle identifier of the browser application.
    public var bundleIdentifier: String {
        switch self {
        case .safari: return "com.apple.Safari"
        case .chrome: return "com.google.Chrome"
        case .edge: return "com.microsoft.edgemac"
        }
    }
}

/// The semantic role of an element on a page, derived from the accessibility
/// tree / DOM. Kept deliberately small and stable; richer roles can be added
/// without breaking consumers.
public enum ElementRole: String, Sendable, Codable, Equatable {
    case button
    case link
    case textField
    case secureField   // password / sensitive input
    case checkbox
    case text
    case image
    case other
}

/// A single interactive or readable element on a page.
public struct PageElement: Sendable, Codable, Equatable, Identifiable {
    public var id: String
    public var role: ElementRole
    /// Visible label / accessible name / link text.
    public var label: String
    /// Current value for inputs (never a secret — secure fields report empty).
    public var value: String?

    public init(id: String, role: ElementRole, label: String, value: String? = nil) {
        self.id = id
        self.role = role
        self.label = label
        self.value = value
    }
}

/// An immutable snapshot of the current page. This is the unit ``BrowserController``
/// returns and the unit ``LoginDetector`` and the AI summarizer consume.
public struct PageSnapshot: Sendable, Codable, Equatable {
    public var url: URL
    public var title: String
    /// Extracted, human-readable text content of the page.
    public var text: String
    public var elements: [PageElement]

    public init(url: URL, title: String, text: String, elements: [PageElement] = []) {
        self.url = url
        self.title = title
        self.text = text
        self.elements = elements
    }

    /// Whether the page exposes a password/secure input.
    public var hasSecureField: Bool {
        elements.contains { $0.role == .secureField }
    }
}

/// Navigation actions that do not require a target element.
public enum NavigationAction: String, Sendable, Codable, Equatable {
    case back
    case forward
    case reload
}

/// The direction to scroll the viewport.
public enum ScrollDirection: String, Sendable, Codable, Equatable {
    case up
    case down
    case top
    case bottom
}
