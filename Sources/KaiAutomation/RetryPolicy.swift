import Foundation

/// How many times, and how patiently, to retry a failing step before giving up.
public struct RetryPolicy: Sendable, Equatable {
    public let maxAttempts: Int
    public let delay: Duration

    public init(maxAttempts: Int = 1, delay: Duration = .zero) {
        self.maxAttempts = max(1, maxAttempts)
        self.delay = delay
    }

    /// Try once, no retry.
    public static let none = RetryPolicy(maxAttempts: 1)
}
