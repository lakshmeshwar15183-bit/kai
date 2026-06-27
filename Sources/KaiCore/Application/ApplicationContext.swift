import Foundation

/// A snapshot of the frontmost application Kai should operate within. Captured
/// from the OS on macOS; supplied explicitly in tests and the CLI.
public struct ApplicationContext: Sendable, Equatable, Codable {
    /// The application's bundle identifier, e.g. "com.apple.Safari".
    public let bundleIdentifier: String
    /// Human-readable name, e.g. "Safari".
    public let localizedName: String
    /// The focused window's title, when available.
    public let windowTitle: String?

    public init(bundleIdentifier: String, localizedName: String, windowTitle: String? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.localizedName = localizedName
        self.windowTitle = windowTitle
    }
}

/// Bundle identifiers for the applications Kai understands out of the box.
/// Plugins reference these to declare which apps they support.
public enum KnownApplication {
    public static let safari = "com.apple.Safari"
    public static let chrome = "com.google.Chrome"
    public static let edge = "com.microsoft.edgemac"
    public static let finder = "com.apple.finder"
    public static let terminal = "com.apple.Terminal"
    public static let vscode = "com.microsoft.VSCode"
    public static let xcode = "com.apple.dt.Xcode"
    public static let excel = "com.microsoft.Excel"
    public static let word = "com.microsoft.Word"
    public static let powerpoint = "com.microsoft.Powerpoint"
    public static let preview = "com.apple.Preview"
    public static let notes = "com.apple.Notes"
    public static let calendar = "com.apple.iCal"
    public static let mail = "com.apple.mail"
    public static let messages = "com.apple.MobileSMS"

    /// The browsers Kai can drive.
    public static let browsers: Set<String> = [safari, chrome, edge]
}

/// Supplies the currently active application. The macOS implementation uses
/// `NSWorkspace`; tests/CLI use a stub.
public protocol ActiveApplicationProvider: Sendable {
    func current() async -> ApplicationContext?
}

/// A fixed, scriptable provider for tests and the CLI demo.
public actor StubActiveApplicationProvider: ActiveApplicationProvider {
    private var context: ApplicationContext?

    public init(context: ApplicationContext? = nil) {
        self.context = context
    }

    public func set(_ context: ApplicationContext?) {
        self.context = context
    }

    public func current() async -> ApplicationContext? {
        context
    }
}
