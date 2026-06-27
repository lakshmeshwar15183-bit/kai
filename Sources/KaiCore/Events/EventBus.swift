import Foundation

/// A multicast, in-process event bus built on `AsyncStream`.
///
/// Any number of consumers can call ``subscribe()`` to receive an independent
/// stream of every event published after they subscribe. The bus is an actor,
/// so publishing and subscription bookkeeping are race-free.
public actor EventBus {
    private var continuations: [UUID: AsyncStream<KaiEvent>.Continuation] = [:]

    public init() {}

    /// Returns a new stream that yields every event published while the caller
    /// is iterating. The subscription is automatically removed when the stream
    /// is terminated (e.g. the consuming task is cancelled).
    public func subscribe() -> AsyncStream<KaiEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    /// Publishes an event to all current subscribers.
    public func publish(_ event: KaiEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    /// Convenience for publishing a log line.
    public func log(_ level: LogLevel, _ message: String) {
        publish(KaiEvent(kind: .log(level: level, message: message)))
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }

    /// Number of active subscribers (primarily for testing/diagnostics).
    public var subscriberCount: Int {
        continuations.count
    }
}
