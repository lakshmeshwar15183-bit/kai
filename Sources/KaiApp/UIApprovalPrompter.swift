import Foundation
import KaiCore

/// Bridges the permission engine's Yellow/Red decisions to the SwiftUI layer.
///
/// When the router needs a decision it `await`s ``requestDecision(action:level:)``,
/// which suspends until the user responds. Pending requests are surfaced via the
/// ``pending`` async stream; the UI presents a sheet and calls ``resolve(_:granted:)``.
public actor UIApprovalPrompter: PermissionPrompting {
    public struct PendingApproval: Sendable, Identifiable, Equatable {
        public let id: UUID
        public let action: String
        public let level: PermissionLevel
    }

    private var continuations: [UUID: CheckedContinuation<Bool, Never>] = [:]
    private var streamContinuation: AsyncStream<PendingApproval>.Continuation?
    public let pending: AsyncStream<PendingApproval>

    public init() {
        var captured: AsyncStream<PendingApproval>.Continuation!
        self.pending = AsyncStream { captured = $0 }
        self.streamContinuation = captured
    }

    public func requestDecision(action: String, level: PermissionLevel) async -> Bool {
        await withCheckedContinuation { continuation in
            let id = UUID()
            continuations[id] = continuation
            streamContinuation?.yield(PendingApproval(id: id, action: action, level: level))
        }
    }

    /// Resolves a pending approval with the user's decision.
    public func resolve(_ id: UUID, granted: Bool) {
        guard let continuation = continuations.removeValue(forKey: id) else { return }
        continuation.resume(returning: granted)
    }
}
