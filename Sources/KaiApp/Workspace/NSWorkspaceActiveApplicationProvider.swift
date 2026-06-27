#if os(macOS)
import Foundation
import AppKit
import KaiCore

/// macOS `ActiveApplicationProvider` backed by `NSWorkspace`. Reports the
/// frontmost application so the router can prefer app-specific plugins (Active
/// Window Intelligence).
public struct NSWorkspaceActiveApplicationProvider: ActiveApplicationProvider {
    public init() {}

    public func current() async -> ApplicationContext? {
        await MainActor.run {
            guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
            return ApplicationContext(
                bundleIdentifier: app.bundleIdentifier ?? "unknown",
                localizedName: app.localizedName ?? "Unknown",
                windowTitle: nil
            )
        }
    }
}
#endif
