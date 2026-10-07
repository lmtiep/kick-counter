import Foundation

/// The in-flight drag of `ArticleSheet` (phase 7 plan, Task 1). SwiftUI calls a
/// drag gesture's `onEnded` only when the finger lifts; a cancelled gesture (a
/// system alert, the app leaving the foreground, another gesture winning) skips
/// it. Keeping the whole drag in one value lets the sheet clear it in one place
/// when its `@GestureState` reports that no drag is live any more.
public struct SheetDragState: Sendable, Equatable {
    /// The finger's vertical translation the sheet follows; nil while the sheet is not moving.
    public private(set) var translation: Double?
    /// The finger's translation when a drag on the expanded body was handed to the sheet.
    public private(set) var handoffStart: Double?

    public init() {}

    public var isDragging: Bool { translation != nil }

    public mutating func move(by translation: Double) {
        self.translation = translation
    }

    public mutating func beginHandoff(at translation: Double) {
        handoffStart = translation
    }

    /// Clears the drag. Returns true when the sheet had moved, so it must settle on a detent.
    @discardableResult
    public mutating func end() -> Bool {
        let moved = isDragging
        self = SheetDragState()
        return moved
    }
}
