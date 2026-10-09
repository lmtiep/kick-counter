import Foundation
import KickCore
import SwiftData
import Testing
@testable import KickData

/// Phase 17 spec §3.2: at most one dose per day.
@MainActor
struct PillDoseStoreTests {
    let container: ModelContainer
    let store: PillDoseStore

    init() throws {
        container = try KickPersistence.makeContainer(inMemory: true)
        store = PillDoseStore(context: container.mainContext, calendar: utcCalendar)
    }

    private struct InjectedFailure: Error {}

    @Test func markingStoresTheDayAtStartOfDay() throws {
        try store.markTaken(on: date("2026-10-08T15:00:00Z"), at: date("2026-10-08T21:04:00Z"))
        let doses = try store.doses()
        #expect(doses.count == 1)
        #expect(doses.first?.day == date("2026-10-08T00:00:00Z"))
        #expect(doses.first?.takenAt == date("2026-10-08T21:04:00Z"))
    }

    @Test func oneDosePerDayKeepingTheFirstTime() throws {
        try store.markTaken(on: date("2026-10-08T00:00:00Z"), at: date("2026-10-08T21:04:00Z"))
        try store.markTaken(on: date("2026-10-08T12:00:00Z"), at: date("2026-10-08T23:00:00Z"))
        try store.markTaken(on: date("2026-10-09T00:00:00Z"), at: date("2026-10-09T21:00:00Z"))
        let doses = try store.doses()
        #expect(doses.map(\.day) == [date("2026-10-08T00:00:00Z"), date("2026-10-09T00:00:00Z")])
        #expect(doses.first?.takenAt == date("2026-10-08T21:04:00Z"))
    }

    @Test func duplicatesOnOneDayAreMergedOnRead() throws {
        let context = container.mainContext
        let day = date("2026-10-08T00:00:00Z")
        context.insert(PillDose(record: PillDoseRecord(day: day, takenAt: day.addingTimeInterval(80_000))))
        context.insert(PillDose(record: PillDoseRecord(day: day, takenAt: day.addingTimeInterval(70_000))))
        try context.save()
        let doses = try store.doses()
        #expect(doses.count == 1)
        #expect(doses.first?.takenAt == day.addingTimeInterval(70_000))
        #expect(try context.fetchCount(FetchDescriptor<PillDose>()) == 1)
    }

    @Test func aFutureDayIsRefused() {
        #expect(throws: PillDoseError.futureDate) {
            try store.markTaken(on: date("2026-10-10T00:00:00Z"), at: date("2026-10-09T21:00:00Z"))
        }
    }

    @Test func unmarkRemovesThatDayOnly() throws {
        try store.markTaken(on: date("2026-10-08T00:00:00Z"), at: date("2026-10-08T21:00:00Z"))
        try store.markTaken(on: date("2026-10-09T00:00:00Z"), at: date("2026-10-09T21:00:00Z"))
        try store.unmark(on: date("2026-10-09T18:00:00Z"))
        try store.unmark(on: date("2026-10-01T00:00:00Z"))
        #expect(try store.doses().map(\.day) == [date("2026-10-08T00:00:00Z")])
    }

    @Test func aFailedSaveRollsBack() throws {
        let failing = PillDoseStore(context: container.mainContext, calendar: utcCalendar) { _ in throw InjectedFailure() }
        #expect(throws: InjectedFailure.self) {
            try failing.markTaken(on: date("2026-10-08T00:00:00Z"), at: date("2026-10-08T21:00:00Z"))
        }
        #expect(try store.doses().isEmpty)
    }
}
