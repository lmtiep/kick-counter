import Foundation
import KickCore
import SwiftData
import Testing
@testable import KickData

@MainActor
struct CycleStoreTests {
    struct SaveFailed: Error {}

    let today = date("2026-10-02T12:00:00Z")
    let container: ModelContainer
    let store: CycleStore

    init() throws {
        container = try KickPersistence.makeContainer(inMemory: true)
        store = CycleStore(context: container.mainContext, calendar: utcCalendar)
    }

    /// A store on the same context whose saves always fail.
    private func failingStore() -> CycleStore {
        CycleStore(context: container.mainContext, calendar: utcCalendar, saveContext: { _ in throw SaveFailed() })
    }

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    private func count<T: PersistentModel>(_ type: T.Type) throws -> Int {
        try container.mainContext.fetchCount(FetchDescriptor<T>())
    }

    @Test func schemaIncludesTheCycleModels() {
        let names = KickPersistence.schema.entities.map(\.name)
        #expect(names.contains("PeriodEntry"))
        #expect(names.contains("CycleLog"))
        #expect(names.contains("Appointment"))
    }

    // MARK: - Periods

    @Test func addedPeriodRoundTripsAtTheStartOfTheDay() throws {
        let period = PeriodRecord(startDate: date("2026-09-03T18:00:00Z"), endDate: date("2026-09-07T06:00:00Z"))
        try store.addPeriod(period, today: today)
        #expect(try store.periods() == [PeriodRecord(id: period.id, startDate: day("2026-09-03"), endDate: day("2026-09-07"))])
    }

    @Test func periodsAreSortedOldestFirst() throws {
        let later = PeriodRecord(startDate: day("2026-09-03"), endDate: day("2026-09-07"))
        let earlier = PeriodRecord(startDate: day("2026-08-06"), endDate: day("2026-08-10"))
        try store.addPeriod(later, today: today)
        try store.addPeriod(earlier, today: today)
        #expect(try store.periods().map(\.id) == [earlier.id, later.id])
    }

