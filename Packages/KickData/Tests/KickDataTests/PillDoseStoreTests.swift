import Foundation
import KickCore
import SwiftData
import Testing
@testable import KickData

/// Phase 17 spec §3.2: at most one dose per calendar day.
@MainActor
struct PillDoseStoreTests {
    let container: ModelContainer
    let store: PillDoseStore
    let oct8 = CalendarDay(year: 2026, month: 10, day: 8)
    let oct9 = CalendarDay(year: 2026, month: 10, day: 9)

    init() throws {
        container = try KickPersistence.makeContainer(inMemory: true)
        store = PillDoseStore(context: container.mainContext, calendar: utcCalendar)
    }

    private struct InjectedFailure: Error {}

    private func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    @Test func markingStoresTheCalendarDay() throws {
        try store.markTaken(on: oct8, at: date("2026-10-08T21:04:00Z"))
        let doses = try store.doses()
        #expect(doses.count == 1)
        #expect(doses.first?.day == oct8)
        #expect(doses.first?.takenAt == date("2026-10-08T21:04:00Z"))
        #expect(try container.mainContext.fetch(FetchDescriptor<PillDose>()).first?.dayKey == 20261008)
    }

    @Test func oneDosePerDayKeepingTheFirstTime() throws {
        try store.markTaken(on: oct8, at: date("2026-10-08T21:04:00Z"))
        try store.markTaken(on: oct8, at: date("2026-10-08T23:00:00Z"))
        try store.markTaken(on: oct9, at: date("2026-10-09T21:00:00Z"))
        let doses = try store.doses()
        #expect(doses.map(\.day) == [oct8, oct9])
        #expect(doses.first?.takenAt == date("2026-10-08T21:04:00Z"))
    }

    @Test func duplicatesOnOneDayAreMergedOnRead() throws {
        let context = container.mainContext
        let day = date("2026-10-08T00:00:00Z")
        context.insert(PillDose(record: PillDoseRecord(day: oct8, takenAt: day.addingTimeInterval(80_000))))
        context.insert(PillDose(record: PillDoseRecord(day: oct8, takenAt: day.addingTimeInterval(70_000))))
        try context.save()
        let doses = try store.doses()
        #expect(doses.count == 1)
        #expect(doses.first?.takenAt == day.addingTimeInterval(70_000))
        #expect(try context.fetchCount(FetchDescriptor<PillDose>()) == 1)
    }

    /// A dose marked in Hanoi reads as the same date from a store in New York.
    @Test func aDoseKeepsItsDayInAnotherTimeZone() throws {
        let hanoi = PillDoseStore(context: container.mainContext, calendar: calendar("Asia/Ho_Chi_Minh"))
        // Marked at 06:30 on Oct 9 in Hanoi, which is 19:30 on Oct 8 in New York:
        // the pill stays Oct 9's.
        try hanoi.markTaken(on: oct9, at: date("2026-10-08T23:30:00Z"))
        let newYork = PillDoseStore(context: container.mainContext, calendar: calendar("America/New_York"))
        #expect(try newYork.doses().map(\.day) == [oct9])
        try newYork.unmark(on: oct9)
        #expect(try newYork.doses().isEmpty)
    }

    /// Rows written by earlier builds of this branch have no `dayKey`: their
    /// day comes from `day` and is stored.
    @Test func olderRowsGetTheirDayKey() throws {
        let context = container.mainContext
        let older = PillDose(record: PillDoseRecord(day: oct8, takenAt: date("2026-10-08T21:00:00Z")))
        older.dayKey = 0
        older.day = date("2026-10-08T00:00:00Z")
        context.insert(older)
        try context.save()
        #expect(try store.doses().map(\.day) == [oct8])
        #expect(older.dayKey == 20261008)
    }

    @Test func aFutureDayIsRefused() {
        #expect(throws: PillDoseError.futureDate) {
            try store.markTaken(on: CalendarDay(year: 2026, month: 10, day: 10), at: date("2026-10-09T21:00:00Z"))
        }
    }

    @Test func unmarkRemovesThatDayOnly() throws {
        try store.markTaken(on: oct8, at: date("2026-10-08T21:00:00Z"))
        try store.markTaken(on: oct9, at: date("2026-10-09T21:00:00Z"))
        try store.unmark(on: oct9)
        try store.unmark(on: CalendarDay(year: 2026, month: 10, day: 1))
        #expect(try store.doses().map(\.day) == [oct8])
    }

    @Test func aFailedSaveRollsBack() throws {
        let failing = PillDoseStore(context: container.mainContext, calendar: utcCalendar) { _ in throw InjectedFailure() }
        #expect(throws: InjectedFailure.self) {
            try failing.markTaken(on: oct8, at: date("2026-10-08T21:00:00Z"))
        }
        #expect(try store.doses().isEmpty)
    }
}
