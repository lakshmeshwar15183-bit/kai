#if os(macOS)
import SwiftUI
import AppKit
import KaiCore

/// Ensures the SwiftPM-built binary behaves as a regular, foreground GUI app
/// (shows in the Dock, brings its window forward on launch). This matters when
/// the app is launched as a bundle that was assembled outside Xcode.
@MainActor
final class KaiAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

/// The SwiftUI application entry point. Launched on macOS by `kai-app`'s
/// `KaiAppEntry.main()`.
public struct KaiAppEntry: App {
    @NSApplicationDelegateAdaptor(KaiAppDelegate.self) private var delegate
    @StateObject private var model = AppModel()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 820, minHeight: 560)
        }
        .windowStyle(.titleBar)

        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(minWidth: 520, minHeight: 440)
        }
    }
}

/// Root layout: a sidebar of sections, a detail pane, an always-visible status
/// pill, and an approval sheet for guarded actions.
struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var section: Section = .chat

    enum Section: String, CaseIterable, Identifiable {
        case chat = "Chat"
        case plugins = "Plugins"
        case activity = "Activity"
        case permissions = "Permissions"
        case settings = "Settings"
        var id: String { rawValue }

        var icon: String {
            switch self {
            case .chat: return "bubble.left.and.bubble.right"
            case .plugins: return "puzzlepiece.extension"
            case .activity: return "list.bullet.rectangle"
            case .permissions: return "lock.shield"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $section) { item in
                Label(item.rawValue, systemImage: item.icon).tag(item)
            }
            .navigationSplitViewColumnWidth(200)
            .safeAreaInset(edge: .bottom) {
                StatusIndicatorView(state: model.state, mode: model.mode, isListening: model.isListening)
                    .padding()
            }
        } detail: {
            switch section {
            case .chat: ChatView()
            case .plugins: PluginManagerView()
            case .activity: ActivityLogView()
            case .permissions: PermissionManagerView()
            case .settings: SettingsView()
            }
        }
        .sheet(item: $model.pendingApproval) { approval in
            ApprovalSheet(approval: approval).environmentObject(model)
        }
        .onAppear { model.refreshPermissions() }
    }
}
#endif
