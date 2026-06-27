#if os(macOS)
import Foundation
import SwiftUI
import KaiCore
import KaiAI
import KaiPlugins
import KaiVoice

/// The observable bridge between the actor-based core and SwiftUI. It owns the
/// ``KaiAssembly`` composition root, subscribes to the event bus and the
/// approval prompter, and exposes published state plus user intents.
@MainActor
public final class AppModel: ObservableObject {
    // Published UI state
    @Published public private(set) var state: ActivationState = .sleeping
    @Published public private(set) var mode: InteractionMode = .execute
    @Published public private(set) var manifests: [PluginManifest] = []
    @Published public private(set) var activity: [String] = []
    @Published public var transcript: [TranscriptEntry] = []
    @Published public var pendingApproval: UIApprovalPrompter.PendingApproval?
    @Published public private(set) var permissions: [SystemPermission: PermissionAuthorization] = [:]
    @Published public private(set) var providerIDs: [String] = []
    @Published public var selectedProviderID: String = "echo (offline)"
    @Published public private(set) var isListening = false
    @Published public private(set) var availableUpdate: UpdateInfo?
    @Published public var connectionTestResult: String = ""
    @Published private var keyStateVersion = 0

    public struct TranscriptEntry: Identifiable, Equatable {
        public let id = UUID()
        public let isUser: Bool
        public let text: String
    }

    private let assembly = KaiAssembly()
    private var voiceTask: Task<Void, Never>?
    public let appVersion = "0.4.0"

    public init() {
        Task { await start() }
    }

    private func start() async {
        await assembly.bootstrap()
        manifests = await assembly.registry.manifests()
        providerIDs = await assembly.providerRegistry.registeredIDs
        refreshPermissions()
        // Reflect the active provider chosen on launch (Echo if none configured).
        if let id = AppSettings.savedProviderID(), let model = AppSettings.savedModel(),
           assembly.hasKey(forProvider: id) {
            selectedProviderID = "\(id)/\(model)"
        } else {
            selectedProviderID = "echo (offline)"
        }

        // Event stream → UI.
        let events = await assembly.eventBus.subscribe()
        Task { @MainActor in
            for await event in events { self.apply(event) }
        }
        // Approval requests → sheet.
        Task { @MainActor in
            for await pending in assembly.prompter.pending {
                self.pendingApproval = pending
            }
        }
        try? await assembly.stateMachine.activate(trigger: .typedCommand)
        try? await assembly.stateMachine.transition(to: .thinking)
    }

    private func apply(_ event: KaiEvent) {
        switch event.kind {
        case let .stateChanged(_, to): state = to
        case let .modeChanged(newMode): mode = newMode
        case let .log(level, message): append("[\(level.label)] \(message)")
        case let .permissionRequested(action, level): append("permission [\(level.displayName)]: \(action)")
        case let .permissionResolved(action, granted): append("permission \(granted ? "granted" : "denied"): \(action)")
        case let .workflow(workflowEvent): append("workflow: \(workflowEvent)")
        case let .activated(trigger): append("activated via \(trigger.rawValue)")
        case let .stopRequested(command): append("STOP (\(command.rawValue))")
        }
    }

    private func append(_ line: String) {
        activity.append(line)
        if activity.count > 500 { activity.removeFirst(activity.count - 500) }
    }

    // MARK: - Intents

    public func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        transcript.append(.init(isUser: true, text: trimmed))
        Task {
            await assembly.audit.record(category: "command", trimmed)
            do {
                let result = try await assembly.router.route(KaiCommand(text: trimmed))
                transcript.append(.init(isUser: false, text: result.message))
            } catch {
                transcript.append(.init(isUser: false, text: "⚠️ \(error)"))
            }
        }
    }

    public func stop() { Task { await assembly.stateMachine.stop() } }

    public func resolveApproval(_ approval: UIApprovalPrompter.PendingApproval, granted: Bool) {
        pendingApproval = nil
        Task { await assembly.prompter.resolve(approval.id, granted: granted) }
    }

    public func refreshPermissions() {
        var result: [SystemPermission: PermissionAuthorization] = [:]
        for permission in SystemPermission.allCases {
            result[permission] = assembly.permissions.status(of: permission)
        }
        permissions = result
    }

    public func requestPermission(_ permission: SystemPermission) {
        Task {
            _ = await assembly.permissions.request(permission)
            refreshPermissions()
        }
    }

    public func openPermissionSettings(_ permission: SystemPermission) {
        assembly.permissions.openSettings(for: permission)
    }

    public func applyProvider(id: String, model: String) {
        Task {
            do {
                try await assembly.selectProvider(AIProviderConfig(providerID: id, model: model))
                assembly.persistProvider(id: id, model: model)
                selectedProviderID = "\(id)/\(model)"
                connectionTestResult = "Active provider set to \(id)/\(model)."
            } catch {
                connectionTestResult = "Failed to set provider: \(error)"
            }
        }
    }

    public func useOffline() {
        Task { await assembly.useOfflineProvider() }
        selectedProviderID = "echo (offline)"
        connectionTestResult = "Using offline echo provider."
    }

    /// Stores an API key for a provider in the Keychain.
    public func saveAPIKey(_ key: String, forProvider id: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        assembly.saveAPIKey(trimmed, forProvider: id)
        keyStateVersion += 1
        connectionTestResult = "Saved API key for \(id) to Keychain."
    }

    /// Whether a usable credential exists for the provider (Ollama needs none).
    public func hasStoredKey(forProvider id: String) -> Bool {
        _ = keyStateVersion // re-evaluate when keys change
        return assembly.hasKey(forProvider: id)
    }

    /// Performs a live request to verify the provider/key without switching to it.
    public func testConnection(id: String, model: String) {
        connectionTestResult = "Testing \(id)/\(model)…"
        Task {
            let result = await assembly.testConnection(AIProviderConfig(providerID: id, model: model))
            connectionTestResult = result
        }
    }

    public func checkForUpdates() {
        Task { availableUpdate = try? await assembly.updateChecker.checkForUpdate(current: appVersion) }
    }

    // MARK: - Voice

    public func toggleVoice() { isListening ? stopVoice() : startVoice() }

    public func startVoice() {
        guard voiceTask == nil else { return }
        isListening = true
        voiceTask = Task { [assembly] in
            while !Task.isCancelled {
                guard let utterance = try? await assembly.recognizer.transcribeUtterance() else { break }
                let event = await assembly.voice.handle(utterance)
                switch event {
                case .wokeUp:
                    await assembly.synthesizer.speak("Yes?")
                case let .command(command):
                    await MainActor.run { self.send(command) }
                    await assembly.voice.finishedProcessing()
                case .stopped:
                    await MainActor.run { self.stop() }
                case .wentToSleep, .ignoredWhileSleeping:
                    break
                }
            }
            await MainActor.run { self.isListening = false }
        }
    }

    public func stopVoice() {
        voiceTask?.cancel()
        voiceTask = nil
        isListening = false
    }
}
#endif
