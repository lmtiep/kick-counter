import Testing
@testable import KickCore

/// Phase 7 plan Task 1: a cancelled sheet drag must not leave the sheet stuck.
struct SheetDragStateTests {
    @Test func startsIdle() {
        let drag = SheetDragState()
        #expect(!drag.isDragging)
        #expect(drag.translation == nil)
        #expect(drag.handoffStart == nil)
    }

    @Test func movingFollowsTheFinger() {
        var drag = SheetDragState()
        drag.move(by: -120)
        #expect(drag.isDragging)
        #expect(drag.translation == -120)
    }

    @Test func endingReportsWhetherTheSheetMovedAndClearsEverything() {
        var drag = SheetDragState()
        drag.beginHandoff(at: 30)
        drag.move(by: 80)
        let moved = drag.end()
        #expect(moved)
        #expect(drag == SheetDragState())
        let movedAgain = drag.end() // the cancel clean-up after onEnded is a no-op
        #expect(!movedAgain)
    }

    @Test func aHandoffAloneIsNotAMove() {
        var drag = SheetDragState()
        drag.beginHandoff(at: 30)
        #expect(!drag.isDragging)
        #expect(drag.handoffStart == 30)
        let moved = drag.end()
        #expect(!moved)
        #expect(drag.handoffStart == nil)
    }
}
