import Foundation
import KaiCore

/// Shared, mutable scratch space passed to each step of a workflow. Steps read
/// outputs of earlier steps and write their own. It also exposes the
/// cancellation signal and logger so steps remain interruptible and observable.
public actor WorkflowContext {
    private var bag: [String: String] = [:]
    public let stopController: StopController
    public let logger: KaiLogger

    public init(stopController: StopController, logger: KaiLogger) {
        self.stopController = stopController
        self.logger = logger
    }

    public func set(_ key: String, _ value: String) {
        bag[key] = value
    }

    public func value(forKey key: String) -> String? {
        bag[key]
    }

    public func snapshot() -> [String: String] {
        bag
    }
}

/// A single, named unit of work in a workflow. Steps must be cooperative: they
/// should periodically check `context.stopController` (or perform naturally
/// short operations) so the user can halt the workflow promptly.
public protocol WorkflowStep: Sendable {
    var name: String { get }
    func run(context: WorkflowContext) async throws
}

/// A convenience step built from a closure, for simple cases and tests.
public struct ClosureStep: WorkflowStep {
    public let name: String
    private let body: @Sendable (WorkflowContext) async throws -> Void

    public init(name: String, _ body: @escaping @Sendable (WorkflowContext) async throws -> Void) {
        self.name = name
        self.body = body
    }

    public func run(context: WorkflowContext) async throws {
        try await body(context)
    }
}

/// An ordered, named collection of steps.
public struct Workflow: Sendable {
    public let name: String
    public let steps: [any WorkflowStep]

    public init(name: String, steps: [any WorkflowStep]) {
        self.name = name
        self.steps = steps
    }
}
