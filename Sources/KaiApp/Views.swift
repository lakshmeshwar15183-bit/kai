#if os(macOS)
import SwiftUI
import KaiCore
import KaiPlugins

/// Always-visible status pill: lifecycle state, interaction mode, and mic state.
struct StatusIndicatorView: View {
    let state: ActivationState
    let mode: InteractionMode
    let isListening: Bool

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
            Text(mode.displayName)
                .font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                .background(mode == .observe ? Color.yellow.opacity(0.25) : Color.green.opacity(0.2), in: Capsule())
            if isListening {
                Image(systemName: "mic.fill").foregroundStyle(.red)
            }
        }
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Chat / command surface with voice toggle and stop.
struct ChatView: View {
    @EnvironmentObject private var model: AppModel
    @State private var input = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(model.transcript) { entry in
                            HStack {
                                if entry.isUser { Spacer(minLength: 40) }
                                Text(entry.text)
                                    .textSelection(.enabled)
                                    .padding(10)
                                    .background(entry.isUser ? Color.blue.opacity(0.2) : Color.gray.opacity(0.15),
                                                in: RoundedRectangle(cornerRadius: 10))
                                if !entry.isUser { Spacer(minLength: 40) }
                            }.id(entry.id)
                        }
                    }.padding()
                }
                .onChange(of: model.transcript.count) {
                    if let last = model.transcript.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
            Divider()
            HStack(spacing: 8) {
                TextField("Ask Kai, or say \"observe\" / \"execute\"…", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(submit)
                Button(action: submit) { Image(systemName: "paperplane.fill") }
                    .keyboardShortcut(.return, modifiers: [])
                Button(action: model.toggleVoice) {
                    Image(systemName: model.isListening ? "mic.fill" : "mic")
                }.help("Toggle voice activation")
                Button(role: .destructive, action: model.stop) { Image(systemName: "stop.fill") }
                    .help("Stop everything")
            }.padding()
        }
    }

    private func submit() {
        model.send(input)
        input = ""
    }
}

/// Plugin manager listing installed skills and their capabilities/permissions.
struct PluginManagerView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        List(model.manifests) { manifest in
            Section("\(manifest.name)  v\(manifest.version)") {
                Text(manifest.summary).font(.callout).foregroundStyle(.secondary)
                ForEach(manifest.capabilities) { capability in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(capability.name)
                            Text(capability.summary).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !capability.sideEffect {
                            Text("read-only").font(.caption2).padding(4)
                                .background(.green.opacity(0.2), in: Capsule())
                        }
                        Text(capability.defaultPermissionLevel.displayName)
                            .font(.caption2).padding(4).background(.quaternary, in: Capsule())
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
        List(Array(model.activity.enumerated()), id: \.offset) { _, line in
            Text(line).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
        }
        .navigationTitle("Activity")
    }
}

/// Permission manager for macOS system permissions.
struct PermissionManagerView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            Section {
                ForEach(SystemPermission.allCases) { permission in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(permission.title).font(.headline)
                            Text(permission.rationale).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        statusBadge(model.permissions[permission] ?? .notDetermined)
                        Button("Request") { model.requestPermission(permission) }
                        Button("Settings…") { model.openPermissionSettings(permission) }
                    }.padding(.vertical, 4)
                }
            } footer: {
                Text("Kai never works around a denied permission. Grant only what you need.")
            }
        }
        .navigationTitle("Permissions")
        .toolbar { Button("Refresh") { model.refreshPermissions() } }
    }

    private func statusBadge(_ status: PermissionAuthorization) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case .authorized: return ("Authorized", .green)
            case .denied: return ("Denied", .red)
            case .notDetermined: return ("Not set", .orange)
            }
        }()
        return Text(text).font(.caption).padding(4).background(color.opacity(0.2), in: Capsule())
    }
}

/// Settings: AI provider selection + update check.
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var providerID = "openai"
    @State private var modelName = "gpt-4o"

    var body: some View {
        TabView {
            Form {
                LabeledContent("Active provider", value: model.selectedProviderID)
                Picker("Provider", selection: $providerID) {
                    ForEach(model.providerIDs, id: \.self) { Text($0).tag($0) }
                }
                TextField("Model", text: $modelName)
                HStack {
                    Button("Apply") { model.selectProvider(id: providerID, model: modelName) }
                    Button("Use offline (echo)") { model.useOffline() }
                }
                Text("API keys are read from the macOS Keychain and never stored in config or logs.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .tabItem { Label("AI", systemImage: "brain") }

            Form {
                LabeledContent("Version", value: model.appVersion)
                Button("Check for updates") { model.checkForUpdates() }
                if let update = model.availableUpdate {
                    Text("Update available: \(update.version)").foregroundStyle(.green)
                } else {
                    Text("Updates are never installed silently.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .tabItem { Label("Updates", systemImage: "arrow.down.circle") }
        }
        .frame(width: 460, height: 280)
        .padding()
    }
}

/// Confirmation/approval sheet for Yellow/Red actions.
struct ApprovalSheet: View {
    @EnvironmentObject private var model: AppModel
    let approval: UIApprovalPrompter.PendingApproval

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(approval.level == .red ? "Approval required" : "Confirm action",
                  systemImage: approval.level == .red ? "exclamationmark.shield.fill" : "questionmark.circle")
                .font(.title2).bold()
                .foregroundStyle(approval.level == .red ? .red : .primary)
            Text(approval.action).foregroundStyle(.secondary).textSelection(.enabled)
            Text("Permission level: \(approval.level.displayName)").font(.caption)
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
        .frame(width: 420)
    }
}
#endif
