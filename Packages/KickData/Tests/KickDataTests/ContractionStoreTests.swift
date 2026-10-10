import Foundation
import KickCore
import SwiftData
import Testing
@testable import KickData

/// Phase 20 spec §3.1: contractions, at most one running.
@MainActor
struct ContractionStoreTests {
    let container: ModelContainer
    let store: ContractionStore

    init() throws {
        container = try KickPersistence.makeContainer(inMemory: true)
        store = ContractionStore(context: container.mainContext)
    }

    private struct InjectedFailure: Error {}

    @Test func savesAndReadsOldestFirst() throws {
        let later = ContractionRecord(startedAt: date("2026-10-10T10:10:00Z"), endedAt: date("2026-10-10T10:11:00Z"))
        let earlier = ContractionRecord(startedAt: date("2026-10-10T10:00:00Z"), endedAt: date("2026-10-10T10:00:50Z"))
        try store.save(later)
        try store.save(earlier)
        #expect(try store.contractions() == [earlier, later])
    }

    @Test func saveReplacesTheRecordWithItsID() throws {
        var record = ContractionRecord(startedAt: date("2026-10-10T10:00:00Z"))
        try store.save(record)
        record.endedAt = date("2026-10-10T10:01:00Z")
        try store.save(record)
        #expect(try store.contractions() == [record])
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Contraction>()) == 1)
        // And back to running (undo of a stop).
        record.endedAt = nil
        try store.save(record)
        #expect(try store.contractions().first?.isRunning == true)
    }

    @Test func aSecondRunningContractionIsRefused() throws {
        try store.save(ContractionRecord(startedAt: date("2026-10-10T10:00:00Z")))
        #expect(throws: ContractionError.alreadyRunning) {
            try store.save(ContractionRecord(startedAt: date("2026-10-10T10:05:00Z")))
        }
        #expect(try store.contractions().count == 1)
    }

    @Test func anEndBeforeTheStartIsRefused() {
        #expect(throws: ContractionError.endBeforeStart) {
            try store.save(ContractionRecord(startedAt: date("2026-10-10T10:00:00Z"), endedAt: date("2026-10-10T09:59:00Z")))
        }
    }

    @Test func deleteRemovesThoseIDsOnly() throws {
        let a = ContractionRecord(startedAt: date("2026-10-10T10:00:00Z"), endedAt: date("2026-10-10T10:01:00Z"))
        let b = ContractionRecord(startedAt: date("2026-10-10T10:05:00Z"), endedAt: date("2026-10-10T10:06:00Z"))
        let c = ContractionRecord(startedAt: date("2026-10-10T10:10:00Z"))
        for record in [a, b, c] { try store.save(record) }
        try store.delete(ids: [a.id, c.id, UUID()])
        #expect(try store.contractions() == [b])
        try store.delete(ids: [])
        #expect(try store.contractions() == [b])
    }

    @Test func aFailedSaveRollsBack() throws {
        let failing = ContractionStore(context: container.mainContext) { _ in throw InjectedFailure() }
        #expect(throws: InjectedFailure.self) {
            try failing.save(ContractionRecord(startedAt: date("2026-10-10T10:00:00Z")))
        }
        #expect(try store.contractions().isEmpty)
        #expect(!container.mainContext.hasChanges)
    }

    @Test func aFailedDeleteRollsBack() throws {
        let record = ContractionRecord(startedAt: date("2026-10-10T10:00:00Z"), endedAt: date("2026-10-10T10:01:00Z"))
        try store.save(record)
        let failing = ContractionStore(context: container.mainContext) { _ in throw InjectedFailure() }
        #expect(throws: InjectedFailure.self) { try failing.delete(ids: [record.id]) }
        #expect(try store.contractions() == [record])
    }
}