    @Test func overlappingPeriodIsRejectedAndNotSaved() throws {
        try store.addPeriod(PeriodRecord(startDate: day("2026-09-03"), endDate: day("2026-09-07")), today: today)
        #expect(throws: CycleRepositoryError.overlapsExistingPeriod) {
            try store.addPeriod(PeriodRecord(startDate: day("2026-09-06")), today: today)
        }
        #expect(try count(PeriodEntry.self) == 1)
    }

    @Test func futurePeriodIsRejected() throws {
        #expect(throws: CycleRepositoryError.futureDate) {
            try store.addPeriod(PeriodRecord(startDate: day("2026-10-03")), today: today)
        }
        #expect(try count(PeriodEntry.self) == 0)
    }

    @Test func updateSetsTheEndAndChecksOverlap() throws {
        var open = PeriodRecord(startDate: day("2026-09-28"))
        try store.addPeriod(PeriodRecord(startDate: day("2026-09-03"), endDate: day("2026-09-07")), today: today)
        try store.addPeriod(open, today: today)
        open.endDate = day("2026-10-01")
        try store.updatePeriod(open, today: today)
        #expect(try store.periods().last == open)

        open.startDate = day("2026-09-05")
        #expect(throws: CycleRepositoryError.overlapsExistingPeriod) {
            try store.updatePeriod(open, today: today)
        }
        #expect(try store.periods().last?.startDate == day("2026-09-28"))
    }

    @Test func updatingAnUnknownPeriodThrowsNotFound() {
        #expect(throws: CycleRepositoryError.notFound) {
            try store.updatePeriod(PeriodRecord(startDate: day("2026-09-03")), today: today)
        }
    }

    @Test func deleteRemovesAndUnknownIDIsANoOp() throws {
        let period = PeriodRecord(startDate: day("2026-09-03"), endDate: day("2026-09-07"))
        try store.addPeriod(period, today: today)
        try store.deletePeriod(id: period.id)
        try store.deletePeriod(id: UUID())
        #expect(try store.periods().isEmpty)
        #expect(try count(PeriodEntry.self) == 0)
    }

    @Test func overlappingPeriodsFromSyncAreMerged() throws {
        // iCloud delivers the same period started on two devices.
        let context = container.mainContext
        context.insert(PeriodEntry(record: PeriodRecord(startDate: day("2026-09-03"))))
        context.insert(PeriodEntry(record: PeriodRecord(startDate: day("2026-09-03"), endDate: day("2026-09-07"))))
        context.insert(PeriodEntry(record: PeriodRecord(startDate: day("2026-08-06"), endDate: day("2026-08-10"))))
        try context.save()

        let periods = try store.periods()
        #expect(periods.map(\.startDate) == [day("2026-08-06"), day("2026-09-03")])
        #expect(periods.last?.endDate == day("2026-09-07"))
        #expect(try count(PeriodEntry.self) == 2)
    }

    // MARK: - Day logs

    @Test func logRoundTripsEveryField() throws {
        let log = CycleLogRecord(day: date("2026-10-01T21:00:00Z"), lh: .positive, bbtCelsius: 36.55, mucus: .eggWhite, note: " Cramps ")
        try store.saveLog(log, today: today)
        #expect(try store.logs() == [CycleLogRecord(id: log.id, day: day("2026-10-01"), lh: .positive, bbtCelsius: 36.55, mucus: .eggWhite, note: "Cramps")])
    }

    @Test func savingTheSameDayAgainReplacesTheLogAndKeepsItsID() throws {
        let first = CycleLogRecord(day: day("2026-10-01"), lh: .negative)
        try store.saveLog(first, today: today)
        try store.saveLog(CycleLogRecord(day: date("2026-10-01T09:00:00Z"), lh: .positive, mucus: .creamy), today: today)
        #expect(try store.logs() == [CycleLogRecord(id: first.id, day: day("2026-10-01"), lh: .positive, mucus: .creamy)])
        #expect(try count(CycleLog.self) == 1)
    }

    @Test func emptyLogDeletesTheDay() throws {
        try store.saveLog(CycleLogRecord(day: day("2026-10-01"), mucus: .dry), today: today)
        try store.saveLog(CycleLogRecord(day: day("2026-10-01"), note: "  "), today: today)
        #expect(try store.logs().isEmpty)
        #expect(try count(CycleLog.self) == 0)
    }

    @Test func implausibleTemperatureAndFutureDaysAreRejected() throws {
        #expect(throws: CycleRepositoryError.invalidTemperature) {
            try store.saveLog(CycleLogRecord(day: day("2026-10-01"), bbtCelsius: 40.1), today: today)
        }
        #expect(throws: CycleRepositoryError.futureDate) {
            try store.saveLog(CycleLogRecord(day: day("2026-10-03"), mucus: .dry), today: today)
        }
        #expect(try count(CycleLog.self) == 0)
    }

    @Test func sameDayLogsFromSyncAreMerged() throws {
        let context = container.mainContext
        context.insert(CycleLog(record: CycleLogRecord(day: day("2026-10-01"), lh: .negative, note: "Tired")))
        context.insert(CycleLog(record: CycleLogRecord(day: day("2026-10-01"), lh: .positive, bbtCelsius: 36.4)))
        try context.save()

        let logs = try store.logs()
        #expect(logs.count == 1)
        #expect(logs.first?.lh == .positive)
        #expect(logs.first?.bbtCelsius == 36.4)
        #expect(logs.first?.note == "Tired")
        #expect(try count(CycleLog.self) == 1)
    }

    @Test func unknownRawValuesDecodeToNilAndSurviveAMergeThatLeavesTheKeptRowAlone() throws {
        // Values a newer app version may sync that this build does not know.
        let context = container.mainContext
        let keptID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let kept = CycleLog(record: CycleLogRecord(id: keptID, day: day("2026-10-01"), note: "Tired"))
        kept.lhRaw = "inconclusive"
        kept.mucusRaw = "spotting"
        context.insert(kept)
        context.insert(CycleLog(record: CycleLogRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, day: day("2026-10-01"), note: "Tired"
        )))
        try context.save()

        #expect(kept.record.lh == nil)
        #expect(kept.record.mucus == nil)
        #expect(try store.logs() == [CycleLogRecord(id: keptID, day: day("2026-10-01"), note: "Tired")])
        #expect(try count(CycleLog.self) == 1)
        #expect(kept.lhRaw == "inconclusive")
        #expect(kept.mucusRaw == "spotting")
    }

    @Test func mergeThatChangesOtherFieldsKeepsUnknownRawValues() throws {
        let context = container.mainContext
        let kept = CycleLog(record: CycleLogRecord(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, day: day("2026-10-01")))
        kept.lhRaw = "inconclusive"
        kept.mucusRaw = "spotting"
        context.insert(kept)
        context.insert(CycleLog(record: CycleLogRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, day: day("2026-10-01"), bbtCelsius: 36.4
        )))
        try context.save()

        #expect(try store.logs().first?.bbtCelsius == 36.4)
        #expect(kept.bbtCelsius == 36.4)
        #expect(kept.lhRaw == "inconclusive")
        #expect(kept.mucusRaw == "spotting")
    }

    // MARK: - Rollback

    @Test func failedPeriodSaveRollsBack() throws {
        #expect(throws: SaveFailed.self) {
            try failingStore().addPeriod(PeriodRecord(startDate: day("2026-09-03")), today: today)
        }
        #expect(try store.periods().isEmpty)
        #expect(try count(PeriodEntry.self) == 0)
    }

    @Test func failedLogSaveRollsBack() throws {
        let log = CycleLogRecord(day: day("2026-10-01"), lh: .negative)
        try store.saveLog(log, today: today)
        #expect(throws: SaveFailed.self) {
            try failingStore().saveLog(CycleLogRecord(day: day("2026-10-01"), lh: .positive), today: today)
        }
        #expect(try store.logs() == [log])
    }

    @Test func failedDeleteRollsBack() throws {
        let period = PeriodRecord(startDate: day("2026-09-03"), endDate: day("2026-09-07"))
        try store.addPeriod(period, today: today)
        #expect(throws: SaveFailed.self) {
            try failingStore().deletePeriod(id: period.id)
        }
        #expect(try store.periods() == [period])
    }

    @Test func failedPeriodUpdateRollsBack() throws {
        let period = PeriodRecord(startDate: day("2026-09-28"))
        try store.addPeriod(period, today: today)
        var ended = period
        ended.endDate = day("2026-10-01")
        #expect(throws: SaveFailed.self) {
            try failingStore().updatePeriod(ended, today: today)
        }
        #expect(try store.periods() == [period])
    }

    @Test func failedMergeSaveThrowsAndKeepsTheDuplicates() throws {
        let context = container.mainContext
        context.insert(PeriodEntry(record: PeriodRecord(startDate: day("2026-09-03"))))
        context.insert(PeriodEntry(record: PeriodRecord(startDate: day("2026-09-03"), endDate: day("2026-09-07"))))
        context.insert(CycleLog(record: CycleLogRecord(day: day("2026-10-01"), lh: .negative)))
        context.insert(CycleLog(record: CycleLogRecord(day: day("2026-10-01"), lh: .positive)))
        try context.save()

        let failing = failingStore()
        #expect(throws: SaveFailed.self) {
            try failing.periods()
        }
        #expect(throws: SaveFailed.self) {
            try failing.logs()
        }
        #expect(try count(PeriodEntry.self) == 2)
        #expect(try count(CycleLog.self) == 2)
    }
}
