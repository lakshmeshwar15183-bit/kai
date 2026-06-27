import Foundation

/// Records reversible Finder operations so the user can say "undo". An actor
/// because the stack is shared mutable state.
public actor FinderUndoStack {
    /// A single reversible action.
    public enum Action: Sendable, Equatable {
        /// Restore a trashed item.
        case restore(TrashToken)
        /// Reverse a move/rename: the item now lives at `moved` and should go
        /// back to `original`.
        case reverseMove(original: URL, moved: URL)
    }

    private var actions: [Action] = []

    public init() {}

    public func push(_ action: Action) {
        actions.append(action)
    }

    public func pop() -> Action? {
        actions.popLast()
    }

    public var count: Int { actions.count }
}
