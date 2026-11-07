import Foundation
import Testing
@testable import KickCore

/// Edit round 2: the add-missed sheet's state is a start and a length, so moving
/// the start keeps the length.
struct ContractionDraftTests {
    let now = date("2026-11-06T12:00:00Z")

    @Test func theMissedDefaultIsAMinuteLongEndingNow() {
        let draft = ContractionDraft.missed(now: now)
        #expect(draft.start == now.addingTimeInterval(-60))
        #expect(draft.duration == 60)
        #expect(draft.end == now)
    }

    @Test func movingTheStartKeepsTheLengthWhenAdding() {
        var draft = ContractionDraft.missed(now: now)
        draft.setStart(now.addingTimeInterval(-20 * 60), keepingLength: true)
        #expect(draft.duration == 60)
        #expect(draft.end == now.addingTimeInterval(-19 * 60))
        #expect(ContractionEditRules.validate(id: nil, start: draft.start, end: draft.end, existing: [], now: now) == nil)
    }

    @Test func movingTheStartChangesTheLengthWhenEditing() {
        var draft = ContractionDraft(start: now.addingTimeInterval(-600), end: now.addingTimeInterval(-540))
        draft.setStart(now.addingTimeInterval(-630), keepingLength: false)
        #expect(draft.end == now.addingTimeInterval(-540))
        #expect(draft.duration == 90)
    }

    @Test func theLengthMovesTheEnd() {
        var draft = ContractionDraft.missed(now: now)
        draft.setDuration(75)
        #expect(draft.end == now.addingTimeInterval(15))
        #expect(draft.start == now.addingTimeInterval(-60))
    }

    @Test func theEndChangesTheLength() {
        var draft = ContractionDraft.missed(now: now)
        draft.setEnd(now.addingTimeInterval(-30))
        #expect(draft.duration == 30)
    }
}
