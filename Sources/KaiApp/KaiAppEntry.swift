#if os(macOS)
import SwiftUI
import KaiCore

/// The SwiftUI application entry point. On a Mac this is launched from an Xcode
/// app target (or an executable wrapper) by calling `KaiAppEntry.main()`.
public struct KaiAppEntry: App {
    @StateObject private var model = AppModel()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 720, minHeight: 480)
        }
        .windowStyle(.titleBar)

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}

/// Root layout: a sidebar of sections plus a detail pane, with the status pill
/// always visible and an approval sheet for guarded actions.
struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var section: Section = .chat

    enum Section: String, CaseIterable, Identifiable {
        case chat = "Chat"
        case plugins = "Plugins"
        case activity = "Activity"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $section) { item in
                Text(item.rawValue).tag(item)
            }
            .navigationSplitViewColumnWidth(180)
            .safeAreaInset(edge: .bottom) {
                StatusIndicatorView(state: model.state)
                    .padding()
            }
        } detail: {
            switch section {
            case .chat: ChatView()
            case .plugins: PluginManagerView()
            case .activity: ActivityLogView()
            }
        }
        .sheet(item: $model.pendingApproval) { approval in
            ApprovalSheet(approval: approval)
                .environmentObject(model)
        }
    }
}
#endif
