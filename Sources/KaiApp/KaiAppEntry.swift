#if os(macOS)
import SwiftUI
import KaiCore

/// The SwiftUI application entry point. Launched on macOS by `kai-app`'s
/// `KaiAppEntry.main()`.
public struct KaiAppEntry: App {
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
        var id: String { rawValue }

        var icon: String {
            switch self {
            case .chat: return "bubble.left.and.bubble.right"
            case .plugins: return "puzzlepiece.extension"
            case .activity: return "list.bullet.rectangle"
            case .permissions: return "lock.shield"
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
            }
        }
        .sheet(item: $model.pendingApproval) { approval in
            ApprovalSheet(approval: approval).environmentObject(model)
        }
        .onAppear { model.refreshPermissions() }
    }
}
#endif
