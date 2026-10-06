import Foundation
import KickCore
import SwiftData
import Testing
@testable import KickData

@MainActor
struct WeightStoreTests {
    struct SaveFailed: Error {}

    let today = date("2026-10-02T12:00:00Z")
    let container: ModelContainer
    let store: WeightStore

    init() throws {
        container = try KickPersistence.makeContainer(inMemory: true)
        store = WeightStore(context: container.mainContext, calendar: utcCalendar)
    }

    private func failingStore() -> WeightStore {
        WeightStore(context: container.mainContext, calendar: utcCalendar, saveContext: { _ in throw SaveFailed() })
    }

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    private func count() throws -> Int {
        try container.mainContext.fetchCount(FetchDescriptor<WeightEntry>())
    }

    @Test func schemaIncludesWeightEntry() {
        #expect(KickPersistence.schema.entities.map(\.name).contains("WeightEntry"))
    }

    @Test func savedEntryRoundTripsAtTheStartOfTheDayRounded() throws {
        let entry = WeightRecord(day: date("2026-10-01T18:00:00Z"), kg: 58.04)
        try store.save(entry, today: today)
        #expect(try store.entries() == [WeightRecord(id: entry.id, day: day("2026-10-01"), kg: 58.0)])
    }

    @Test func entriesAreOldestFirst() throws {
        try store.save(WeightRecord(day: day("2026-10-01"), kg: 58), today: today)
        try store.save(WeightRecord(day: day("2026-09-01"), kg: 56), today: today)
        #expect(try store.entries().map(\.kg) == [56, 58])
    }

    @Test func savingTheSameDayAgainUpdatesTheEntryAndKeepsItsID() throws {
        let first = WeightRecord(day: day("2026-10-01"), kg: 58)
        try store.save(first, today: today)
        try store.save(WeightRecord(day: date("2026-10-01T20:00:00Z"), kg: 58.4), today: today)
        #expect(try store.entries() == [WeightRecord(id: first.id, day: day("2026-10-01"), kg: 58.4)])
        #expect(try count() == 1)
    }

    @Test func futureDaysAndImplausibleWeightsAreRefused() throws {
        #expect(throws: WeightRepositoryError.futureDate) {
            try store.save(WeightRecord(day: day("2026-10-03"), kg: 58), today: today)
        }
        #expect(throws: WeightRepositoryError.outOfRange) {
            try store.save(WeightRecord(day: day("2026-10-01"), kg: 250), today: today)
        }
        #expect(try count() == 0)
    }

    @Test func deleteRemovesAndUnknownIDIsANoOp() throws {
        let entry = WeightRecord(day: day("2026-10-01"), kg: 58)
        try store.save(entry, today: today)
        try store.delete(id: UUID())
        #expect(try count() == 1)
        try store.delete(id: entry.id)
        #expect(try store.entries().isEmpty)
    }

    @Test func sameDayEntriesFromSyncKeepTheFirstIDWithItsOwnWeight() throws {
        let context = container.mainContext
        let keptID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        context.insert(WeightEntry(record: WeightRecord(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, day: day("2026-10-01"), kg: 58.4)))
        context.insert(WeightEntry(record: WeightRecord(id: keptID, day: day("2026-10-01"), kg: 58.0)))
        try context.save()
        #expect(try store.entries() == [WeightRecord(id: keptID, day: day("2026-10-01"), kg: 58.0)])
        #expect(try count() == 1)
    }

    @Test func failedSaveRollsBack() throws {
        let entry = WeightRecord(day: day("2026-10-01"), kg: 58)
        try store.save(entry, today: today)
        #expect(throws: SaveFailed.self) {
            try failingStore().save(WeightRecord(day: day("2026-10-01"), kg: 60), today: today)
        }
        #expect(throws: SaveFailed.self) {
            try failingStore().save(WeightRecord(day: day("2026-09-30"), kg: 57), today: today)
        }
        #expect(try store.entries() == [entry])
    }

    @Test func failedDeleteRollsBack() throws {
        let entry = WeightRecord(day: day("2026-10-01"), kg: 58)
        try store.save(entry, today: today)
        #expect(throws: SaveFailed.self) {
            try failingStore().delete(id: entry.id)
        }
        #expect(try store.entries() == [entry])
    }

    @Test func failedMergeSaveThrowsAndKeepsTheDuplicates() throws {
        let context = container.mainContext
        context.insert(WeightEntry(record: WeightRecord(day: day("2026-10-01"), kg: 58)))
        context.insert(WeightEntry(record: WeightRecord(day: day("2026-10-01"), kg: 59)))
        try context.save()
        #expect(throws: SaveFailed.self) {
            try failingStore().entries()
        }
        #expect(try count() == 2)
    }
}
