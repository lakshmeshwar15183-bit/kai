#if os(macOS)
import SwiftUI
import KaiCore
import KaiPlugins

/// The always-visible status pill (Sleeping/Listening/Thinking/Working/…).
struct StatusIndicatorView: View {
    let state: ActivationState

    private var color: Color {
        switch state {
        case .sleeping: return .gray
        case .listening: return .blue
        case .thinking: return .purple
        case .working: return .orange
        case .waitingForApproval: return .yellow
        case .completed: return .green
        case .stopped: return .red
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(state.displayName).font(.callout).bold()
            Spacer()
        }
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Chat / voice command surface.
struct ChatView: View {
    @EnvironmentObject private var model: AppModel
    @State private var input = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(model.transcript) { entry in
                        HStack {
                            if entry.isUser { Spacer() }
                            Text(entry.text)
                                .padding(10)
                                .background(entry.isUser ? Color.blue.opacity(0.2) : Color.gray.opacity(0.15),
                                            in: RoundedRectangle(cornerRadius: 10))
                            if !entry.isUser { Spacer() }
                        }
                    }
                }
                .padding()
            }
            Divider()
            HStack {
                TextField("Ask Kai…", text: $input, onCommit: submit)
                    .textFieldStyle(.roundedBorder)
                Button("Send", action: submit).keyboardShortcut(.return)
                Button(role: .destructive) { model.stop() } label: { Text("Stop") }
            }
            .padding()
        }
        .onAppear { model.wake(trigger: .typedCommand) }
    }

    private func submit() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        model.send(text)
        input = ""
    }
}

/// Plugin manager listing installed capabilities and their permission levels.
struct PluginManagerView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List(model.manifests) { manifest in
            Section(manifest.name) {
                Text(manifest.summary).font(.callout).foregroundStyle(.secondary)
                ForEach(manifest.capabilities) { capability in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(capability.name)
                            Text(capability.summary).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(capability.defaultPermissionLevel.displayName)
                            .font(.caption).padding(4)
                            .background(.quaternary, in: Capsule())
                    }
                }
            }
        }
        .navigationTitle("Plugins")
    }
}

/// Live activity log fed by the event bus.
struct ActivityLogView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List(Array(model.logLines.enumerated()), id: \.offset) { _, line in
            Text(line).font(.system(.caption, design: .monospaced))
        }
        .navigationTitle("Activity")
    }
}

/// Settings: provider selection, permissions, shortcuts (scaffold).
struct SettingsView: View {
    var body: some View {
        TabView {
            Form {
                Text("AI provider selection lives here (config-driven).")
            }
            .tabItem { Label("AI", systemImage: "brain") }

            Form {
                Text("Permission defaults and wake settings live here.")
            }
            .tabItem { Label("Privacy", systemImage: "lock") }
        }
        .frame(width: 420, height: 240)
        .padding()
    }
}

/// Confirmation/approval sheet for Yellow/Red actions.
struct ApprovalSheet: View {
    @EnvironmentObject private var model: AppModel
    let approval: AppModel.PendingApproval

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(approval.level == .red ? "Approval required" : "Confirm action")
                .font(.title2).bold()
            Text(approval.action).foregroundStyle(.secondary)
            Text("Permission level: \(approval.level.displayName)")
                .font(.caption)
            HStack {
                Spacer()
                Button("Deny", role: .cancel) { model.resolveApproval(approval, granted: false) }
                Button(approval.level == .red ? "Approve" : "Confirm") {
                    model.resolveApproval(approval, granted: true)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}
#endif
