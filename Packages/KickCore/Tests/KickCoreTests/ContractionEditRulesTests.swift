import Foundation
import Testing
@testable import KickCore

/// Editing contractions (spec 2026-11-06): the same rules as live timing, as pure checks.
struct ContractionEditRulesTests {
    let now = date("2026-11-06T12:00:00Z")

    private func at(_ secondsAgo: TimeInterval) -> Date { now.addingTimeInterval(-secondsAgo) }

    private func record(_ startAgo: TimeInterval, lasting duration: TimeInterval = 60) -> ContractionRecord {
        ContractionRecord(startedAt: at(startAgo), endedAt: at(startAgo).addingTimeInterval(duration))
    }

    private func validate(
        start: Date, end: Date, existing: [ContractionRecord] = [], id: UUID? = nil
    ) -> ContractionEditError? {
        ContractionEditRules.validate(id: id, start: start, end: end, existing: existing, now: now)
    }

    @Test func validEditHasNoError() {
        #expect(validate(start: at(600), end: at(540)) == nil)
    }

    @Test func startInFutureIsRefused() {
        #expect(validate(start: now.addingTimeInterval(1), end: now.addingTimeInterval(61)) == .startInFuture)
    }

    @Test func endInFutureIsRefused() {
        #expect(validate(start: at(10), end: now.addingTimeInterval(1)) == .endInFuture)
    }

    @Test func endMustBeAfterStart() {
        #expect(validate(start: at(100), end: at(100)) == .endNotAfterStart)
        #expect(validate(start: at(100), end: at(120)) == .endNotAfterStart)
    }

    @Test func underThreeSecondsIsTooShort() {
        #expect(validate(start: at(100), end: at(100).addingTimeInterval(2.9)) == .tooShort)
    }

    @Test func exactlyThreeSecondsIsAllowed() {
        #expect(validate(start: at(100), end: at(100).addingTimeInterval(3)) == nil)
    }

    @Test func overFiveMinutesIsTooLong() {
        #expect(validate(start: at(1000), end: at(1000).addingTimeInterval(300.1)) == .tooLong)
    }

    @Test func exactlyFiveMinutesIsAllowed() {
        #expect(validate(start: at(1000), end: at(1000).addingTimeInterval(300)) == nil)
    }

    /// The neighbour runs 600..540 s ago; the edit's end reaches into it.
    @Test func overlapAtTheStartEdgeIsRefused() {
        let neighbour = record(600, lasting: 60)
        #expect(validate(start: at(700), end: at(570), existing: [neighbour]) == .overlapsNeighbour)
    }

    /// The edit's start lands inside the neighbour.
    @Test func overlapAtTheEndEdgeIsRefused() {
        let neighbour = record(600, lasting: 60)
        #expect(validate(start: at(570), end: at(500), existing: [neighbour]) == .overlapsNeighbour)
    }

    @Test func containingANeighbourIsRefused() {
        let neighbour = record(600, lasting: 60)
        #expect(validate(start: at(700), end: at(400), existing: [neighbour]) == .overlapsNeighbour)
    }

    @Test func touchingANeighbourIsAllowed() {
        let neighbour = record(600, lasting: 60)
        #expect(validate(start: at(540), end: at(480), existing: [neighbour]) == nil)
        #expect(validate(start: at(660), end: at(600), existing: [neighbour]) == nil)
    }

    @Test func itsOwnRecordIsIgnored() {
        let own = record(600, lasting: 60)
        #expect(validate(start: at(590), end: at(520), existing: [own], id: own.id) == nil)
    }

    @Test func aRunningNeighbourEndsAtNow() {
        let running = ContractionRecord(startedAt: at(100))
        #expect(validate(start: at(130), end: at(90), existing: [running]) == .overlapsNeighbour)
        #expect(validate(start: at(200), end: at(100), existing: [running]) == nil)
    }

    @Test func markerInFutureIsRefused() {
        #expect(ContractionEditRules.validateMarker(at: now.addingTimeInterval(1), now: now) == .startInFuture)
        #expect(ContractionEditRules.validateMarker(at: now, now: now) == nil)
    }

    @Test func keepingSecondsKeepsTheOriginalSeconds() {
        let original = date("2026-11-06T11:58:37Z")
        let picked = date("2026-11-06T12:01:00Z")
        let result = ContractionEditRules.keepingSeconds(of: original, in: picked, calendar: utcCalendar)
        #expect(result == date("2026-11-06T12:01:37Z"))
    }
}
