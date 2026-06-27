import Foundation

/// KaiApp hosts the native macOS user interface (SwiftUI). All UI types are
/// compiled only on macOS via `#if os(macOS)` so that the rest of the package
/// continues to build and test on Linux/CI, where AppKit/SwiftUI are absent.
///
/// On a Mac, this target is embedded in an Xcode application (or built as an
/// executable) that calls `KaiAppEntry.main()`.
public enum KaiAppInfo {
    public static let displayName = "Kai"
    public static let tagline = "Personal AI Operating System for macOS"
    /// True only when built for macOS, where the UI is available.
    public static let userInterfaceAvailable: Bool = {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }()
}
