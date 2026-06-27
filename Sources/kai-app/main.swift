// Launchable entry point for the Kai macOS application.
//
// On macOS this hands control to the SwiftUI `App` defined in `KaiApp`. On other
// platforms (CI/Linux, where AppKit/SwiftUI are unavailable) it prints guidance
// instead of failing to link, so the whole package still builds everywhere.

#if os(macOS)
import KaiApp

KaiAppEntry.main()
#else
import Foundation

print("""
Kai is a native macOS application and must be built on macOS.

  • Run in development:   swift run kai-app        (on a Mac, macOS 14+)
  • Package a .app/.dmg:  ./Scripts/build_app.sh && ./Scripts/make_dmg.sh

See docs/MACOS_STEPS.md for full instructions.
""")
#endif
