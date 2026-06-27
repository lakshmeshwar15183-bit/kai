import Foundation
import KaiAI

/// An `AIProvider` whose backing provider can be swapped at runtime, so the
/// Settings screen can change vendor without rebuilding the command pipeline.
///
/// Implemented as an **actor** rather than a lock-guarded class: there is no
/// `NSLock`, no shared mutable state outside the actor, and therefore no risk of
/// holding a lock across an `await`. This is Swift 6 strict-concurrency-safe by
/// construction. It is platform-agnostic (no Apple frameworks) so it builds and
/// is checked on every platform, including CI.
public actor SwitchableAIProvider: AIProvider {
    /// Stable, fixed identifiers (the wrapper's identity, not the backing one).
    public nonisolated let id = "switchable"
    public nonisolated let model = "switchable"

    private var backing: any AIProvider

    public init(_ initial: any AIProvider) {
        self.backing = initial
    }

    /// Swaps the backing provider. In-flight completions keep using the provider
    /// they captured.
    public func setProvider(_ provider: any AIProvider) {
        backing = provider
    }

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        let provider = backing
        return try await provider.complete(request)
    }
}
