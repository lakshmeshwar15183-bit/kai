import Foundation

/// Raised when a dependency graph cannot be ordered.
public enum DependencyError: Error, Sendable, Equatable {
    case cycleDetected
    case unknownNode
}

/// A directed acyclic graph of step identifiers used to order workflow steps by
/// their dependencies. Ordering uses Kahn's algorithm and detects cycles.
public struct DependencyGraph<ID: Hashable & Sendable & Comparable>: Sendable {
    private var nodes: Set<ID> = []
    /// node -> set of nodes it depends on (must run first).
    private var dependencies: [ID: Set<ID>] = [:]

    public init() {}

    public mutating func addNode(_ id: ID) {
        nodes.insert(id)
        if dependencies[id] == nil { dependencies[id] = [] }
    }

    /// Declares that `node` depends on `prerequisite` (prerequisite runs first).
    public mutating func addDependency(_ node: ID, dependsOn prerequisite: ID) {
        addNode(node)
        addNode(prerequisite)
        dependencies[node, default: []].insert(prerequisite)
    }

    /// Returns the nodes in an order that respects all dependencies. Ties are
    /// broken by the natural ordering of `ID` for deterministic output.
    public func topologicallySorted() throws -> [ID] {
        var indegree: [ID: Int] = [:]
        for node in nodes { indegree[node] = dependencies[node]?.count ?? 0 }

        var ready = indegree.filter { $0.value == 0 }.map(\.key).sorted()
        var order: [ID] = []

        while !ready.isEmpty {
            let node = ready.removeFirst()
            order.append(node)
            // Decrement indegree of nodes that depend on `node`.
            for candidate in nodes where dependencies[candidate]?.contains(node) == true {
                indegree[candidate, default: 0] -= 1
                if indegree[candidate] == 0 {
                    ready.append(candidate)
                    ready.sort()
                }
            }
        }

        guard order.count == nodes.count else { throw DependencyError.cycleDetected }
        return order
    }
}
